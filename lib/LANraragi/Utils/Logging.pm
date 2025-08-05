package LANraragi::Utils::Logging;

use strict;
use warnings;
use utf8;

use feature 'say';
use POSIX;
use FindBin;
use Cwd 'abs_path';

use Encode;
use File::ReadBackwards;
use Compress::Zlib;

# Contains all functions related to logging.
use Exporter 'import';
our @EXPORT_OK = qw(get_logger get_plugin_logger get_logdir get_lines_from_file);

# Get the Log folder.
sub get_logdir {

    my $log_folder = "$FindBin::Bin/../log";

    # Folder location can be overriden by LRR_LOG_DIRECTORY
    if ( $ENV{LRR_LOG_DIRECTORY} ) {
        $log_folder = $ENV{LRR_LOG_DIRECTORY};
    }
    mkdir $log_folder;
    return $log_folder;
}

# Returns a Logger object with a custom name and a filename for the log file.
sub get_logger {

    #Customize log file location and minimum log level
    my $pgname  = $_[0];
    my $logfile = $_[1];

    my $logpath = abs_path( get_logdir . "/$logfile.log" );

    if ( -e $logpath && -s $logpath > 1048576 ) {

        # Rotate log if it's > 1MB
        say "Rotating logfile $logfile";

        # Based on Logfile::Rotate
        # Rotate existing logs
        for ( my $i = 7; $i > 1; $i-- ) {
            my $j = $i - 1;
            my $next = "$logpath.$i.gz";
            my $prev = "$logpath.$j.gz";
            if ( -r $prev && -f $prev ) {
                rename( $prev, $next ) or die "error: rename failed: ($prev,$next)";
            }
        }

        # Rotate current log and Gzip-it
        my $gz = gzopen( "$logpath.1.gz", "wb" ) or die "error: could not gzopen $logpath: $!";

        open( my $handle, '<', $logpath ) or die "Couldn't open $logpath :" . $!;
        my $buffer;
        $gz->gzwrite($buffer) while read( $handle, $buffer, 4096 ) > 0;
        $gz->gzclose();
        close $handle;

        unlink $logpath or die "error: could not delete $logpath: $!";
    }

    my $log = Mojo::Log->new(
        path  => $logpath,
        level => 'info'
    );

    my $devmode = LANraragi::Model::Config->enable_devmode;

    #Tell logger to store debug logs as well in debug mode
    if ($devmode) {
        $log->level('debug');
    }

    # Step down into trace if we're launched from npm run dev-server-verbose
    if ( $ENV{LRR_DEVSERVER} ) {
        $log->level('trace');
    }

    #Copy logged messages to STDOUT with the matching name
    $log->on(
        message => sub {
            my ( $time, $level, @lines ) = @_;

            #Like with logging to file, debug logs are only printed in debug mode
            unless ( $devmode == 0 && ( $level eq 'debug' || $level eq 'trace' ) ) {
                print "[$pgname] [$level] ";
                say $lines[0];
            }
        }
    );

    $log->format(
        sub {
            my ( $time, $level, @lines ) = @_;
            my $time2 = strftime( "%Y-%m-%d %H:%M:%S", localtime($time) );

            my $logstring = join( "\n", @lines );

            # We'd like to make sure we always show proper UTF-8.
            # redis_decode, while not initially designed for this, does the job.
            $logstring = LANraragi::Utils::Database::redis_decode($logstring);

            return "[$time2] [$pgname] [$level] $logstring\n";
        }
    );

    return $log;
}

sub get_plugin_logger {

    my ( $pkg, $filename, $line ) = caller;

    if ( !$pkg->can('plugin_info') ) {
        die "\"get_plugin_logger\" cannot be called from \"$pkg\"; line $line at $filename\n";
    }
    my %pi = $pkg->plugin_info();
    return get_logger( $pi{name}, "plugins" );
}

sub get_lines_from_file {

    my $lines = $_[0];
    my $file  = $_[1];

    #Load the last X lines of file
    if ( -e $file ) {
        my $bw  = File::ReadBackwards->new($file);
        my $res = "";
        for ( my $i = 0; $i <= $lines; $i++ ) {
            my $line = $bw->readline();
            if ($line) {
                $res = $line . $res;
            }

        }

        return decode_utf8($res);
    }

    return "No logs to be found here!";

}

1;
