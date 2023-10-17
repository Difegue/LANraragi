package LANraragi::Model::Stats;

use strict;
use warnings;
use utf8;

use Redis;
use File::Find;
use Mojo::JSON qw(encode_json);

use LANraragi::Utils::Generic qw(is_archive);
use LANraragi::Utils::String qw(trim trim_CRLF trim_url);
use LANraragi::Utils::Database qw(redis_decode redis_encode);
use LANraragi::Utils::Logging qw(get_logger);

sub get_archive_count {
    my $redis  = LANraragi::Model::Config->get_redis_search;
    return $redis->zcard("LRR_TITLES") + 0;    # Total number of archives (as int)
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
# - LRR_TITLES, which is a lexicographically sorted set containing all titles in the DB, alongside their ID. (In the "title\0ID" format)
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

    # Cancel the transaction if the hashes have been modified by another job in the meantime.
    # This also allows for the previous stats/map to still be readable until we're done.
    $redistx->watch( "LRR_STATS", "LRR_URLMAP", "LRR_UNTAGGED", "LRR_TITLES", "LRR_NEW" );
    $redistx->multi;

    # Hose the entire index DB since we're rebuilding it
    $redistx->flushdb();

    # Iterate on hashes to get their tags
    $logger->info("Building stat indexes... ($archive_count archives)");

    # TODO go through tanks first, and remove their IDs from @keys

    foreach my $id (@keys) {
        if ( $redis->hexists( $id, "tags" ) ) {

            my $rawtags = $redis->hget( $id, "tags" );

            # Split tags by comma
            my @tags     = split( /,\s?/, redis_decode($rawtags) );
            my $has_tags = 0;

            foreach my $t (@tags) {
                $t = trim($t);
                $t = trim_CRLF($t);

                # The following are basic and therefore don't count as "tagged"
                $has_tags = 1 unless $t =~ /(artist|parody|series|language|event|group|date_added|timestamp):.*/;

                # If the tag is a source: tag, add it to the URL index
                if ( $t =~ /source:(.*)/i ) {
                    my $url = trim_url($1);
                    $logger->trace("Adding $url as an URL for $id");
                    $redistx->hset( "LRR_URLMAP", $url, $id );  # No need to encode the value, as URLs are already encoded by design
                }

                # Tag is lowercased here to avoid redundancy/dupes
                my $redis_tag = redis_encode( lc($t) );

                # Increment tag in stats
                $redistx->zincrby( "LRR_STATS", 1, $redis_tag );

                # Add the archive ID to the set for this tag
                $redistx->sadd( "INDEX_" . $redis_tag, $id );
            }

            # Flag the ID as untagged if it had no tags
            unless ($has_tags) {
                $logger->trace("Adding $id to LRR_UNTAGGED");
                $redistx->sadd( "LRR_UNTAGGED", $id );
            }
        }

        if ( $redis->hexists( $id, "title" ) ) {
            my $title = $redis->hget( $id, "title" );

            # Decode and lowercase the title
            $title = lc( redis_decode($title) );
            $title = trim($title);
            $title = trim_CRLF($title);
            $title = redis_encode($title);

            # The LRR_TITLES lexicographically sorted set contains both the title and the id under the form $title\x00$id.
            $redistx->zadd( "LRR_TITLES", 0, "$title\0$id" );
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
    $logger->info("Stat indexes built! ($archive_count archives)");
    $redis->quit;
    $redistx->quit;
}

sub is_url_recorded {

    my $url    = $_[0];
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
        LANraragi::Utils::Database::get_arcsize($redis_db, $id);
    }
    my @result = $redis_db->exec;
    $redis_db->quit;

    my $size = 0;
    foreach my $row (@result) {
        if (defined($row)) {
            $size = $size + $row;
        }
    }

    return int( $size / 1073741824 * 100 ) / 100;
}

1;
