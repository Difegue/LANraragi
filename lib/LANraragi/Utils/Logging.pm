package LANraragi::Utils::Logging;

use strict;
use warnings;
use utf8;

use feature 'say';
use POSIX;
use FindBin;

use Encode;
use File::ReadBackwards;

# Contains all functions related to logging.
use Exporter 'import'; 
our @EXPORT_OK = qw(get_logger get_logdir get_lines_from_file); 

# Get the Log folder.
sub get_logdir {

    my $log_folder = "$FindBin::Bin/../log";

    # Folder location can be overriden by LRR_LOG_DIRECTORY
    if ($ENV{LRR_LOG_DIRECTORY}) {
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

    my $logpath = get_logdir . "/$logfile.log";

    if (-e $logpath && -s $logpath > 1048576) {
        # Rotate log if it's > 1MB
        say "Rotating logfile $logfile";
        new Logfile::Rotate(File => $logpath, Gzip  => 'lib')->rotate();
    }

    my $log = Mojo::Log->new( path => $logpath, 
                              level => 'info' );

    my $devmode = LANraragi::Model::Config->enable_devmode;

    #Tell logger to store debug logs as well in debug mode
    if ($devmode) {
        $log->level('debug');
    }

    #Copy logged messages to STDOUT with the matching name
    $log->on(
        message => sub {
            my ( $time, $level, @lines ) = @_;

            unless ( $devmode == 0 && $level eq 'debug' )
            { #Like with logging to file, debug logs are only printed in debug mode
                print "[$pgname] [$level] ";
                say $lines[0];
            }
        }
    );

    $log->format(
        sub {
            my ( $time, $level, @lines ) = @_;
            my $time2 = strftime( "%Y-%m-%d %H:%M:%S", localtime($time) );
            return "[$time2] [$pgname] [$level] " . join( "\n", @lines ) . "\n";
        }
    );

    return $log;
}

sub get_lines_from_file {

    my $lines = $_[0];
    my $file  = $_[1];

    #Load the last X lines of file
    if ( -e $file ) {
        my $bw  = File::ReadBackwards->new($file);
        my $res = "";
        for ( my $i = 0 ; $i <= $lines ; $i++ ) {
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