package LANraragi::Model::Stats;

use strict;
use warnings;
use utf8;

use Redis;
use File::Find;
use Mojo::JSON qw(encode_json);

use LANraragi::Utils::Generic qw(remove_spaces remove_newlines is_archive trim_url);
use LANraragi::Utils::Database qw(redis_decode redis_encode);
use LANraragi::Utils::Logging qw(get_logger);

sub get_archive_count {

    #We can't trust the DB to contain the exact amount of files,
    #As deleted files are still kept in store.
    my $dirname = LANraragi::Model::Config->get_userdir;
    my $count   = 0;

    #Count files the old-fashioned way instead
    find(
        {   wanted => sub {
                return if -d $_;    #Directories are excluded on the spot
                if ( is_archive($_) ) {
                    $count++;
                }
            },
            no_chdir    => 1,
            follow_fast => 1
        },
        $dirname
    );
    return $count;
}

sub get_page_stat {

    my $redis = LANraragi::Model::Config->get_redis;
    my $stat = $redis->get("LRR_TOTALPAGESTAT") || 0;
    $redis->quit();

    return $stat;
}

# This operation builds the following hashes:
# - LRR_URL_MAP, which maps URLs to IDs in the database that have them as a source: tag
# - LRR_STATS, which is a sorted set used to build the statistics/tag cloud JSON
# - LRR_UNTAGGED, which is a set used by the untagged archives API
# - LRR_TITLES, which is a set containing all titles in the DB, alongside their ID. (In the "title\0ID" format)
# * It also builds index sets for each distinct tag.
sub build_stat_hashes {

  # This method does only one atomic write transaction, using Redis' watch/multi mode.
  # But we can't use the connection to get other data while it's in transaction mode!
  # So we instantiate a second connection to get the data we need. Helps as well now that both connections are made on separate DBs.
    my $redis   = LANraragi::Model::Config->get_redis;
    my $redistx = LANraragi::Model::Config->get_redis_search;
    my $logger  = get_logger( "Tag Stats", "lanraragi" );

    # 40-character long keys only => Archive IDs
    my @keys = $redis->keys('????????????????????????????????????????');

    # Cancel the transaction if the hashes have been modified by another job in the meantime.
    # This also allows for the previous stats/map to still be readable until we're done.
    $redistx->watch( "LRR_STATS", "LRR_URLMAP", "LRR_UNTAGGED", "LRR_TITLES" );
    $redistx->multi;

    # Hose the entire index DB since we're rebuilding it
    $redistx->flushdb();

    # Iterate on hashes to get their tags
    $logger->debug("Building stat indexes...");
    foreach my $id (@keys) {
        if ( $redis->hexists( $id, "tags" ) ) {

            my $rawtags = $redis->hget( $id, "tags" );

            # Split tags by comma
            my @tags = split( /,\s?/, redis_decode($rawtags) );
            my $has_tags = 0;

            foreach my $t (@tags) {
                remove_spaces($t);
                remove_newlines($t);

                # The following are basic and therefore don't count as "tagged"
                $has_tags = 1 unless $t =~ /(artist|parody|series|language|event|group|date_added|timestamp):.*/;

                # If the tag is a source: tag, add it to the URL index
                if ( $t =~ /source:(.*)/i ) {
                    my $url = $1;
                    trim_url($url);
                    $logger->debug("Adding $url as an URL for $id");
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
                $redistx->sadd( "LRR_UNTAGGED", $id );
            }
        }

        if ( $redis->hexists( $id, "title" ) ) {
            my $title = $redis->hget( $id, "title" );

            # Decode and lowercase the title
            $title = lc( redis_decode($title) );
            remove_spaces($title);
            remove_newlines($title);
            $title = redis_encode($title);

            # The LRR_TITLES set contains both the title and the id under the form $title\x00$id.
            $redistx->sadd( "LRR_TITLES", "$title\0$id" );
        }
    }

    $redistx->exec;
    $logger->debug("Done!");
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
    trim_url($url);

    if ( $redis->hexists( "LRR_URLMAP", $url ) ) {
        $id = $redis->hget( "LRR_URLMAP", $url );
        $logger->debug("Found! id $id.");
    }
    $redis->quit;
    return $id;
}

sub build_tag_stats {

    my $minscore = shift;
    my $logger = get_logger( "Tag Stats", "lanraragi" );
    $logger->debug("Serving tag statistics with a minimum weight of $minscore");

    # Login to Redis and grab the stats sorted set
    my $redis = LANraragi::Model::Config->get_redis_search;
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

    #Get size of archive folder
    my $dirname = LANraragi::Model::Config->get_userdir;
    my $size    = 0;

    find( sub { $size += -s if -f }, $dirname );

    return int( $size / 1073741824 * 100 ) / 100;
}

1;
