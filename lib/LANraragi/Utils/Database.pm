package LANraragi::Utils::Database;

use strict;
use warnings;
use utf8;

use feature qw(signatures);
no warnings 'experimental::signatures';

use Digest::SHA qw(sha256_hex);
use Mojo::JSON  qw(decode_json);
use Encode;
use File::Basename;
use Redis;
use Cwd;
use Unicode::Normalize;
use List::MoreUtils qw(uniq);

use LANraragi::Utils::Generic qw(flat);
use LANraragi::Utils::String  qw(trim trim_CRLF trim_url);
use LANraragi::Utils::Tags    qw(unflat_tagrules tags_rules_to_array restore_CRLF join_tags_to_string split_tags_to_array );
use LANraragi::Utils::Archive qw(get_filelist);
use LANraragi::Utils::Logging qw(get_logger);

# Functions for interacting with the DB Model.
use Exporter 'import';
our @EXPORT_OK =
  qw(redis_encode redis_decode invalidate_cache compute_id change_archive_id set_tags set_title set_isnew get_computed_tagrules save_computed_tagrules get_archive_json get_archive_json_multi get_tankoubons_by_file);

# Creates a DB entry for a file path with the given ID.
# This function doesn't actually require the file to exist at its given location.
sub add_archive_to_redis ( $id, $file, $redis ) {

    my $logger = get_logger( "Archive", "lanraragi" );
    my ( $name, $path, $suffix ) = fileparse( $file, qr/\.[^.]*/ );

    # Initialize Redis hash for the added file
    $logger->debug("Pushing to redis on ID $id:");
    $logger->debug("File Name: $name");
    $logger->debug("Filesystem Path: $file");

    $redis->hset( $id, "name", redis_encode($name) );
    $redis->hset( $id, "tags", "" );
    if ( defined($file) && -e $file ) {
        $redis->hset( $id, "arcsize", -s $file );
    }

    # Don't encode filenames.
    $redis->hset( $id, "file", $file );

    # Set title so that index is updated
    # Throw a decode in there just in case the filename is already UTF8
    set_title( $id, redis_decode($name) );

    # New file in collection, so this flag is set.
    set_isnew( $id, "true" );

    $redis->quit;
    return $name;
}

# Updates the DB entry for the given ID to reflect the new ID.
# This is used in case the file changes substantially and its hash becomes different.
sub change_archive_id ( $old_id, $new_id ) {

    my $logger = get_logger( "Archive", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis;

    $logger->debug("Changing ID $old_id to $new_id");

    if ( $redis->exists($old_id) ) {
        $redis->rename( $old_id, $new_id );
    }

    # Update archive size
    my $file = $redis->hget( $new_id, "file" );
    $redis->hset( $new_id, "arcsize", -s $file );
    $redis->quit;

    # Update categories that contain the ID.
    $logger->debug("Updating categories that contained $old_id to $new_id.");
    my @categories = LANraragi::Model::Category::get_categories_containing_archive($old_id);

    foreach my $cat (@categories) {
        my $catid = %{$cat}{"id"};
        $logger->warn("Updating category $catid");
        LANraragi::Model::Category::remove_from_category( $catid, $old_id );
        LANraragi::Model::Category::add_to_category( $catid, $new_id );
    }

    # Update tanks that contain the ID
    $logger->debug("Updating tankoubons that contained $old_id to $new_id.");
    my @tanks = LANraragi::Model::Tankoubon::get_tankoubons_containing_archive($old_id);

    foreach my $tank (@tanks) {
        $logger->warn("Updating tankoubon $tank");
        LANraragi::Model::Tankoubon::remove_from_tankoubon( $tank, $old_id );
        LANraragi::Model::Tankoubon::add_to_tankoubon( $tank, $new_id );
    }
}

# Adds a timestamp tag to the given ID.
sub add_timestamp_tag ( $redis, $id ) {

    my $logger = get_logger( "Archive", "lanraragi" );

    # Initialize tags to the current date if the matching pref is enabled
    if ( LANraragi::Model::Config->enable_dateadded eq "1" ) {

        $logger->debug("Adding timestamp tag...");
        my $date;

        if ( LANraragi::Model::Config->use_lastmodified eq "1" ) {
            $logger->debug("Using file date");
            $date = ( stat( $redis->hget( $id, "file" ) ) )[9];    #9 is the unix time stamp for date modified.
        } else {
            $logger->debug("Using current date");
            $date = time();
        }

        set_tags( $id, "date_added:$date", 1 );
    }
}

# Calculates and adds pagecount to the given ID.
sub add_pagecount ( $redis, $id ) {

    my $logger = get_logger( "Archive", "lanraragi" );

    my $file = $redis->hget( $id, "file" );
    my ( $images, $sizes ) = get_filelist($file);
    my @images = @$images;
    $redis->hset( $id, "pagecount", scalar @images );
}

# Builds a JSON object for an archive registered in the database and returns it.
# If you need to get many JSONs at once, use the multi variant.
sub get_archive_json ( $redis, $id ) {

    my $arcdata;

    eval {
        #Extra check in case we've been given a bogus ID
        die unless $redis->exists($id);

        my %hash = $redis->hgetall($id);
        $arcdata = build_json( $id, %hash );
    };

    return $arcdata;
}

# Uses Redis' MULTI to get an archive JSON for each ID.
sub get_archive_json_multi (@ids) {

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
sub build_json ( $id, %hash ) {

    # It's not a new archive, but it might have never been clicked on yet,
    # so grab the value for $isnew stored in redis.
    my ( $name, $title, $tags, $file, $isnew, $progress, $pagecount, $lastreadtime, $arcsize ) =
      @hash{qw(name title tags file isnew progress pagecount lastreadtime arcsize)};

    # Return undef if the file doesn't exist.
    return unless ( defined($file) && -e $file );

    # Parameters have been obtained, let's decode them.
    ( $_ = redis_decode($_) ) for ( $name, $title, $tags );

    # Workaround if title was incorrectly parsed as blank
    if ( !defined($title) || $title =~ /^\s*$/ ) {
        $title = $name;
    }

    my $arcdata = {
        arcid        => $id,
        title        => $title,
        filename     => $name,
        tags         => $tags,
        isnew        => $isnew ? $isnew : "false",
        extension    => lc( ( split( /\./, $file ) )[-1] ),
        progress     => $progress     ? int($progress)     : 0,
        pagecount    => $pagecount    ? int($pagecount)    : 0,
        lastreadtime => $lastreadtime ? int($lastreadtime) : 0,
        size         => $arcsize      ? int($arcsize)      : 0
    };

    return $arcdata;
}

# drop_database()
# Drops the entire database. Hella dangerous
# TODO: Might be worth it to add versions that only do flushdb on certain databases like the config/archive data one?
sub drop_database {
    my $redis = LANraragi::Model::Config->get_redis;

    $redis->flushall();
    $redis->quit;
}

# clean_database()
# Remove entries from the database that don't have a matching archive on the filesystem.
# Returns the number of entries deleted/unlinked.
sub clean_database {
    my $redis        = LANraragi::Model::Config->get_redis;
    my $redis_config = LANraragi::Model::Config->get_redis_config;
    my $logger       = get_logger( "Archive", "lanraragi" );

    eval {
        # Save an autobackup somewhere before cleaning
        my $outfile = getcwd() . "/autobackup.json";
        $logger->info("Saving automatic backup to $outfile");
        open( my $fh, '>', $outfile );
        print $fh LANraragi::Model::Backup::build_backup_JSON();
        close $fh;
    };

    if ($@) {
        $logger->warn("Unable to open a file to save backup before cleaning database! $@");
    }

    # Get the filemap for ID checks later down the line
    my @filemapids = $redis_config->exists("LRR_FILEMAP") ? $redis_config->hvals("LRR_FILEMAP") : ();
    my %filemap    = map { $_ => 1 } @filemapids;

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

        # If the linked file exists, check if its ID is in the filemap
        unless ( $file eq "" || exists $filemap{$id} ) {
            $logger->warn("File exists but its ID is no longer $id!");
            $logger->warn("Trying to find its new ID in the Shinobu filemap...");

            if ( $redis_config->hexists( "LRR_FILEMAP", $file ) ) {
                my $newid = $redis_config->hget( "LRR_FILEMAP", $file );
                $logger->warn("Found $newid in the filemap! Changing ID from $id to it.");

                if ( $redis->exists($newid) ) {
                    $logger->warn("ID $newid already exists in the database! Unlinking old ID.");
                    $redis->hset( $id, "file", "" );
                } else {
                    change_archive_id( $id, $newid );
                    $redis_config->hset( "LRR_FILEMAP", $file, $newid );
                }

            } else {
                $logger->warn("File $file not found in the filemap! Removing file reference in the database entry for $id.");
                $redis->hset( $id, "file", "" );
                $unlinked_arcs++;
            }

        }
    }

    $redis->quit;
    $redis_config->quit;
    return ( $deleted_arcs, $unlinked_arcs );
}

sub set_title ( $id, $newtitle ) {

    my $redis        = LANraragi::Model::Config->get_redis;
    my $redis_search = LANraragi::Model::Config->get_redis_search;

    if ( $newtitle ne "" ) {

        # Remove old title from search set
        if ( $redis->hexists( $id, "title" ) ) {
            my $oldtitle = lc( redis_decode( $redis->hget( $id, "title" ) ) );
            $oldtitle = trim($oldtitle);
            $oldtitle = trim_CRLF($oldtitle);
            $oldtitle = redis_encode($oldtitle);
            $redis_search->zrem( "LRR_TITLES", "$oldtitle\0$id" );
        }

        # Set actual title in metadata DB
        $redis->hset( $id, "title", redis_encode($newtitle) );

        # Set title/ID key in search set
        $newtitle = lc($newtitle);
        $newtitle = trim($newtitle);
        $newtitle = trim_CRLF($newtitle);
        $newtitle = redis_encode($newtitle);
        $redis_search->zadd( "LRR_TITLES", 0, "$newtitle\0$id" );
    }
    $redis->quit;
    $redis_search->quit;
}

# Set $tags for the archive with id $id.
# Set $append to 1 if you want to append the tags instead of replacing them.
sub set_tags ( $id, $newtags, $append = 0 ) {

    my $redis   = LANraragi::Model::Config->get_redis;
    my $oldtags = $redis->hget( $id, "tags" );
    $oldtags = redis_decode($oldtags);

    if ($append) {

        # If the new tags are empty, don't do anything
        unless ( length $newtags ) { return; }

        if ($oldtags) {
            $oldtags = trim($oldtags);

            if ( $oldtags ne "" ) {
                $newtags = $oldtags . "," . $newtags;
            }
        }
    }

    $newtags = join_tags_to_string( uniq( split_tags_to_array($newtags) ) );

    # Update sets depending on the added/removed tags
    update_indexes( $id, $oldtags, $newtags );

    $redis->hset( $id, "tags", redis_encode($newtags) );
    $redis->quit;

    invalidate_cache();
}

# Set $isnew for the archive with id $id.
sub set_isnew ( $id, $isnew ) {

    my $redis        = LANraragi::Model::Config->get_redis;
    my $redis_search = LANraragi::Model::Config->get_redis_search;

    # Just set isnew for the provided ID.
    my $newval = $isnew ne "false" ? "true" : "false";

    $redis->hset( $id, "isnew", $newval );

    if ( $newval eq "true" ) {
        $redis_search->sadd( "LRR_NEW", $id );
    } else {
        $redis_search->srem( "LRR_NEW", $id );
    }

    $redis_search->quit;
    $redis->quit;

    invalidate_cache();
}

# Splits both old and new tags, and:
# Removes the ID from all sets of the old tags
# Adds it back to all sets of the new tags.
sub update_indexes ( $id, $oldtags, $newtags ) {

    my $redis = LANraragi::Model::Config->get_redis_search;
    $redis->multi;

    my @oldtags  = split( /,\s?/, $oldtags // "" );
    my @newtags  = split( /,\s?/, $newtags // "" );
    my $has_tags = 0;

    foreach my $tag (@oldtags) {

        if ( $tag =~ /source:(.*)/i ) {
            my $url = trim_url($1);
            $redis->hdel( "LRR_URLMAP", $url );
        }

        # Tag is lowercased here to avoid redundancy/dupes
        $redis->srem( "INDEX_" . redis_encode( lc($tag) ), $id );
    }

    foreach my $tag (@newtags) {

        # The following are basic and therefore don't count as "tagged"
        $has_tags = 1 unless $tag =~ /(artist|parody|series|language|event|group|date_added|timestamp):.*/;

        # If the tag is a source: tag, add it to the URL index
        if ( $tag =~ /source:(.*)/i ) {
            my $url = trim_url($1);
            $redis->hset( "LRR_URLMAP", $url, $id );
        }

        $redis->sadd( "INDEX_" . redis_encode( lc($tag) ), $id );
    }

    # Add or remove the ID from the untagged list
    if ($has_tags) {
        $redis->srem( "LRR_UNTAGGED", $id );
    } else {
        $redis->sadd( "LRR_UNTAGGED", $id );
    }

    $redis->exec;
    $redis->quit;
}

# This function is used for all ID computation in LRR.
# Takes the path to the file as an argument.
sub compute_id ($file) {

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
sub redis_encode ($data) {

    my $NFC_data = NFC($data);
    return encode_utf8($NFC_data);
}

# Final Solution to the Unicode glitches -- Eval'd double-decode for data obtained from Redis.
# This should be a one size fits-all function.
sub redis_decode ($data) {

    # Setting FB_CROAK tells encode to die instantly if it encounters any errors.
    # Without this setting, it typically tries to replace characters... which might already be valid UTF8!
    eval { $data = decode_utf8( $data, Encode::FB_CROAK ) };

    # Do another UTF-8 decode just in case the data was double-encoded
    eval { $data = decode_utf8( $data, Encode::FB_CROAK ) };

    return $data;
}

# Bust the current search cache key in Redis.
# Add "1" as a parameter to rebuild stat hashes as well. (Use with caution!)
sub invalidate_cache ( $rebuild_indexes = 0 ) {

    my $redis = LANraragi::Model::Config->get_redis_search;
    $redis->del("LRR_SEARCHCACHE");
    $redis->hset( "LRR_SEARCHCACHE", "created", time );
    $redis->quit();

    # Re-warm the cache to ensure sufficient speed on the main index
    if ($rebuild_indexes) {
        LANraragi::Model::Config->get_minion->enqueue( build_stat_hashes => [] => { priority => 3 } );
    }
}

sub save_computed_tagrules ($tagrules) {

    my $redis = LANraragi::Model::Config->get_redis_config;
    $redis->del("LRR_TAGRULES");

    if (@$tagrules) {
        my @flat         = reverse flat(@$tagrules);
        my @encoded_flat = map { redis_encode($_) } @flat;
        $redis->lpush( "LRR_TAGRULES", @encoded_flat );
    }

    $redis->quit();
    return;
}

sub get_computed_tagrules {
    my @tagrules;

    my $redis = LANraragi::Model::Config->get_redis_config;

    if ( $redis->exists("LRR_TAGRULES") ) {
        my @flattened_rules = $redis->lrange( "LRR_TAGRULES", 0, -1 );
        my @decoded_rules   = map { redis_decode($_) } @flattened_rules;
        @tagrules = unflat_tagrules( \@decoded_rules );
    } else {
        @tagrules = tags_rules_to_array( restore_CRLF( LANraragi::Model::Config->get_tagrules ) );
        $redis->lpush( "LRR_TAGRULES", reverse flat(@tagrules) ) if (@tagrules);
    }

    $redis->quit();
    return @tagrules;
}

sub add_arcsize ( $redis, $id ) {
    my $file = $redis->hget( $id, "file" );
    $redis->hset( $id, "arcsize", -s $file );
}

sub get_arcsize ( $redis, $id ) {
    return $redis->hget( $id, "arcsize" );
}

1;
