package LANraragi::Utils::Database;

use strict;
use warnings;
use utf8;

use Digest::SHA qw(sha256_hex);
use Mojo::JSON qw(decode_json);
use Encode;
use File::Basename;
use Redis;
use Cwd;

use LANraragi::Model::Config;
use LANraragi::Model::Plugins;

# Functions for interacting with the DB Model.

#add_archive_to_redis($id,$file,$redis)
#Parses the name of a file for metadata, and matches that metadata to the SHA-1 hash of the file in our Redis database.
#This function doesn't actually require the file to exist at its given location.
sub add_archive_to_redis {
    my ( $id, $file, $redis ) = @_;
    my $logger =
      LANraragi::Utils::Generic::get_logger( "Archive", "lanraragi" );
    my ( $name, $path, $suffix ) = fileparse( $file, qr/\.[^.]*/ );

    #jam this shit in redis
    $logger->debug("Pushing to redis on ID $id:");
    $logger->debug("File Name: $name");
    $logger->debug("Filesystem Path: $file");

    my $title = $name;
    my $tags  = "";

    $redis->hset( $id, "name", encode_utf8($name) );

    #Don't encode filenames.
    $redis->hset( $id, "file", $file );

    #New file in collection, so this flag is set.
    $redis->hset( $id, "isnew", "true" );

    #Use the mythical regex to get title and tags
    #Except if the matching pref is off
    if ( LANraragi::Model::Config->get_tagregex eq "1" ) {
        ( $title, $tags ) = parse_name($name);
        $logger->debug("Parsed Title: $title");
        $logger->debug("Parsed Tags: $tags");
    }

    $redis->hset( $id, "title", encode_utf8($title) );
    $redis->hset( $id, "tags",  encode_utf8($tags) );
    $redis->quit;

    return ( $name, $title, $tags, "true" );
}

# build_archive_JSON(redis, id)
# Builds a JSON object for an archive registered in the database and returns it.
# This function is usually called many times in a row, so provide your own Redis object.
sub build_archive_JSON {
    my ( $redis, $id ) = @_;
    my $dirname = LANraragi::Model::Config::get_userdir;

    #Extra check in case we've been given a bogus ID
    return "" unless $redis->exists($id);

    my %hash = $redis->hgetall($id);
    my ( $path, $suffix );

    #It's not a new archive, but it might have never been clicked on yet,
    #so we'll grab the value for $isnew stored in redis.
    my ( $name, $title, $tags, $file, $isnew ) =
      @hash{qw(name title tags file isnew)};

    #Parameters have been obtained, let's decode them.
    ( $_ = LANraragi::Utils::Database::redis_decode($_) )
      for ( $name, $title, $tags );

    #Workaround if title was incorrectly parsed as blank
    if ( !defined($title) || $title =~ /^\s*$/ ) {
        $title = $name;
    }

    my $arcdata = {
        arcid  => $id,
        title  => $title,
        tags   => $tags,
        isnew  => $isnew
    };

    return $arcdata;
}

sub build_OPDS_entry {

    my ( $redis, $id ) = @_;

    # Recycle the above method to handle all the base data
    my $arcdata = build_archive_JSON($redis, $id);
    my $tags    = $arcdata->{tags};

    # Infer a few OPDS-related fields from the tags
    $arcdata->{dateadded} = LANraragi::Utils::Generic::get_tag_with_namespace("dateadded", $tags, "00");
    $arcdata->{author}    = LANraragi::Utils::Generic::get_tag_with_namespace("artist", $tags, "");
    $arcdata->{language}  = LANraragi::Utils::Generic::get_tag_with_namespace("language", $tags, "");
    $arcdata->{circle}    = LANraragi::Utils::Generic::get_tag_with_namespace("group", $tags, "");
    $arcdata->{event}     = LANraragi::Utils::Generic::get_tag_with_namespace("event", $tags, "");

    return $arcdata;
}

#Deletes the archive with the given id from redis, and the matching archive file.
sub delete_archive {

    my $id   = $_[0];
    my $redis = LANraragi::Model::Config::get_redis;
    my $filename = $redis->hget( $id, "file" );

    $redis->del($id);
    $redis->quit();

    if ( -e $filename ) {
        unlink $filename;
        return $filename;
    }

    return "0";
}

# drop_database()
# Drops the entire database. Hella dangerous
sub drop_database {
    my $redis = LANraragi::Model::Config::get_redis;

    $redis->flushall();
    $redis->quit;
}

# clean_database()
# Remove entries from the database that don't have a matching archive on the filesystem.
# Returns the number of entries deleted.
sub clean_database {
    my $redis = LANraragi::Model::Config::get_redis;

    #40-character long keys only => Archive IDs
    my @keys = $redis->keys('????????????????????????????????????????');

    my $deleted_arcs = 0;

    foreach my $id (@keys) {
        my $file = $redis->hget($id, "file");

        unless (-e $file) {
            $redis->del($id);
            $deleted_arcs++;
        }
    }

    $redis->quit;
    return $deleted_arcs;
}

#add_tags($id, $tags)
#add the $tags to the archive with id $id.
sub add_tags {

    my ( $id, $newtags ) = @_;

    my $redis = LANraragi::Model::Config::get_redis;
    my $oldtags = $redis->hget( $id, "tags" );
    $oldtags = LANraragi::Utils::Database::redis_decode($oldtags);

    if ( length $newtags ) {

        if ( $oldtags ne "" ) {
            $newtags = $oldtags . "," . $newtags;
        }

        $redis->hset( $id, "tags", encode_utf8($newtags) );
    }
    $redis->quit;
}

sub set_title {

    my ( $id, $newtitle ) = @_;
    my $redis = LANraragi::Model::Config::get_redis;

    if ( $newtitle ne "" ) {
        $redis->hset( $id, "title", encode_utf8($newtitle) );
    }
    $redis->quit;
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
        push @tags, "series:$series";
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

    if( $digest eq "da39a3ee5e6b4b0d3255bfef95601890afd80709" ) {
        die "Computed ID is for a null value, invalid source file.";
    }

    return $digest;

}

#Final Solution to the Unicode glitches -- Eval'd double-decode for data obtained from Redis.
#This should be a one size fits-all function.
sub redis_decode {

    my $data = $_[0];

#Setting FB_CROAK tells encode to die instantly if it encounters any errors.
#Without this setting, it typically tries to replace characters... which might already be valid UTF8!
    eval { $data = decode_utf8( $data, Encode::FB_CROAK ) };

    #Do another UTF-8 decode just in case the data was double-encoded
    eval { $data = decode_utf8( $data, Encode::FB_CROAK ) };

    return $data;
}

# Bust the current search cache key in Redis.
sub invalidate_cache {
    my $redis = LANraragi::Model::Config::get_redis;
    $redis->del("LRR_JSONCACHE");
    $redis->del("LRR_SEARCHCACHE");
    $redis->quit();
}

1;
