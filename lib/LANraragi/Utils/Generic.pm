package LANraragi::Utils::Generic;

use strict;
use warnings;
use utf8;

use feature 'say';
use POSIX;
use Digest::SHA qw(sha256_hex);
use Mojo::Log;

use LANraragi::Model::Config;

# Generic Utility Functions.

#Remove spaces before and after a word
sub remove_spaces {
    until ( substr( $_[0], 0, 1 ) ne " " ) {
        $_[0] = substr( $_[0], 1 );
    }

    until ( substr( $_[0], -1 ) ne " " ) {
        chop $_[0];
    }
}

#Remove all newlines in a string
sub remove_newlines {
    $_[0] =~ s/\R//g;
}

#This function gives us a SHA hash for the passed file, which is used for thumbnail reverse search on E-H.
#First argument is the file, second is the algorithm to use. (1, 224, 256, 384, 512, 512224, or 512256)
#E-H only uses SHA-1 hashes.
sub shasum {

    my $digest = "";
    my $logger = get_logger( "Hash Computation", "lanraragi" );

    eval {
        my $ctx = Digest::SHA->new( $_[1] );
        $ctx->addfile( $_[0] );
        $digest = $ctx->hexdigest;
    };

    if ($@) {
        $logger->error( "Error building hash for " . $_[0] . " -- " . $@ );

        return "";
    }

    return $digest;
}

#Returns a Logger object with a custom name and a filename for the log file.
sub get_logger {

    #Customize log file location and minimum log level
    my $pgname  = $_[0];
    my $logfile = $_[1];

    my $log =
      Mojo::Log->new( path => './log/' . $logfile . '.log', level => 'info' );

    my $devmode = LANraragi::Model::Config::enable_devmode;

    #Tell logger to store debug logs as well in debug mode
    if ($devmode) {
        $log->level('debug');
    }

    #Copy logged messages to STDOUT with the matching name
    $log->on(
        message => sub {
            my ( $time, $level, @lines ) = @_;

            unless ( $devmode == 0 && $level eq 'debug' )
            {    #Like for the logging to file, debug logs are only printed in debug mode
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

#Print a dropdown list to select CSS, and adds <link> tags for all the style sheets present in the /style folder.
sub generate_themes {

    #Get all the available CSS sheets.
    my @css;
    opendir( DIR, "./public/themes" ) or die $!;
    while ( my $file = readdir(DIR) ) {
        if ( $file =~ /.+\.css/ ) { push( @css, $file ); }
    }
    closedir(DIR);

    my $CSSsel = '<div>';

    #html that we'll insert before the list to declare all the available styles.
    my $html = "";

    #We opened a drop-down list. Now, we'll fill it.
    for ( my $i = 0 ; $i < $#css + 1 ; $i++ ) {

        #populate the div with spans
        my $css_name = LANraragi::Model::Config::css_default_names( $css[$i] );
        $CSSsel =
            $CSSsel
          . '<input class="stdbtn" type="button" onclick="switch_style(\''
          . $i
          . '\');" value="'
          . $css_name . '"/>';

        #if this is the default sheet, set it up as so.
        if ( $css[$i] eq LANraragi::Model::Config->get_style ) {

            $html =
                $html
              . '<link rel="stylesheet" type="text/css" title="'
              . $i
              . '" href="/themes/'
              . $css[$i] . '"> ';
        }
        else {

            $html =
                $html
              . '<link rel="alternate stylesheet" type="text/css" title="'
              . $i
              . '" href="/themes/'
              . $css[$i] . '"> ';
        }
    }

    #close up dropdown list
    $CSSsel = $CSSsel . '</div>';

    return $html . $CSSsel;

}

1;
