package LANraragi::Model::Search;

use strict;
use warnings;
use utf8;

use List::Util qw(min);
use Redis;
use Encode;
use Storable qw/ nfreeze thaw /;
use Sort::Naturally;
use Sys::CpuAffinity;
use Parallel::Loops;
use Mojo::JSON qw(decode_json);

use LANraragi::Utils::Generic qw(split_workload_by_cpu);
use LANraragi::Utils::Database qw(redis_decode);
use LANraragi::Utils::Logging qw(get_logger);

use LANraragi::Model::Archive;
use LANraragi::Model::Category;

# do_search (filter, filter2, page, key, order, newonly, untaggedonly)
# Performs a search on the database.
sub do_search {

    my ( $filter, $category_id, $start, $sortkey, $sortorder, $newonly, $untaggedonly ) = @_;

    my $redis = LANraragi::Model::Config->get_redis_search;
    my $logger = get_logger( "Search Engine", "lanraragi" );

    # Search filter results
    my $total = $redis->hlen("LRR_FILEMAP") + 0;    # Total number of archives (as int)

    # Look in searchcache first
    my $sortorder_inv = $sortorder ? 0 : 1;
    my $cachekey      = encode_utf8("$category_id-$filter-$sortkey-$sortorder-$newonly-$untaggedonly");
    my $cachekey_inv  = encode_utf8("$category_id-$filter-$sortkey-$sortorder_inv-$newonly-$untaggedonly");
    my ( $cachehit, @filtered ) = check_cache( $cachekey, $cachekey_inv );

    unless ($cachehit) {
        $logger->debug("No cache available, doing a full DB parse.");
        @filtered = search_uncached( $category_id, $filter, $sortkey, $sortorder, $newonly, $untaggedonly );

        # Cache this query in the search database
        eval { $redis->hset( "LRR_SEARCHCACHE", $cachekey, nfreeze \@filtered ); };
    }
    $redis->quit();

    # If start is negative, return all possible data
    # Kind of a hack for the random API, not sure how this could be improved...
    # (The paging has always been there mostly to make datatables behave after all.)
    if ( $start == -1 ) {
        return ( $total, $#filtered + 1, @filtered );
    }

    # Only get the first X keys
    my $keysperpage = LANraragi::Model::Config->get_pagesize;

    # Return total keys and the filtered ones
    my $end = min( $start + $keysperpage - 1, $#filtered );
    return ( $total, $#filtered + 1, @filtered[ $start .. $end ] );
}

sub check_cache {

    my ( $cachekey, $cachekey_inv ) = @_;
    my $redis = LANraragi::Model::Config->get_redis_search;
    my $logger = get_logger( "Search Cache", "lanraragi" );

    my @filtered = ();
    my $cachehit = 0;
    $logger->debug("Search request: $cachekey");

    if ( $redis->exists("LRR_SEARCHCACHE") && $redis->hexists( "LRR_SEARCHCACHE", $cachekey ) ) {
        $logger->debug("Using cache for this query.");
        $cachehit = 1;

        # Thaw cache and use that as the filtered list
        my $frozendata = $redis->hget( "LRR_SEARCHCACHE", $cachekey );
        @filtered = @{ thaw $frozendata };

    } elsif ( $redis->exists("LRR_SEARCHCACHE") && $redis->hexists( "LRR_SEARCHCACHE", $cachekey_inv ) ) {
        $logger->debug("A cache key exists with the opposite sortorder.");
        $cachehit = 1;

        # Thaw cache, invert the list to match the sortorder and use that as the filtered list
        my $frozendata = $redis->hget( "LRR_SEARCHCACHE", $cachekey_inv );
        @filtered = reverse @{ thaw $frozendata };
    }

    $redis->quit();
    return ( $cachehit, @filtered );
}

# Grab all our IDs, then filter them down according to the following filters and tokens' ID groups.
sub search_uncached {

    my ( $category_id, $filter, $sortkey, $sortorder, $newonly, $untaggedonly ) = @_;
    my $redis = LANraragi::Model::Config->get_redis_search;
    my $logger = get_logger( "Search Core", "lanraragi" );

    # Compute search filters
    my @tokens = compute_search_filter($filter);

    # Prepare array: For each token, we'll have a list of matching archive IDs.
    # We intersect those lists as we proceed to get the final result.
    # Start with all our IDs.
    my @filtered = LANraragi::Model::Config->get_redis->keys('????????????????????????????????????????');

    # If we're using a category, we'll need to get its source data first.
    my %category = LANraragi::Model::Category::get_category($category_id);

    if (%category) {

        # We're using a category! Update its lastused value.
        $redis->hset( $category_id, "last_used", time() );

        # If the category is dynamic, get its search predicate and add it to the tokens.
        # If it's static however, we can use its ID list as the base for our result array.
        if ( $category{search} ne "" ) {
            my @cat_tokens = compute_search_filter( $category{search} );
            push @tokens, @cat_tokens;
        } else {
            @filtered = intersect_arrays( $category{archives}, \@filtered, 0 );
        }
    }

    # If the untagged filter is enabled, call the untagged files API
    if ($untaggedonly) {
        my @untagged = LANraragi::Model::Archive::find_untagged_archives();
        @filtered = intersect_arrays( \@untagged, \@filtered, 0 );
    }

    # Check new filter
    if ($newonly) {
        my @new = $redis->smembers("LRR_NEW");
        @filtered = intersect_arrays( \@new, \@filtered, 0 );
    }

    # Iterate through each token and intersect the results with the previous ones.
    unless ( scalar @tokens == 0 || scalar @filtered == 0 ) {
        foreach my $token (@tokens) {

            my $tag     = $token->{tag};
            my $isneg   = $token->{isneg};
            my $isexact = $token->{isexact};

            $logger->debug("Searching for $tag, isneg=$isneg, isexact=$isexact");

            my @ids = ();

            # Tags are always considered exact for now, so just check if an index for it exists
            if ( $redis->exists("INDEX_$tag") ) {

                # Get the list of IDs for this tag
                @ids = $redis->smembers("INDEX_$tag");
            }

            # Append fuzzy title search
            my $namesearch = $isexact ? $tag : "*$tag*";
            my $scan = -1;
            while ( $scan > 0 ) {

                # First iteration
                if ( $scan == -1 ) { $scan = 0; }
                $logger->debug("Scanning for $namesearch, cursor=$scan");

                my @result = $redis->zscan( "LRR_TITLES", $scan, "MATCH", $namesearch );
                $scan = $result[0];

                foreach my $title ( @{ $result[1] } ) {
                    $logger->debug("Found title match: $title");

                    # Strip everything before \x00 to get the ID out of the key
                    my $id = substr( $title, index( $title, "\x00" ) + 1 );
                    push @ids, $id;
                }
            }

            if ( scalar @ids == 0 && !$isneg ) {

                # No more results, we can end search here
                $logger->debug("No results for this token, halting search.");
                @filtered = ();
                last;
            } else {
                $logger->debug( "Found " . scalar @ids . " results for this token." );

                # Intersect the new list with the previous ones
                @filtered = intersect_arrays( \@ids, \@filtered, $isneg );
            }
        }
    }

    if ( $#filtered > 0 ) {

        if ( !$sortkey ) {
            $sortkey = "title";
        }

        # TODO Sort by the required metadata, asc or desc
        #@filtered = sort_results( $sortkey, $sortorder, @filtered );
    }

    return @filtered;
}

# intersect_arrays(@array1, @array2, $isneg)
# Intersect two arrays and return the result. If $isneg is true, return the difference instead.
sub intersect_arrays {

    my ( $array1, $array2, $isneg ) = @_;

    # Special case: If array1 is empty, just return array2 as we don't have anything to intersect yet
    if ( scalar @$array1 == 0 ) {
        return @$array2;
    }

    # If array2 is empty, die since this sub shouldn't even be used in that case
    if ( scalar @$array2 == 0 ) {
        die "intersect_arrays called with an empty array2";
    }

    my %hash = map { $_ => 1 } @$array1;
    my @result;

    if ($isneg) {
        @result = grep { !exists $hash{$_} } @$array2;
    } else {
        @result = grep { exists $hash{$_} } @$array2;
    }

    return @result;
}

# compute_search_filter($filter)
# Transform the search engine syntax into a list of tokens.
# A token object contains the tag, whether it must be an exact match, and whether it must be absent.
sub compute_search_filter {

    my $filter = shift;
    my $logger = get_logger( "Search Core", "lanraragi" );
    my @tokens = ();
    if ( !$filter ) { $filter = ""; }

    # Special characters:
    # "" for exact search (or $ but is that one really useful)
    # ?/_ for any character
    # * % for multiple characters
    # - to exclude the next tag

    $b = reverse($filter);
    while ( $b ne "" ) {

        my $char  = chop $b;
        my $isneg = 0;

        if ( $char eq "-" ) {
            $isneg = 1;
            $char  = chop $b;
        }

        # Get characters until the next space, or the next " if the following char is "
        my $delimiter = ' ';
        if ( $char eq '"' ) {
            $delimiter = '"';
            $char      = chop $b;
        }

        my $tag     = "";
        my $isexact = 0;
      TAGBUILD: while (1) {
            if ( $char eq $delimiter || $char eq "" ) { last TAGBUILD; }
            $tag  = $tag . $char;    # Add characters in reverse order since we used reverse earlier on
            $char = chop $b;
        }

        #If last char is $, enable isexact
        if ( $delimiter eq '"' ) {
            $char = chop $b;
            if ( $char eq "\$" ) {
                $isexact = 1;
            } else {
                $b = $b . $char;
            }
        } else {
            $char = chop $tag;
            if ( $char eq "\$" ) {
                $isexact = 1;
            } else {
                $tag = $tag . $char;
            }
        }

        # Escape already present regex characters
        $logger->debug("Pre-escaped tag: $tag");

        #$tag = quotemeta($tag);

        # Replace placeholders with glob-style patterns,
        # ? or _ => ?
        $tag =~ s/\_/\?/g;

        # * or % => *
        $tag =~ s/\%/\*/g;

        push @tokens,
          { tag     => $tag,
            isneg   => $isneg,
            isexact => $isexact
          };
    }
    return @tokens;
}

sub sort_results {

    my ( $sortkey, $sortorder, @filtered ) = @_;

    @filtered = sort {

        #Use either tags or title depending on the sortkey
        my $meta1 = $a->{title};
        my $meta2 = $b->{title};

        if ( $sortkey ne "title" ) {
            my $re = qr/$sortkey/;
            if ( $a->{tags} =~ m/.*${re}:(.*)(\,.*|$)/ ) {
                $meta1 = $1;
            } else {
                $meta1 = "zzzz";    # Not a very good way to make items end at the bottom...
            }

            if ( $b->{tags} =~ m/.*${re}:(.*)(\,.*|$)/ ) {
                $meta2 = $1;
            } else {
                $meta2 = "zzzz";
            }
        }

        if ($sortorder) {
            ncmp( lc($meta2), lc($meta1) );
        } else {
            ncmp( lc($meta1), lc($meta2) );
        }

    } @filtered;

    return @filtered;
}

1;
