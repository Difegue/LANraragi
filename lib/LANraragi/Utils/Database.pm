package LANraragi::Utils::Database;

use strict;
use warnings;
use utf8;

use Digest::SHA qw(sha256_hex);
use Encode;
use File::Basename;
use Redis;

use LANraragi::Model::Config;

# Functions for interacting with the DB Model.

#add_archive_to_redis($id,$file,$redis)
#Parses the name of a file for metadata, and matches that metadata to the SHA-1 hash of the file in our Redis database.
sub add_archive_to_redis {
    my ( $id, $file, $redis ) = @_;
    my $logger =
      LANraragi::Utils::Generic::get_logger( "Archive", "lanraragi" );
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

#parse_name(name)
#parses an archive name with the regex specified in the configuration file(get_regex and select_from_regex subs) to find metadata.
sub parse_name {

    my ( $event, $artist, $title, $series, $language );
    $event = $artist = $title = $series = $language = "";

    #Replace underscores with spaces
    $_[0] =~ s/_/ /g;

    #Use the regex on our file, and pipe it to the regexsel sub.
    $_[0] =~ LANraragi::Model::Config->get_regex;

    #Take variables from the regex selection
    if ( defined $2 ) { $event    = $2; }
    if ( defined $4 ) { $artist   = $4; }
    if ( defined $5 ) { $title    = $5; }
    if ( defined $7 ) { $series   = $7; }
    if ( defined $9 ) { $language = $9; }

    my @tags = ();

    if ( $event ne "" ) {
        push @tags, "event:$event";
    }

    if ( $artist ne "" ) {

     #Special case for circle/artist sets:
     #If the string contains parenthesis, what's inside those is the artist name
     #the rest is the circle.
        if ( $artist =~ /(.*) \((.*)\)/ ) {
            push @tags, "group:$1";
            push @tags, "artist:$2";
        }
        else {
            push @tags, "artist:$artist";
        }
    }

    if ( $series ne "" ) {
        push @tags, "parody:$series";
    }

    if ( $language ne "" ) {
        push @tags, "language:$language";
    }

    my $tagstring = join( ", ", @tags );

    return ( $title, $tagstring );
}

#This function is used for all ID computation in LRR.
#Takes the path to the file as an argument.
sub compute_id {

    my $file = $_[0];

    #Read the first 500 KBs only (allows for faster disk speeds )
    open( my $handle, '<', $file ) or die "Couldn't open $file :" . $!;
    my $data;
    my $len = read $handle, $data, 512000;
    close $handle;

    #Compute a SHA-1 hash of this data
    my $ctx = Digest::SHA->new(1);
    $ctx->add($data);
    my $digest = $ctx->hexdigest;

    return $digest;

}

#Final Solution to the Unicode glitches -- Eval'd double-decode for data obtained from Redis.
#This should be a one size fits-all function.
sub redis_decode {

    my $data = $_[0];

#Setting FB_CROAK tells encode to die instantly if it encounters any errors.
#Without this setting, it typically tries to replace characters... which might already be valid UTF8!
    eval { $data = decode_utf8( $data, Encode::FB_CROAK ) };
    eval { $data = decode_utf8( $data, Encode::FB_CROAK ) };

    return $data;
}

#Set the force_refresh flag. This will invalidate the currently cached JSON.
sub invalidate_cache {
    my $redis = LANraragi::Model::Config::get_redis;
    $redis->hset( "LRR_JSONCACHE", "force_refresh", 1 );
}

1;
