package LANraragi::Model::Utils;

use strict;
use warnings;
use utf8;
use feature 'say';

use POSIX;
use Digest::SHA qw(sha256_hex);
use File::Basename;
use Encode;
use URI::Escape;
use Redis;
use Image::Magick;
use Mojo::Log;

use LANraragi::Model::Config;
use LANraragi::Model::Plugins;

#generate_thumbnail(original_image, thumbnail_location)
#use ImageMagick to make a thumbnail, width = 200px
sub generate_thumbnail {

    my ( $orig_path, $thumb_path ) = @_;
    my $img = Image::Magick->new;

    $img->Read($orig_path);
    $img->Thumbnail( geometry => '200x' );
    $img->Write($thumb_path);
}

#Returns a Logger object, taking plugin info as argument to obtain the plugin name and a filename for the log file.
sub get_logger {

    #Customize log file location and minimum log level
    my $pgname  = $_[0];
    my $logfile = $_[1];

    my $log =
      Mojo::Log->new( path => './log/' . $logfile . '.log', level => 'info' );

    my $devmode = LANraragi::Model::Config::enable_devmode;

    #Copy logged messages to STDOUT with the plugin name
    $log->on(
        message => sub {
            my ( $time, $level, @lines ) = @_;

            unless ( $devmode == 0 && $level eq 'debug' )
            {   #Debug logs are only printed in debug mode (duh)
                print "[$pgname] ";
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

#This function gives us a SHA hash for the passed file, which is used for thumbnail reverse search on E-H.
#First argument is the file, second is the algorithm to use. (1, 224, 256, 384, 512, 512224, or 512256)
#E-H only uses SHA-1 hashes.
sub shasum {

    my $digest = "";
    my $logger = get_logger("Hash Computation","lanraragi");

    eval {
        my $ctx = Digest::SHA->new( $_[1] );
        $ctx->addfile( $_[0] );
        $digest = $ctx->hexdigest;
    };

    if ($@) {
        $logger->error("Error building hash for " . $_[0] . " -- " . $@);

        return "";
    }

    return $digest;
}

#This function is used for all ID computation in LRR.
#Takes the path to the file as an argument.
sub compute_id {

    my $file = $_[0];

    #Read the first 500 KBs only (allows for faster disk speeds )
    open( my $handle, '<', $file ) or die $!;
    my $data;
    my $len = read $handle, $data, 512000;
    close $handle;

    #Compute a SHA-1 hash of this data
    my $ctx = Digest::SHA->new(1);
    $ctx->add($data);
    my $digest = $ctx->hexdigest;

    return $digest;

}

#Remove spaces before and after a word
sub remove_spaces {
    until ( substr( $_[0], 0, 1 ) ne " " ) {
        $_[0] = substr( $_[0], 1 );
    }

    until ( substr( $_[0], -1 ) ne " " ) {
        chop $_[0];
    }
}

#Final Solution to the Unicode glitches -- Eval'd double-decode for data obtained from Redis.
#This should be a one size fits-all function.
sub redis_decode {

    my $data = $_[0];

    #Setting FB_CROAK tells encode to die instantly if it encounters any errors.
    #Without this setting, it typically tries to replace characters... which might already be valid UTF8!
    eval { $data = decode_utf8($data, Encode::FB_CROAK) }; 
    eval { $data = decode_utf8($data, Encode::FB_CROAK) };

    return $data;
}

#Set the force_refresh flag. This will invalidate the currently cached JSON.
sub invalidate_cache {
    my $redis = LANraragi::Model::Config::get_redis;
    $redis->hset( "LRR_JSONCACHE", "force_refresh", 1 );
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
        } else {

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

#parse_name(name)
#parses an archive name with the regex specified in the configuration file(get_regex and select_from_regex subs) to find metadata.
sub parse_name {

    my ( $event, $artist, $title, $series, $language, $tags );
    $event = $artist = $title = $series = $language = $tags = "";

    #Replace underscores with spaces
    $_[0] =~ s/_/ /g;

    #Use the regex on our file, and pipe it to the regexsel sub.
    $_[0] =~ LANraragi::Model::Config->get_regex ;

    #Take variables from the regex selection
    if (defined $2) { $event = $2; }
    if (defined $4) { $artist = $4; }
    if (defined $5) { $title = $5; }
    if (defined $7) { $series = $7; }
    if (defined $9) { $language = $9; }

    if ($event ne "") {
        $tags .= "event:$event, ";
    }

    if ($artist ne "") {

        #Special case for circle/artist sets: If the string contains parenthesis, what's inside those is the artist name -- the rest is the circle.
        if ( $artist =~ /(.*) \((.*)\)/ ) {
            $tags .= "group:$1, artist:$2, ";
        }
        else {
            $tags .= "artist:$artist, ";
        }
    }

    if ($series ne "") {
        $tags .= "parody:$series, ";
    }

    if ($language ne "") {
        $tags .= "language:$language, ";
    }

    return ( $title, $tags );
}

#add_archive_to_redis($id,$file,$redis)
#Parses the name of a file for metadata, and matches that metadata to the SHA-1 hash of the file in our Redis database.
sub add_archive_to_redis {
    my ( $id, $file, $redis ) = @_;
    my $logger = get_logger("Archive","lanraragi");
    my ( $name, $path, $suffix ) = fileparse( $file, qr/\.[^.]*/ );

    #parse_name function is up there
    my ( $title, $tags ) = parse_name( $name . $suffix );

    #jam this shit in redis
    $logger->debug("Pushing to redis on ID $id:");
    $logger->debug("File Name: $name");
    $logger->debug("Parsed Title: $title");
    $logger->debug("Parsed Tags: $tags");
    $logger->debug("Filesystem Path: $file");

    $redis->hset( $id, "name",  encode_utf8($name) );
    $redis->hset( $id, "title", encode_utf8($title) );
    $redis->hset( $id, "tags",  encode_utf8($tags) );
    $redis->hset( $id, "file",  encode_utf8($file) );
    $redis->hset( $id, "isnew", "block" );    

    #New file in collection, so this flag is set.
    return ( $name, $title, $tags, "block" );
}

1;
