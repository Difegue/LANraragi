package LANraragi::Model::Index;

use strict;
use warnings;
use utf8;

use List::Util qw(min);
use Redis;
use Encode;
use Mojo::JSON qw(decode_json encode_json);

use LANraragi::Utils::Generic;
use LANraragi::Utils::Archive;
use LANraragi::Utils::Database;

use LANraragi::Model::Config;

# 
sub do_search {

    my ( $search, $page, $sortkey, $sortorder) = @_;

    my $redis = LANraragi::Model::Config::get_redis;

    my $logger =
      LANraragi::Utils::Generic::get_logger( "Search Engine", "lanraragi" );

    # Get all archives from redis
    my @keys = $redis->keys('????????????????????????????????????????');
    my @filtered;

    # Go through tags and apply search filter
    # TODO: subprocess this by chunks for s p e e d
    foreach my $id (@keys) {
        my $metadata = $redis->hget($id, "tags");

        if (matches_search_filter($search, $metadata)) {
            # Push id to array
            push @filtered, $id;          
        }
    }

    if ($filtered > 0) {
        # Sort by the required metadata (default is title)
        @filtered = sort { 

            if ($sortorder) {
                lc($redis->hget($a, $sortkey)) cmp lc($redis->hget($b, $sortkey))
            } else {
                lc($redis->hget($b, $sortkey)) cmp lc($redis->hget($a, $sortkey))
            }

        } @filtered;
    }
    
    # Only get the first X keys
    # TODO: cache @filtered
    my $keysperpage = LANraragi::Model::Config::get_pagesize;

    # Return total keys and the filterd ones
    return ( $#keys, @filtered[0..min($keysperpage,$#filtered)] );
}

# matches_search_filter($filter, $tags)
sub matches_search_filter {

}

# create_json($keys)
sub create_json {

}


1;