#!/usr/bin/env perl

use strict;
use warnings;
use Cwd 'abs_path';

use Mojo::Base -strict;
use Mojo::Server::Morbo;
use Mojo::Server::Prefork;
use Mojo::Util qw(extract_usage getopt);
use File::Path qw(make_path);

getopt
  'm|morbo'      => \my $morbo,
  'f|foreground' => \$ENV{HYPNOTOAD_FOREGROUND},
  'h|help'       => \my $help,
  'v|verbose'    => \$ENV{MORBO_VERBOSE};

if ( $ENV{LRR_DATA_DIRECTORY} ) {
    make_path( $ENV{LRR_DATA_DIRECTORY} );
}

if ( $ENV{LRR_THUMB_DIRECTORY} ) {
    make_path( $ENV{LRR_THUMB_DIRECTORY} );
}

if ( $ENV{LRR_TEMP_DIRECTORY} ) {
    make_path( $ENV{LRR_TEMP_DIRECTORY} );
}

die extract_usage if $help || !( my $app = shift || $ENV{HYPNOTOAD_APP} );

my @listen;
if ( $ENV{LRR_NETWORK} ) {
    @listen = [ $ENV{LRR_NETWORK} ];
} else {
    @listen = ["http://*:3000"];
}

# Relocate the Prefork PID file
my $hypno_pid;
if ( $ENV{LRR_TEMP_DIRECTORY} ) {
    $hypno_pid = $ENV{LRR_TEMP_DIRECTORY} . "/server.pid";
} else {
    $hypno_pid = "./public/temp/server.pid";
}
$hypno_pid = abs_path($hypno_pid);

my $backend;
if ($morbo) {
    $backend = Mojo::Server::Morbo->new( keep_alive_timeout => 30 );
    $ENV{MOJO_MODE} = "development";
    $backend->daemon->listen(@listen);
    $backend->run($app);
} else {
    print "Server PID will be at " . $hypno_pid . "\n";

    $backend = Mojo::Server::Prefork->new( keep_alive_timeout => 30 );
    $backend->pid_file($hypno_pid);
    $backend->listen(@listen);

    $backend->load_app($app);

    $backend->start;
    $backend->daemonize if !$ENV{HYPNOTOAD_FOREGROUND};

    # Start accepting connections
    $backend->cleanup(1)->run;
}

exit;

=encoding utf8

=head1 NAME

LRR launcher using either morbo or Prefork. Morbo always starts in dev mode.
To change the listen port, use the LRR_NETWORK environment variable.

=head1 SYNOPSIS

  Usage: perl launcher.pl [OPTIONS] lanraragi

  Options:
    -m, --morbo        Use morbo instead of Prefork
    -f, --foreground   Keep manager process in foreground (Prefork)
    -v, --verbose      Print details about what files changed to
                       STDOUT (morbo)
    -h, --help         Show this message

=head1 DESCRIPTION

Start L<Mojolicious> and L<Mojolicious::Lite> applications with the
L<Prefork|Mojo::Server::Prefork> web server.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<https://mojolicious.org>.

=cut
