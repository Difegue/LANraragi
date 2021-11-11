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
    my $sortorder_inv = $sortorder ? 0 : 1;

    my $redis = LANraragi::Model::Config->get_redis;
    my $logger = get_logger( "Search Engine", "lanraragi" );

    # Search filter results
    my $total    = $redis->hlen("LRR_FILEMAP");    # Total number of archives
    my @filtered = ();

    # Look in searchcache first
    my $cachekey     = encode_utf8("$category_id-$filter-$sortkey-$sortorder-$newonly-$untaggedonly");
    my $cachekey_inv = encode_utf8("$category_id-$filter-$sortkey-$sortorder_inv-$newonly-$untaggedonly");
    $logger->debug("Search request: $cachekey");

    if (   $redis->exists("LRR_SEARCHCACHE")
        && $redis->hexists( "LRR_SEARCHCACHE", $cachekey ) ) {
        $logger->debug("Using cache for this query.");

        # Thaw cache and use that as the filtered list
        my $frozendata = $redis->hget( "LRR_SEARCHCACHE", $cachekey );
        @filtered = @{ thaw $frozendata };

    } elsif ( $redis->exists("LRR_SEARCHCACHE")
        && $redis->hexists( "LRR_SEARCHCACHE", $cachekey_inv ) ) {
        $logger->debug("A cache key exists with the opposite sortorder.");

        # Thaw cache, invert the list to match the sortorder and use that as the filtered list
        my $frozendata = $redis->hget( "LRR_SEARCHCACHE", $cachekey_inv );
        @filtered = reverse @{ thaw $frozendata };

    } else {
        $logger->debug("No cache available, doing a full DB parse.");

        # Get all archives from redis - or just use IDs from the category if possible.
        my ( $filter_cat, @keys ) = get_source_data( $redis, $category_id );

        # Compute search filters
        my @tokens     = compute_search_filter($filter);
        my @tokens_cat = compute_search_filter($filter_cat);

        # Setup parallel processing
        my $numCpus = Sys::CpuAffinity::getNumCpus();
        my $pl      = Parallel::Loops->new($numCpus);
        my @shared  = ();
        $pl->share( \@shared );

        # If the untagged filter is enabled, call the untagged files API
        my %untagged = ();
        if ($untaggedonly) {

            # Map the array to a hash to easily check if it contains our id
            %untagged = map { $_ => 1 } LANraragi::Model::Archive::find_untagged_archives();
        }

        my @sections = split_workload_by_cpu( $numCpus, @keys );

        # Go through tags and apply search filter in subprocesses
        $pl->foreach(
            \@sections,
            sub {

                my @ids = @$_;

                # Get all the info for the given IDs as an atomic operation
                $redis = LANraragi::Model::Config->get_redis;
                $redis->multi;
                foreach my $id (@$_) {

                    # Check untagged filter first as it requires no DB hits
                    if ( !$untaggedonly || exists( $untagged{$id} ) ) {
                        $redis->hgetall($id);
                    } else {
                        $logger->debug("$id doesn't exist in the untagged_archives set, skipping.");
                        @ids = grep { $_ ne $id } @ids;    # Remove id from array to avoid messing up the mapping post-multi
                    }
                }
                my @data = $redis->exec;
                $redis->quit;

                for my $i ( 0 .. $#data ) {

                    # MULTI returns data in the same order the operations were sent,
                    # so we can get the ID from the original array this way.
                    my %hash;

                    if ( $data[$i] ) {
                        %hash = @{ $data[$i] };
                    } else {
                        next;
                    }
                    my $id = $ids[$i];

                    my ( $tags, $title, $file, $isnew ) = @hash{qw(tags title file isnew)};

                    $title = redis_decode($title);
                    $tags  = redis_decode($tags);

                    # Check new filter first
                    if ( $newonly && $isnew && $isnew ne "true" ) {
                        next;
                    }

                    # Check category search and base search filter
                    my $concat = $tags ? $title . "," . $tags : $title;
                    if (   $file
                        && matches_search_filter( $concat, @tokens_cat )
                        && matches_search_filter( $concat, @tokens ) ) {

                        # Push id to array
                        push @shared, { id => $id, title => $title, tags => $tags };
                    }
                }
            }
        );

        # Remove the extra reference/objects Parallel::Loops adds to the array,
        # as that'll cause memory leaks when we serialize/deserialize them with Storable.
        # This is done by simply copying the parallelized array to @filtered.
        @filtered = @shared;

        if ( $#filtered > 0 ) {

            if ( !$sortkey ) {
                $sortkey = "title";
            }

            # Sort by the required metadata, asc or desc
            @filtered = sort_results( $sortkey, $sortorder, @filtered );
        }

        # Cache this query in Redis
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

sub get_source_data {

    my ( $redis, $category_id ) = @_;
    my @keys       = ();
    my $filter_cat = "";

    if ( $category_id ne "" ) {
        my %category = LANraragi::Model::Category::get_category($category_id);

        if (%category) {

            # We're using a category! Update its lastused value.
            $redis->hset( $category_id, "last_used", time() );

            # If the category is dynamic, get its search predicate
            $filter_cat = $category{search};

            # If it's static however, we can use its ID list as the source data.
            if ( $filter_cat eq "" ) {
                @keys = @{ $category{archives} };
            } else {
                @keys = $redis->keys('????????????????????????????????????????');
            }
        }

    } else {
        @keys = $redis->keys('????????????????????????????????????????');
    }

    return ( $filter_cat, @keys );
}

# compute_search_filter($filter)
# Transform the search engine syntax into a list of tokens.
# A token object contains the tag, whether it must be an exact match, and whether it must be absent.
sub compute_search_filter {

    my $filter = shift;
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
        $tag = quotemeta($tag);

        # Replace placeholders(with an extra backslash in em thanks to quotemeta) with regex-friendly variants,
        # ? _ => .
        $tag =~ s/\\\?|\_/\./g;

        # * % => .*
        $tag =~ s/\\\*|\\\%/\.\*/g;

        push @tokens,
          { tag     => $tag,
            isneg   => $isneg,
            isexact => $isexact
          };
    }
    return @tokens;
}

# matches_search_filter($computed_filter, $tags)
# Search engine core.
sub matches_search_filter {

    my ( $tags, @tokens ) = @_;

    foreach my $token (@tokens) {

        my $tag     = $token->{tag};
        my $isneg   = $token->{isneg};
        my $isexact = $token->{isexact};

        # For each token, we check if the tag is present.
        my $tagpresent = 0;
        if ($isexact) {    # The tag must necessarily be complete if isexact = 1
             # Check for comma + potential space before and comma after the tag, or start/end of string to account for the first/last tag.
            $tagpresent = $tags =~ m/(.*\,\s*|^)$tag(\,.*|$)/i;
        } else {
            $tagpresent = $tags =~ m/.*$tag.*/i;
        }

        #present=true & isneg=true => false
        #present=false & isneg=false => false
        return 0 if ( $tagpresent == $isneg );

    }

    # All filters passed!
    return 1;
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
