#!/usr/bin/env perl

# Transparent Process Manager.
#  Self-contained process orchestrator for the server and helper processes.

use v5.38;
use utf8;

use local::lib;

use threads;
use threads::shared;
use Config;
use Proc::Simple;
use Cwd 'abs_path';
use File::Path qw(make_path);
use IO::Socket qw(SHUT_WR);
use IO::Socket::UNIX;
use Getopt::Long qw(GetOptionsFromString);

use constant IS_UNIX => ( $Config{osname} ne 'MSWin32' );

my %pids :shared; # PIDs
my %run :shared; # Should process be restarted

my $should_run :shared = 1;

sub start_process( $process, $arg1, @argv ) {
    $run{$process} = 1;
    while ( $should_run ) {
        while ( $should_run && $run{$process} ) {
            my $proc = Proc::Simple->new();
            $proc->start( $Config{perlpath}, $arg1, @argv );
            $pids{$process} = $proc->pid;
            $proc->wait();
        }
        sleep 1;
    }
}

sub stop_processes {
    kill INT => $pids{lanraragi};
    kill INT => $pids{shinobu};
    kill TERM => $pids{tsubasa};
}

sub restart_command ( $value, $client ) {
    if ( $value eq "all" ) {
        stop_processes();
        $client->send( 1 );
    } else {
        my $pid = $pids{$value};
        if ( $pid ) {
            $pids{$value} = 0;
            kill INT => $pid;
        }

        $run{$value} = 1; # Make sure process is enabled

        my $retries = 0;
        while (!$pids{$value} && $retries < 5) { # Wait for start
            $retries++;
            sleep 1;
        }

        $client->send( $pids{$value} );
    }
}

sub pid_command ( $value, $client ) {
    $client->send( $pids{$value} );
}

sub stop_command ( $value, $client ) {
    $run{$value} = 0;
    kill INT => $pids{$value};
    $pids{$value} = 0;
    $client->send( 1 );
}

if ( $ENV{LRR_DATA_DIRECTORY} ) {
    make_path( $ENV{LRR_DATA_DIRECTORY} );
}

if ( $ENV{LRR_THUMB_DIRECTORY} ) {
    make_path( $ENV{LRR_THUMB_DIRECTORY} );
}

if ( $ENV{LRR_TEMP_DIRECTORY} ) {
    make_path( $ENV{LRR_TEMP_DIRECTORY} );
} else {
    eval { make_path("./temp"); };
}

local $SIG{INT} = sub {
    $should_run = 0;
    stop_processes();
};

local $SIG{TERM} = sub {
    $should_run = 0;
    stop_processes();
};

my $socket = "/tmp/hitagi.sock";

if ( $ENV{XDG_RUNTIME_DIR} ) {
    $socket = $ENV{XDG_RUNTIME_DIR} . "/hitagi.sock"; # Relocate socket to user run directory
}

if ( !IS_UNIX ) {
    $socket = $ENV{TEMP} . "/hitagi.sock"; # Relocate socket to user temp directory
}

$ENV{HITAGI_SOCK} = $socket = abs_path($socket);

say( "Starting processes" );

my @monitor_threads;

push @monitor_threads, threads->create( \&start_process, "lanraragi", "./script/launcher.pl", @ARGV );
push @monitor_threads, threads->create( \&start_process, "shinobu", "./lib/Shinobu.pm" );
push @monitor_threads, threads->create( \&start_process, "tsubasa", "./lib/Tsubasa.pm" );

unlink $socket if -e $socket;

my $server = IO::Socket::UNIX->new(
    Type => SOCK_STREAM(),
    Local => $socket,
    Listen => 1,
    Timeout => 1
);

while ( $should_run ) {
    while ( my $client = $server->accept() ) {
        my $message = "";
        $client->recv( $message, 512 );
        
        GetOptionsFromString (
            $message,
            "restart=s" => sub { restart_command($_[1], $client); },
            "stop=s" => sub { stop_command($_[1], $client); },
            "pid=s" => sub { pid_command($_[1], $client); },
        );

        $client->shutdown( SHUT_WR );
    }
}

$server->close();

say( "Waiting for processes..." );

foreach my $thread (@monitor_threads) {
    $thread->join();
}

say( "Done! Exiting..." );

eval { unlink $socket; };

exit;
