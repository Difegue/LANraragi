package LANraragi::Utils::Logging;

use strict;
use warnings;
use utf8;

use feature 'say';
use POSIX;
use FindBin;
use Time::HiRes;

use Encode;
use File::ReadBackwards;
use Compress::Zlib;
use LANraragi::Model::Config;
use LANraragi::Utils::Redis qw(redis_decode);

# Contains all functions related to logging.
use Exporter 'import';
our @EXPORT_OK = qw(get_logger get_plugin_logger get_logdir get_lines_from_file);
our %LOGGER_CACHE;

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

    my $logpath     = get_logdir . "/$logfile.log";
    my $cache_key   = "$logfile|$pgname";
    my $log;

    # Reuse cached logger if exists
    if ( exists $LOGGER_CACHE{$cache_key} && -e $logpath && -s $logpath <= 1048576 ) {
        return $LOGGER_CACHE{$cache_key};
    }

    # Logfile lock owners have exclusive ability to create a logfile.
    # Non-owners may only append or wait for logfile availability.
    my $lock_name   = "log-rotate:$logfile";
    my $lock;

    if ( -e $logpath && -s $logpath > 1048576 ) {

        # Rotate log if it's > 1MB
        my $redis       = LANraragi::Model::Config->get_redis_config;
        $lock           = $redis->set( $lock_name, 1, 'NX', 'EX', 10 );
        my $rotation_error;

        if ( $lock ) {

            eval {
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

                # Move current logs to tempfile to stop new writes to it
                my $tmp = "$logpath.rotate";
                unlink $tmp if -e $tmp;
                rename( $logpath, $tmp ) or die "error: could not detach $logpath to $tmp: $!";

                # Gzip the detached tempfile
                my $gz = gzopen( "$logpath.1.gz", "wb" ) or die "error: could not gzopen $logpath.1.gz: $!";
                open( my $handle, '<', $tmp ) or die "Couldn't open $tmp: $!";
                my $buffer;
                $gz->gzwrite($buffer) while read( $handle, $buffer, 4096 ) > 0;
                $gz->gzclose();
                close $handle;

                unlink $tmp or die "error: could not delete $tmp: $!";

                open( my $fh, '>>', $logpath ) or die "Could not create logfile '$logpath': $!";
                close $fh;
                my $newlog;
                eval {
                    $newlog = Mojo::Log->new(
                        path  => $logpath,
                        level => 'info'
                    );
                    $newlog->handle;
                    $newlog->info("Rotated log files.");
                    1;
                } or do {
                    my $e = $@ || 'unknown error';
                    die "Failed to instantiate Mojo::Log for '$pgname' at '$logpath' (rotation): $e";
                };
                $log = $newlog;
                $LOGGER_CACHE{$cache_key} = $log;
            };

            $rotation_error = $@;
            $redis->del($lock_name);

        }

        $redis->quit();
        die $rotation_error if $rotation_error;

    }

    # handle logpath existence cases.
    # case 1 (logfile exist):                   no action needed, just get the logfile handle
    # case 2 (logfile DNE, lock not acquired):  wait 10s logfile to be available
    # case 3 (logfile DNE, lock acquired):      create new logfile
    if ( !-e $logpath ) {
        # handle cases where a logfile doesn't exist.

        my $redis       = LANraragi::Model::Config->get_redis_config;
        $lock           = $redis->set( $lock_name, 1, 'NX', 'EX', 10 );

        my $logfile_create_error;
        if ( !$lock ) {
            # Another worker is rotating/creating the logfile.
            my $tries = 0;
            while ( $tries < 100 && !-e $logpath ) {
                Time::HiRes::sleep(0.1);
                $tries++;
            }
            if ( -e $logpath ) {
                my $newlog;
                eval {
                    $newlog = Mojo::Log->new(
                        path  => $logpath,
                        level => 'info'
                    );
                    $newlog->handle;
                    $newlog->info("Created log file.");
                    1;
                } or do {
                    my $e = $@;
                    die "Failed to instantiate Mojo::Log for '$pgname' at '$logpath' (wait branch): $@";
                };
                $log = $newlog;
                $LOGGER_CACHE{$cache_key} = $log;
            } else {
                $logfile_create_error = "Timed out waiting for logfile to be created: $logpath"
            }
        } else {
            # This happens during start of app (if no logfile exists).
            eval {
                say "Creating logfile $logfile.";

                open( my $fh, '>>', $logpath ) or die "Could not create logfile '$logpath': $!";
                close $fh;
                my $newlog;
                eval {
                    $newlog = Mojo::Log->new(
                        path  => $logpath,
                        level => 'info'
                    );
                    $newlog->handle;
                    1;
                } or do {
                    my $e = $@ || 'unknown error';
                    die "Failed to instantiate Mojo::Log for '$pgname' at '$logpath' (create branch): $e";
                };
                $log = $newlog;
                $LOGGER_CACHE{$cache_key} = $log;
                1;
            };

            $logfile_create_error = $@;
            $redis->del($lock_name);
        }

        $redis->quit();
        die $logfile_create_error if $logfile_create_error;

    } else {
        my $newlog;
        eval {
            $newlog = Mojo::Log->new(
                path  => $logpath,
                level => 'info'
            );
            $newlog->handle;
            1;
        } or do {
            my $e = $@ || 'unknown error';
            die "Failed to instantiate Mojo::Log for '$pgname' at '$logpath' (default branch): $e";
        };
        $log = $newlog;
        $LOGGER_CACHE{$cache_key} = $log;
    }

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
            $logstring = redis_decode($logstring);

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
