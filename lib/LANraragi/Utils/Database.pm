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
use Unicode::Normalize;

use LANraragi::Model::Plugins;
use LANraragi::Model::Config;
use LANraragi::Utils::Generic qw(flat remove_spaces);
use LANraragi::Utils::Tags qw(unflat_tagrules tags_rules_to_array restore_CRLF);
use LANraragi::Utils::Logging qw(get_logger);

# Functions for interacting with the DB Model.
use Exporter 'import';
our @EXPORT_OK =
  qw(redis_encode redis_decode invalidate_cache compute_id get_computed_tagrules save_computed_tagrules get_archive_json get_archive_json_multi);

#add_archive_to_redis($id,$file,$redis)
# Creates a DB entry for a file path with the given ID.
# This function doesn't actually require the file to exist at its given location.
sub add_archive_to_redis {
    my ( $id, $file, $redis ) = @_;
    my $logger = get_logger( "Archive", "lanraragi" );
    my ( $name, $path, $suffix ) = fileparse( $file, qr/\.[^.]*/ );

    #jam this shit in redis
    $logger->debug("Pushing to redis on ID $id:");
    $logger->debug("File Name: $name");
    $logger->debug("Filesystem Path: $file");

    $redis->hset( $id, "name",  redis_encode($name) );
    $redis->hset( $id, "title", redis_encode($name) );

    # Initialize tags to the current date if the matching pref is enabled
    if ( LANraragi::Model::Config->enable_dateadded eq "1" ) {

        if ( LANraragi::Model::Config->use_lastmodified eq "1" ) {
            $logger->info("Using file date");
            $redis->hset( $id, "tags", "date_added:" . ( stat($file) )[9] );    #9 is the unix time stamp for date modified.
        } else {
            $logger->info("Using current date");
            $redis->hset( $id, "tags", "date_added:" . time() );
        }
    } else {
        $redis->hset( $id, "tags", "" );
    }

    # Don't encode filenames.
    $redis->hset( $id, "file", $file );

    # New file in collection, so this flag is set.
    $redis->hset( $id, "isnew", "true" );

    $redis->quit;
    return $name;
}

# get_archive_json(redis, id)
# Builds a JSON object for an archive registered in the database and returns it.
# If you need to get many JSONs at once, use the multi variant.
sub get_archive_json {
    my ( $redis, $id ) = @_;
    my $arcdata;

    eval {
        #Extra check in case we've been given a bogus ID
        die unless $redis->exists($id);

        my %hash = $redis->hgetall($id);
        $arcdata = build_json( $id, %hash );
    };

    return $arcdata;
}

# get_archive_json_multi(redis, ids)
# Uses Redis' MULTI to get an archive JSON for each ID.
sub get_archive_json_multi {
    my @ids   = @_;
    my $redis = LANraragi::Model::Config->get_redis;

    # Get the archive JSON for each ID.
    my @archives;
    my @results;
    eval {
        $redis->multi;
        foreach my $id (@ids) {
            $redis->hgetall($id);
        }
        @results = $redis->exec;
        $redis->quit;
    };

    # Build the archive JSONs.
    for my $i ( 0 .. $#results ) {

        # If we got no results for one ID/hgetall, skip it.
        next unless ( $results[$i] );
        my %hash = @{ $results[$i] };
        my $id   = $ids[$i];

        my $arcdata = build_json( $id, %hash );

        if ($arcdata) {
            push @archives, $arcdata;
        }
    }

    return @archives;
}

# Internal function for building an archive JSON.
sub build_json {
    my ( $id, %hash ) = @_;

    # It's not a new archive, but it might have never been clicked on yet,
    # so grab the value for $isnew stored in redis.
    my ( $name, $title, $tags, $file, $isnew, $progress, $pagecount ) = @hash{qw(name title tags file isnew progress pagecount)};

    # Return undef if the file doesn't exist.
    return unless ( -e $file );

    # Parameters have been obtained, let's decode them.
    ( $_ = redis_decode($_) ) for ( $name, $title, $tags );

    # Workaround if title was incorrectly parsed as blank
    if ( !defined($title) || $title =~ /^\s*$/ ) {
        $title = $name;
    }

    my $arcdata = {
        arcid     => $id,
        title     => $title,
        tags      => $tags,
        isnew     => $isnew ? $isnew : "false",
        extension => lc( ( split( /\./, $file ) )[-1] ),
        progress  => $progress ? int($progress) : 0,
        pagecount => $pagecount ? int($pagecount) : 0
    };

    return $arcdata;
}

#Deletes the archive with the given id from redis, and the matching archive file/thumbnail.
sub delete_archive {

    my $id       = $_[0];
    my $redis    = LANraragi::Model::Config->get_redis;
    my $filename = $redis->hget( $id, "file" );

    $redis->del($id);
    $redis->quit();

    if ( -e $filename ) {
        unlink $filename;

        my $thumbdir  = LANraragi::Model::Config->get_thumbdir;
        my $subfolder = substr( $id, 0, 2 );
        my $thumbname = "$thumbdir/$subfolder/$id.jpg";

        unlink $thumbname;

        return $filename;
    }

    return "0";
}

# drop_database()
# Drops the entire database. Hella dangerous
sub drop_database {
    my $redis = LANraragi::Model::Config->get_redis;

    $redis->flushall();
    $redis->quit;
}

# clean_database()
# Remove entries from the database that don't have a matching archive on the filesystem.
# Returns the number of entries deleted/unlinked.
sub clean_database {
    my $redis = LANraragi::Model::Config->get_redis;
    my $logger = get_logger( "Archive", "lanraragi" );

    eval {
        # Save an autobackup somewhere before cleaning
        my $outfile = getcwd() . "/autobackup.json";
        open( my $fh, '>', $outfile );
        print $fh LANraragi::Model::Backup::build_backup_JSON();
        close $fh;
    };

    if ($@) {
        $logger->warn("Unable to open a file to save backup before cleaning database! $@");
    }

    # Get the filemap for ID checks later down the line
    my @filemapids = $redis->exists("LRR_FILEMAP") ? $redis->hvals("LRR_FILEMAP") : ();
    my %filemap = map { $_ => 1 } @filemapids;

    #40-character long keys only => Archive IDs
    my @keys = $redis->keys('????????????????????????????????????????');

    my $deleted_arcs  = 0;
    my $unlinked_arcs = 0;

    foreach my $id (@keys) {

        # Check if the DB entry is correct
        eval { $redis->hgetall($id); };

        if ($@) {
            $redis->del($id);
            $deleted_arcs++;
            next;
        }

        # Check if the linked file exists
        my $file = $redis->hget( $id, "file" );
        unless ( -e $file ) {
            $redis->del($id);
            $deleted_arcs++;
            next;
        }

        unless ( $file eq "" || exists $filemap{$id} ) {
            $logger->warn("File exists but its ID is no longer $id -- Removing file reference in its database entry.");
            $redis->hset( $id, "file", "" );
            $unlinked_arcs++;
        }
    }

    $redis->quit;
    return ( $deleted_arcs, $unlinked_arcs );
}

#add_tags($id, $tags)
#add the $tags to the archive with id $id.
sub add_tags {

    my ( $id, $newtags ) = @_;

    my $redis = LANraragi::Model::Config->get_redis;
    my $oldtags = $redis->hget( $id, "tags" );
    $oldtags = redis_decode($oldtags);

    if ( length $newtags ) {

        if ($oldtags) {
            remove_spaces($oldtags);

            if ( $oldtags ne "" ) {
                $newtags = $oldtags . "," . $newtags;
            }
        }

        $redis->hset( $id, "tags", redis_encode($newtags) );
    }
    $redis->quit;
}

sub set_title {

    my ( $id, $newtitle ) = @_;
    my $redis = LANraragi::Model::Config->get_redis;

    if ( $newtitle ne "" ) {
        $redis->hset( $id, "title", redis_encode($newtitle) );
    }
    $redis->quit;
}

#This function is used for all ID computation in LRR.
#Takes the path to the file as an argument.
sub compute_id {

    my $file = $_[0];

    #Read the first 512 KBs only (allows for faster disk speeds )
    open( my $handle, '<', $file ) or die "Couldn't open $file :" . $!;
    my $data;
    my $len = read $handle, $data, 512000;
    close $handle;

    #Compute a SHA-1 hash of this data
    my $ctx = Digest::SHA->new(1);
    $ctx->add($data);
    my $digest = $ctx->hexdigest;

    if ( $digest eq "da39a3ee5e6b4b0d3255bfef95601890afd80709" ) {
        die "Computed ID is for a null value, invalid source file.";
    }

    return $digest;

}

# Normalize the string to Unicode NFC, then layer on redis_encode for Redis-safe serialization.
sub redis_encode {

    my $data     = $_[0];
    my $NFC_data = NFC($data);

    return encode_utf8($NFC_data);
}

#Final Solution to the Unicode glitches -- Eval'd double-decode for data obtained from Redis.
#This should be a one size fits-all function.
sub redis_decode {

    my $data = $_[0];

    # Setting FB_CROAK tells encode to die instantly if it encounters any errors.
    # Without this setting, it typically tries to replace characters... which might already be valid UTF8!
    eval { $data = decode_utf8( $data, Encode::FB_CROAK ) };

    # Do another UTF-8 decode just in case the data was double-encoded
    eval { $data = decode_utf8( $data, Encode::FB_CROAK ) };

    return $data;
}

# Bust the current search cache key in Redis.
# Add "1" as a parameter to perform a cache warm after the wipe.
sub invalidate_cache {
    my $do_warm = shift;
    my $redis   = LANraragi::Model::Config->get_redis;
    $redis->del("LRR_SEARCHCACHE");
    $redis->hset( "LRR_SEARCHCACHE", "created", time );
    $redis->quit();

    # Re-warm the cache to ensure sufficient speed on the main index
    if ($do_warm) {
        LANraragi::Model::Config->get_minion->enqueue( warm_cache        => [] => { priority => 3 } );
        LANraragi::Model::Config->get_minion->enqueue( build_stat_hashes => [] => { priority => 3 } );
    }
}

# Go through the search cache and only invalidate keys that rely on isNew.
sub invalidate_isnew_cache {

    my $redis = LANraragi::Model::Config->get_redis;
    my %cache = $redis->hgetall("LRR_SEARCHCACHE");

    foreach my $cachekey ( keys(%cache) ) {

        # A cached search uses isNew if the second to last number is equal to 1
        # i.e, "--title-asc-1-0" has to be pruned
        if ( $cachekey =~ /.*-.*-.*-.*-1-\d?/ ) {
            $redis->hdel( "LRR_SEARCHCACHE", $cachekey );
        }
    }
    $redis->quit();
}

sub save_computed_tagrules {
    my ($tagrules) = @_;
    my $redis = LANraragi::Model::Config->get_redis;
    $redis->del("LRR_TAGRULES");
    $redis->lpush( "LRR_TAGRULES", reverse flat(@$tagrules) ) if (@$tagrules);
    $redis->quit();
    return;
}

sub get_computed_tagrules {
    my @tagrules;

    my $redis = LANraragi::Model::Config->get_redis;

    if ( $redis->exists("LRR_TAGRULES") ) {
        my @flattened_rules = $redis->lrange( "LRR_TAGRULES", 0, -1 );
        @tagrules = unflat_tagrules( \@flattened_rules );
    } else {
        @tagrules = tags_rules_to_array( restore_CRLF( LANraragi::Model::Config->get_tagrules ) );
        $redis->lpush( "LRR_TAGRULES", reverse flat(@tagrules) ) if (@tagrules);
    }

    $redis->quit();
    return @tagrules;
}

1;
