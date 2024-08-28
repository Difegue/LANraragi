package LANraragi::Model::Stats;

use feature qw(signatures);
no warnings 'experimental::signatures';

use strict;
use warnings;
use utf8;

use Redis;
use File::Find;
use Mojo::JSON qw(encode_json);
use LANraragi::Model::Tankoubon;

use LANraragi::Utils::Generic  qw(is_archive intersect_arrays);
use LANraragi::Utils::String   qw(trim trim_CRLF trim_url);
use LANraragi::Utils::Database qw(redis_decode redis_encode);
use LANraragi::Utils::Logging  qw(get_logger);

sub get_archive_count {
    my $redis = LANraragi::Model::Config->get_redis_search;
    my $tankcount = $redis->scard("LRR_TANKGROUPED") + 0;

    return $redis->zcard("LRR_TITLES") - $tankcount;   
    # Total number of archives (as int) -- Tanks are included and replace the archives they contain. 
}

sub get_page_stat {

    my $redis = LANraragi::Model::Config->get_redis_config;
    my $stat  = $redis->get("LRR_TOTALPAGESTAT") || 0;
    $redis->quit();

    return $stat;
}

# This operation builds the following hashes:
# - LRR_URL_MAP, which maps URLs to IDs in the database that have them as a source: tag
# - LRR_STATS, which is a sorted set used to build the statistics/tag cloud JSON
# - LRR_UNTAGGED, which is a set used by the untagged archives API
# - LRR_NEW, which contains all archives that have isnew=true
# - LRR_TITLES, which is a lexicographically sorted set containing all (archive + tank) titles in the DB, alongside their ID. (In the "title\0ID" format)
# - LRR_TANKGROUPED, which is a set containing all tank IDs in the DB, and the archive IDs that aren't in any tanks. 
# * It also builds index sets for each distinct tag.
sub build_stat_hashes {

  # This method does only one atomic write transaction, using Redis' watch/multi mode.
  # But we can't use the connection to get other data while it's in transaction mode!
  # So we instantiate a second connection to get the data we need. Helps as well now that both connections are made on separate DBs.
    my $redis   = LANraragi::Model::Config->get_redis;
    my $redistx = LANraragi::Model::Config->get_redis_search;
    my $logger  = get_logger( "Tag Stats", "lanraragi" );

    # 40-character long keys only => Archive IDs
    my @keys          = $redis->keys('????????????????????????????????????????');
    my $archive_count = scalar @keys;
    my ( $total, $filtered, @tanks ) = LANraragi::Model::Tankoubon::get_tankoubon_list(-1);

    # Cancel the transaction if the hashes have been modified by another job in the meantime.
    # This also allows for the previous stats/map to still be readable until we're done.
    $redistx->watch( "LRR_STATS", "LRR_URLMAP", "LRR_UNTAGGED", "LRR_TITLES", "LRR_NEW", "LRR_TANKGROUPED" );
    $redistx->multi;

    # Hose the entire index DB since we're rebuilding it
    $redistx->flushdb();

    # Iterate on hashes to get their tags
    $logger->info("Building stat indexes... ($archive_count archives, $total tankoubons)");

    # Go through tanks first
    foreach my $tank (@tanks) {

        my $tank_id = %$tank{id};
        my $tank_title = lc(%$tank{name});
        my @tank_archives = @{ %$tank{archives} };

        # Add the tank name to LRR_TITLES so it shows up in tagless searches when tank grouping is enabled.
        # (This does nothing if the tank is empty, as it won't be in LRR_TANKGROUPED) 
        $redistx->zadd( "LRR_TITLES", 0, "$tank_title\0$tank_id" );

        if (scalar @tank_archives == 0) {
            $logger->warn("Tank $tank_id has no archives in it. Skipping.");
            next;
        }

        $redistx->sadd( "LRR_TANKGROUPED",  $tank_id );

        # Remove IDs contained in the tank from @keys
        @keys = intersect_arrays( \@tank_archives, \@keys, 1 );

        foreach my $arcid (@tank_archives) {
            index_tags_for_id($redis, $redistx, $tank_id, $arcid); 
        }

        # Decode and lowercase the title
        $tank_title = trim($tank_title);
        $tank_title = trim_CRLF($tank_title);
        $tank_title = redis_encode($tank_title);
    }

    foreach my $id (@keys) {

        $redistx->sadd( "LRR_TANKGROUPED",  $id );
        my $has_tags = index_tags_for_id($redis, $redistx, $id, $id); 

        # Flag the ID as untagged if it had no tags
        unless ($has_tags) {
            $logger->trace("Adding $id to LRR_UNTAGGED");
            $redistx->sadd( "LRR_UNTAGGED", $id );
        }

        my $isnew = $redis->hget( $id, "isnew" );
        if ( $isnew && $isnew eq "true" ) {
            $logger->trace("Adding $id to LRR_ISNEW");
            $redistx->sadd( "LRR_NEW", $id );
        }
    }

    # Add a stamp to the stats hash to indicate when it was last updated
    $redistx->set( "LAST_JOB_TIME", time() );

    $redistx->exec;
    my $total_visible_archives = scalar @keys;
    $logger->info("Stat indexes built! ($total_visible_archives archives, $total tankoubons)");
    $redis->quit;
    $redistx->quit;
}

# Parse the tags of the given archive_id, 
# and add the given index_id to all the search indexes that contain said tags. 
sub index_tags_for_id($redis, $redistx, $index_id, $archive_id) {
    my $logger  = get_logger( "Tag Stats", "lanraragi" );
    my $has_tags = 0;

    unless ( $redis->hexists( $archive_id, "tags" ) ) {
        return 0;
    }

    # Split tags by comma and index them    
    my $rawtags = $redis->hget( $archive_id, "tags" );
    my @tags = split( /,\s?/, redis_decode($rawtags) );

    foreach my $t (@tags) {
        $t = trim($t);
        $t = trim_CRLF($t);

        # The following are basic and therefore don't count as "tagged"
        $has_tags = 1 unless $t =~ /(artist|parody|series|language|event|group|date_added|timestamp|source):.*/;

        # If the tag is a source: tag, add it to the URL index. This always uses the original archive ID. 
        if ( $t =~ /source:(.*)/i ) {
            my $url = trim_url($1);
            $logger->trace("Adding $url as an URL for $archive_id");
            $redistx->hset( "LRR_URLMAP", $url, $archive_id );  # No need to encode the value, as URLs are already encoded by design
        }

        # Tag is lowercased here to avoid redundancy/dupes
        my $redis_tag = redis_encode( lc($t) );

        # Increment tag in stats
        $redistx->zincrby( "LRR_STATS", 1, $redis_tag );

        # Add the archive ID and index ID to the set for this tag
        $logger->trace("Adding $index_id to the index for tag $redis_tag");
        $redistx->sadd( "INDEX_" . $redis_tag, $index_id );
        
        if ($index_id ne $archive_id) {
            $logger->trace("Adding $archive_id to the index for tag $redis_tag");
            $redistx->sadd( "INDEX_" . $redis_tag, $archive_id );
        }
    }

    if ( $redis->hexists( $archive_id, "title" ) ) {
        my $title = $redis->hget( $archive_id, "title" );

        # Decode and lowercase the title
        $title = lc( redis_decode($title) );
        $title = trim($title);
        $title = trim_CRLF($title);
        $title = redis_encode($title);

        # The LRR_TITLES lexicographically sorted set contains both the title and the id under the form $title\x00$id.
        $redistx->zadd( "LRR_TITLES", 0, "$title\0$archive_id" );
    }

    return $has_tags;
}

sub is_url_recorded($url) {

    my $logger = get_logger( "Tag Stats", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis_search;
    my $id     = 0;
    $logger->debug("Checking if url $url is in the url map.");

    # Trim last slash from url if it's present
    $url = trim_url($url);

    if ( $redis->hexists( "LRR_URLMAP", $url ) ) {
        $id = $redis->hget( "LRR_URLMAP", $url );
        $logger->debug("Found! id $id.");
    }
    $redis->quit;
    return $id;
}

sub build_tag_stats {

    my $minscore = shift;
    my $logger   = get_logger( "Tag Stats", "lanraragi" );
    $logger->debug("Serving tag statistics with a minimum weight of $minscore");

    # Login to Redis and grab the stats sorted set
    my $redis    = LANraragi::Model::Config->get_redis_search;
    my %tagcloud = $redis->zrangebyscore( "LRR_STATS", $minscore, "+inf", "WITHSCORES" );
    $redis->quit();

    # Go through the data from stats and build an array
    my @tags;

    for ( keys %tagcloud ) {
        my $w = $tagcloud{$_};

        # Split namespace
        # detect the : symbol and only use what's after it
        my $ns = "";
        my $t  = redis_decode($_);
        if ( $t =~ /([^:]*):(.*)/ ) { $ns = $1; $t = $2; }

        if ( $_ ne "" ) {
            my $j = { text => $t, namespace => $ns, weight => $w };
            push( @tags, $j );
        }
    }

    return \@tags;
}

sub compute_content_size {
    my $redis_db = LANraragi::Model::Config->get_redis;

    my @keys = $redis_db->keys('????????????????????????????????????????');

    $redis_db->multi;
    foreach my $id (@keys) {
        LANraragi::Utils::Database::get_arcsize( $redis_db, $id );
    }
    my @result = $redis_db->exec;
    $redis_db->quit;

    my $size = 0;
    foreach my $row (@result) {
        if ( defined($row) ) {
            $size = $size + $row;
        }
    }

    return int( $size / 1073741824 * 100 ) / 100;
}

1;
