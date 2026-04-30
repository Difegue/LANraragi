package LANraragi::Model::Search;

use feature qw(signatures);
no warnings 'experimental::signatures';

use strict;
use warnings;
use utf8;

use List::Util qw(min);
use Redis;
use Storable qw/ nfreeze thaw /;
use Sort::Naturally;
use Cpanel::JSON::XS qw(decode_json);
use Time::HiRes      qw(time);

use LANraragi::Utils::Generic  qw(intersect_arrays);
use LANraragi::Utils::Search   qw(normalize_clauses reduce_clauses compute_search_filter resolve_search_clause);
use LANraragi::Utils::Redis    qw(redis_decode redis_encode);
use LANraragi::Utils::Logging  qw(get_logger);

use LANraragi::Model::Archive;
use LANraragi::Model::Category;

# do_search (filter, category_id, page, key, order, newonly, untaggedonly, grouptanks, hidecompleted)
# Performs a search on the database.
sub do_search ( $filter, $category_id, $start, $sortkey, $sortorder, $newonly, $untaggedonly, $grouptanks, $hidecompleted ) {

    my $redis    = LANraragi::Model::Config->get_redis_search;
    my $redis_db = LANraragi::Model::Config->get_redis;
    my $logger   = get_logger( "Search Engine", "lanraragi" );

    unless ( $redis->exists("LAST_JOB_TIME") ) {
        $logger->error("Search engine is not initialized yet. Please wait a few seconds.");

        # TODO - This is the only case where the API returns -1, but it's not really handled well clientside at the moment.
        $redis->quit();
        $redis_db->quit();
        return ( -1, -1, () );
    }

    my $tankcount = $redis->scard("LRR_TANKGROUPED") + 0;

    # Get tank ids count
    my $tankidscount = scalar( $redis_db->keys('TANK_??????????') );

    # Total number of archives (as int)
    my $total = $grouptanks ? $tankcount : $redis->zcard("LRR_TITLES") - $tankidscount;

    # Look in searchcache first
    my $sortorder_inv = $sortorder ? 0 : 1;
    my $cachekey      = redis_encode("$category_id-$filter-$sortkey-$sortorder-$newonly-$untaggedonly-$grouptanks-$hidecompleted");
    my $cachekey_inv =
      redis_encode("$category_id-$filter-$sortkey-$sortorder_inv-$newonly-$untaggedonly-$grouptanks-$hidecompleted");
    my ( $cachehit, @filtered ) = check_cache( $cachekey, $cachekey_inv );

    # Don't use cache for history searches since setting lastreadtime doesn't (and shouldn't) cachebust
    unless ( $cachehit && $sortkey ne "lastread" ) {
        $logger->debug("No cache available (or history-sorted search), doing a full DB parse.");

        # Resolve candidate set based on grouptanks mode
        my @candidates;
        if ($grouptanks) {
            @candidates = $redis->smembers("LRR_TANKGROUPED");
        } else {
            @candidates = $redis_db->keys('????????????????????????????????????????');
        }

        # Convert single category_id to structured format for resolve_search_clause
        my @categories = ();
        if ( $category_id && $category_id ne "" ) {
            push @categories, { id => $category_id, mode => "include" };
        }

        my @tokens = compute_search_filter( $filter // "" );
        my $clause = resolve_search_clause( \@tokens, \@categories, \@candidates, $newonly, $untaggedonly, $hidecompleted );

        my $keyed_count;
        ( $keyed_count, @filtered ) = do_composite_search_inner( $redis, $redis_db, [$clause], $sortkey, $sortorder );

        # Cache this query in the search database, prepending the keyed count for partition-aware cache inversion
        eval { $redis->hset( "LRR_SEARCHCACHE", $cachekey, nfreeze [ $keyed_count, @filtered ] ); };
    }

    $redis->quit();
    $redis_db->quit();

    # If start is negative, return all possible data.
    if ( $start == -1 ) {
        return ( $total, $#filtered + 1, @filtered );
    }

    # Only get the first X keys
    my $keysperpage = LANraragi::Model::Config->get_pagesize;

    # Return total keys and the filtered ones
    my $end = min( $start + $keysperpage - 1, $#filtered );
    return ( $total, $#filtered + 1, @filtered[ $start .. $end ] );
}

# do_composite_search (clause_descriptors, start, sortkey, sortorder, grouptanks)
# Performs a composite search: each clause descriptor is resolved into an AND conjunction,
# then multiple clauses are OR-unioned. Superset of do_search.
#
# Sort and pagination are global, applied after the OR union across all clauses.
# No caching for composite queries.
#
# Parameters:
#   $clause_descriptors - arrayref of descriptor hashrefs, each containing:
#                           filter       => search filter string
#                           categories   => arrayref of { id, mode } hashrefs
#                           newonly      => 1 = only, -1 = exclude, 0 = off
#                           untaggedonly => 1 = only, -1 = exclude, 0 = off
#   $start      - pagination offset (-1 for all results)
#   $sortkey    - sort field: "title", "lastread", or a tag namespace
#   $sortorder  - 0 = ascending, 1 = descending
#   $grouptanks - 0|1, determines candidate pool
#
# Returns: ($total, $filtered_count, @page_of_ids)
sub do_composite_search ( $clause_descriptors, $start, $sortkey, $sortorder, $grouptanks ) {

    my $redis    = LANraragi::Model::Config->get_redis_search;
    my $redis_db = LANraragi::Model::Config->get_redis;
    my $logger   = get_logger( "Search Engine", "lanraragi" );

    unless ( $redis->exists("LAST_JOB_TIME") ) {
        $logger->error("Search engine is not initialized yet. Please wait a few seconds.");
        $redis->quit();
        $redis_db->quit();
        return ( -1, -1, () );
    }

    # Normalize once, reduce via DNF absorption, then resolve.
    my $normed = normalize_clauses($clause_descriptors);
    $normed = reduce_clauses($normed);

    my $tankcount    = $redis->scard("LRR_TANKGROUPED") + 0;
    my $tankidscount = scalar( $redis_db->keys('TANK_??????????') );
    my $total        = $grouptanks ? $tankcount : $redis->zcard("LRR_TITLES") - $tankidscount;

    # Resolve base candidates from grouptanks mode
    my @base_candidates;
    if ($grouptanks) {
        @base_candidates = $redis->smembers("LRR_TANKGROUPED");
    } else {
        @base_candidates = $redis_db->keys('????????????????????????????????????????');
    }

    # Resolve each normalized clause
    my @clauses;
    foreach my $n (@$normed) {
        push @clauses, resolve_search_clause(
            $n->{raw_tokens},
            $n->{raw_categories},
            \@base_candidates,
            $n->{newonly},
            $n->{untaggedonly},
            $n->{hidecompleted},
        );
    }

    my ( $keyed_count, @filtered ) = do_composite_search_inner( $redis, $redis_db, \@clauses, $sortkey, $sortorder );

    $redis->quit();
    $redis_db->quit();

    # If start is negative, return all possible data.
    if ( $start == -1 ) {
        return ( $total, $#filtered + 1, @filtered );
    }

    # Only get the first X keys
    my $keysperpage = LANraragi::Model::Config->get_pagesize;

    my $end = min( $start + $keysperpage - 1, $#filtered );
    return ( $total, $#filtered + 1, @filtered[ $start .. $end ] );
}

# do_composite_search_inner (redis, redis_db, clauses, sortkey, sortorder)
# Core composite search logic. Runs search_core per clause, unions results, sorts globally.
# Accepts Redis connections from the caller.
#
# For a single clause, delegates directly to search_core (no overhead).
# For multiple clauses, runs search_core per clause, deduplicates the union, and re-sorts globally.
#
# Parameters:
#   $redis      - Redis connection for search database
#   $redis_db   - Redis connection for main database
#   $clauses    - arrayref of clause hashrefs (see do_composite_search)
#   $sortkey    - sort field
#   $sortorder  - 0 = ascending, 1 = descending
#
# Returns: ($keyed_count, @sorted_ids)
sub do_composite_search_inner ( $redis, $redis_db, $clauses, $sortkey, $sortorder ) {

    # Single clause: delegate directly to search_core
    if ( scalar @$clauses == 1 ) {
        my $clause = $clauses->[0];
        return search_core(
            $redis, $redis_db,
            $clause->{candidate_ids}, $clause->{tokens},
            $sortkey, $sortorder,
            $clause->{newonly}, $clause->{untaggedonly},
            $clause->{hidecompleted}
        );
    }

    # Multi-clause: run search_core per clause, union, re-sort globally
    my %seen;
    my @union;

    foreach my $clause (@$clauses) {
        my ( $kc, @results ) = search_core(
            $redis, $redis_db,
            $clause->{candidate_ids}, $clause->{tokens},
            undef, $sortorder,
            $clause->{newonly}, $clause->{untaggedonly},
            $clause->{hidecompleted}
        );

        # Deduplicate: preserve first occurrence across clauses
        foreach my $id (@results) {
            unless ( $seen{$id}++ ) {
                push @union, $id;
            }
        }
    }

    # Re-sort the union globally
    if ( scalar @union > 0 ) {
        if ( !$sortkey ) {
            $sortkey = "title";
        }

        if ( $sortkey eq "title" ) {
            my @ordered = nsort( $redis->zrangebylex( "LRR_TITLES", "-", "+" ) );
            if ($sortorder) {
                @ordered = reverse(@ordered);
            }
            @ordered = map { substr( $_, index( $_, "\x00" ) + 1 ) } @ordered;
            @union = intersect_arrays( \@union, \@ordered, 0 );
            return ( -1, @union );
        } else {
            return sort_results( $sortkey, $sortorder, @union );
        }
    }

    return ( -1, @union );
}

sub check_cache ( $cachekey, $cachekey_inv ) {

    my $redis  = LANraragi::Model::Config->get_redis_search;
    my $logger = get_logger( "Search Cache", "lanraragi" );

    my @filtered = ();
    my $cachehit = 0;
    $logger->debug("Search request: $cachekey");

    if ( $redis->exists("LRR_SEARCHCACHE") && $redis->hexists( "LRR_SEARCHCACHE", $cachekey ) ) {
        $logger->debug("Using cache for this query.");
        $cachehit = 1;

        my $frozendata = $redis->hget( "LRR_SEARCHCACHE", $cachekey );
        my @cached     = @{ thaw $frozendata };
        shift @cached;    # Discard the keyed count, since they're at the bottom of the list naturally
        @filtered = @cached;

    } elsif ( $redis->exists("LRR_SEARCHCACHE") && $redis->hexists( "LRR_SEARCHCACHE", $cachekey_inv ) ) {
        $logger->debug("A cache key exists with the opposite sortorder.");
        $cachehit = 1;

        my $frozendata  = $redis->hget( "LRR_SEARCHCACHE", $cachekey_inv );
        my @cached      = @{ thaw $frozendata };
        my $keyed_count = shift @cached;

        # Reverse only the keyed prefix; unkeyed archives stay at the back
        if ( $keyed_count > 0 && $keyed_count < scalar @cached ) {
            @filtered = ( reverse( @cached[ 0 .. $keyed_count - 1 ] ), @cached[ $keyed_count .. $#cached ] );
        } else {
            @filtered = reverse @cached;
        }
    }

    $redis->quit();
    return ( $cachehit, @filtered );
}

# search_core (redis, redis_db, candidate_ids, tokens, sortkey, sortorder, newonly, untaggedonly, hidecompleted)
# Core search function operating on a pre-resolved candidate set.
# No category or grouptanks awareness — the caller resolves those into candidate_ids and tokens.
#
# Parameters:
#   $redis         - Redis connection for search database (indexes, titles, cache)
#   $redis_db      - Redis connection for main database (archive data)
#   $candidate_ids - arrayref of IDs to search within (archive and/or tank IDs)
#   $tokens        - arrayref of token hashrefs from compute_search_filter, each { tag, isneg, isexact }
#   $sortkey       - sort field: "title", "lastread", or a tag namespace; undef to skip sorting
#   $sortorder     - 0 = ascending, 1 = descending
#   $newonly        - tri-state: 1 = only new, -1 = exclude new, 0 = off
#   $untaggedonly   - tri-state: 1 = only untagged, -1 = exclude untagged, 0 = off
#   $hidecompleted - boolean: 1 = hide archives with progress/pagecount > 0.85
#
# Returns: ($keyed_count, @sorted_ids)
#   $keyed_count  - number of IDs possessing the sort key (-1 for title sort)
#   @sorted_ids   - filtered and sorted ID list
sub search_core ( $redis, $redis_db, $candidate_ids, $tokens, $sortkey, $sortorder, $newonly, $untaggedonly, $hidecompleted ) {

    my $logger = get_logger( "Search Core", "lanraragi" );

    my @filtered = @$candidate_ids;

    # Empty candidate set: no results possible
    if ( scalar @filtered == 0 ) {
        return ( -1, () );
    }

    # Untagged filter: 1 = only untagged, -1 = only tagged
    if ($untaggedonly) {
        my @untagged = $redis->smembers("LRR_UNTAGGED");
        my $isneg = ( $untaggedonly == -1 ) ? 1 : 0;
        @filtered = intersect_arrays( \@untagged, \@filtered, $isneg );
    }

    # New filter: 1 = only new, -1 = only non-new
    if ( $newonly && scalar @filtered > 0 ) {
        my @new = $redis->smembers("LRR_NEW");
        my $isneg = ( $newonly == -1 ) ? 1 : 0;
        @filtered = intersect_arrays( \@new, \@filtered, $isneg );
    }

    # Hide completed archives (Consider an archive read if progress is past 85 % of total)
    if ($hidecompleted) {

        # Separate tanks from regular archives (It's likely we'll need a progress search index once tanks are live)
        my @tanks     = grep { /^TANK/ } @filtered;
        my @non_tanks = grep { !/^TANK/ } @filtered;

        if ( scalar @non_tanks > 0 ) {

            # Use a Lua script to check completion status in bulk, avoiding per-ID round-trips
            my $script = <<'LUA';
            local result = {}
            for i = 1, #ARGV do
                local id = ARGV[i]
                local progress  = tonumber(redis.call('HGET', id, 'progress')  or "0") or 0
                local pagecount = tonumber(redis.call('HGET', id, 'pagecount') or "0") or 0
                if not (pagecount > 0 and (progress / pagecount) > 0.85) then
                    result[#result + 1] = id
                end
            end
            if #result == 0 then return "[]" end
            return cjson.encode(result)
LUA

            my $sha;
            eval { $sha = $redis_db->script_load($script); };

            if ($@) {
                $logger->debug("Lua script not available for hidecompleted filter, falling back to per-ID queries.");
                @non_tanks = grep {
                    my $progress  = $redis_db->hget( $_, "progress" )  || 0;
                    my $pagecount = $redis_db->hget( $_, "pagecount" ) || 0;
                    !( $pagecount > 0 && ( $progress / $pagecount > 0.85 ) );
                } @non_tanks;
            } else {
                my $result = $redis_db->evalsha( $sha, 0, @non_tanks );
                my $data   = eval { decode_json($result) };
                if ($@) {
                    $logger->error("Failed to decode hidecompleted Lua result: $@");
                    @non_tanks = grep {
                        my $progress  = $redis_db->hget( $_, "progress" )  || 0;
                        my $pagecount = $redis_db->hget( $_, "pagecount" ) || 0;
                        !( $pagecount > 0 && ( $progress / $pagecount > 0.85 ) );
                    } @non_tanks;
                } else {
                    @non_tanks = @$data;
                }
            }
        }

        @filtered = ( @tanks, @non_tanks );
    }

    # Iterate through each token and intersect the results with the previous ones.
    unless ( scalar @$tokens == 0 || scalar @filtered == 0 ) {
        foreach my $token (@$tokens) {

            my $tag     = $token->{tag};
            my $isneg   = $token->{isneg};
            my $isexact = $token->{isexact};

            $logger->debug("Searching for $tag, isneg=$isneg, isexact=$isexact");

            # Encode tag as we'll use it in redis operations
            $tag = redis_encode($tag);

            my @ids = ();

           # Specific case for pagecount searches
           # You can search for galleries with a specific number of pages with pages:20, or with a page range: pages:>20 pages:<=30.
           # Or you can search for galleries with a specific number of pages read with read:20, or any pages read: read:>0
            if ( $tag =~ /^(read|pages):(>|<|>=|<=)?(\d+)$/ ) {
                my $col       = $1;
                my $operator  = $2;
                my $pagecount = $3;

                $logger->debug("Searching for IDs with $operator $pagecount $col");

                # If no operator is specified, we assume it's an exact match
                $operator = "=" if !$operator;

                # Change the column based off the tag searched.
                # "pages" -> "pagecount"
                # "read" -> "progress"
                $col = $col eq "pages" ? "pagecount" : "progress";

                # Go through all IDs in @filtered and check if they have the right pagecount
                # This could be sped up with an index, but it's probably not worth it.
                foreach my $id (@filtered) {

                    # Tanks don't have a set pagecount property, so they're not included here for now.
                    # TODO TANKS: Maybe an index would be good actually..
                    if ( $id =~ /^TANK/ ) {
                        next;
                    }

                    # Default to 0 if null.
                    my $count = $redis_db->hget( $id, $col ) || 0;

                    if (   ( $operator eq "=" && $count == $pagecount )
                        || ( $operator eq ">"  && $count > $pagecount )
                        || ( $operator eq ">=" && $count >= $pagecount )
                        || ( $operator eq "<"  && $count < $pagecount )
                        || ( $operator eq "<=" && $count <= $pagecount ) ) {
                        push @ids, $id;
                    }
                }
            }

            # For exact tag searches, just check if an index for it exists
            if ( $isexact && $redis->exists("INDEX_$tag") ) {

                # Get the list of IDs for this tag
                @ids = $redis->smembers("INDEX_$tag");
                $logger->debug( "Found tag index for $tag, containing " . scalar @ids . " IDs" );
            } else {

                # Get index keys that match this tag.
                # If the tag has a namespace, We don't add a wildcard at the start of the tag to keep it intact.
                # Otherwise, we add a wildcard at the start to match all namespaces.
                my $indexkey = $tag =~ /:/ ? "INDEX_$tag*" : "INDEX_*$tag*";
                my @keys     = $redis->keys($indexkey);

                # Get the list of IDs for each key
                foreach my $key (@keys) {
                    my @keyids = $redis->smembers($key);
                    $logger->trace( "Found index $key for $tag, containing " . scalar @ids . " IDs" );
                    push @ids, @keyids;
                }
            }

            # Append fuzzy title search
            my $namesearch = $isexact ? "$tag\x00*" : "*$tag*";
            my $scan       = -1;
            while ( $scan != 0 ) {

                # First iteration
                if ( $scan == -1 ) { $scan = 0; }
                $logger->trace("Scanning for $namesearch, cursor=$scan");

                my @result = $redis->zscan( "LRR_TITLES", $scan, "MATCH", $namesearch, "COUNT", 100 );
                $scan = $result[0];

                foreach my $title ( @{ $result[1] } ) {

                    if ( $title eq "0" ) { next; }    # Skip scores
                    $logger->trace("Found title match: $title");

                    # Strip everything before \x00 to get the ID out of the key
                    my $id = substr( $title, index( $title, "\x00" ) + 1 );
                    push @ids, $id;
                }
            }

            if ( scalar @ids == 0 && !$isneg ) {

                # No more results, we can end search here
                $logger->trace("No results for this token, halting search.");
                @filtered = ();
                last;
            } else {
                $logger->trace( "Found " . scalar @ids . " results for this token." );

                # Intersect the new list with the previous ones
                @filtered = intersect_arrays( \@ids, \@filtered, $isneg );

                if ( scalar @filtered == 0 ) {
                    $logger->trace("No more results after intersection, halting search.");
                    last;
                }
            }
        }
    }

    if ( scalar @filtered > 0 ) {
        $logger->debug( "Found " . scalar @filtered . " results after filtering." );

        # undef sortkey: skip sorting (used by multi-clause path which re-sorts globally)
        unless ( defined $sortkey ) {
            return ( -1, @filtered );
        }

        if ( !$sortkey ) {
            $sortkey = "title";
        }

        if ( $sortkey eq "title" ) {
            my @ordered = ();

            # For title sorting, we can just use the LRR_TITLES set, which is sorted lexicographically (but not naturally).
            @ordered = nsort( $redis->zrangebylex( "LRR_TITLES", "-", "+" ) );
            if ($sortorder) {
                @ordered = reverse(@ordered);
            }

            # Remove the titles from the keys, which are stored as "title\x00id"
            @ordered = map { substr( $_, index( $_, "\x00" ) + 1 ) } @ordered;

            $logger->trace( "Example element from ordered list: " . $ordered[0] );

            # Just intersect the ordered list with the filtered one to get the final result
            @filtered = intersect_arrays( \@filtered, \@ordered, 0 );
        } else {

            # For other sorting, we need to get the metadata for each archive and sort it manually.
            my $keyed_count;
            ( $keyed_count, @filtered ) = sort_results( $sortkey, $sortorder, @filtered );

            return ( $keyed_count, @filtered );
        }
    }

    # Title sort and unfiltered results: all archives are keyed
    return ( -1, @filtered );
}

sub sort_results ( $sortkey, $sortorder, @filtered ) {

    my $start_time = time();
    my $redis      = LANraragi::Model::Config->get_redis;
    my $logger     = get_logger( "Search Sort", "lanraragi" );
    my %tmpfilter  = ();
    my @sorted     = ();

    # Should there be no IDs requiring sorting, return an empty array directly
    if ( scalar @filtered == 0 ) {
        $redis->quit();
        return ( 0, @sorted );
    }

    # Employ Lua scripting to fetch data in bulk, thereby minimizing network request frequency
    if ( $sortkey eq "lastread" ) {

        # Prepare a Lua script to retrieve the lastreadtime for all IDs
        my $script = <<'LUA';
        local result = {}
        for i=1,#ARGV do
            local id = ARGV[i]
            local value = redis.call('HGET', id, 'lastreadtime')
            result[i] = {id, value or "0"}
        end
        return cjson.encode(result)
LUA

        # Execute the Lua script
        my $sha;
        eval {
            $sha = $redis->script_load($script);
            my $total_time = time() - $start_time;
            $logger->debug("[PERF] lastreadtime Lua script completed in ${total_time}s");
        };
        if ($@) {
            $logger->error("Failed to load Lua script: $@");

            # Fallback to running individual hget operations for each ID
            %tmpfilter = map { $_ => $redis->hget( $_, "lastreadtime" ) } @filtered;
        } else {
            my $result = $redis->evalsha( $sha, 0, @filtered );
            my $data   = eval { decode_json($result) };
            if ($@) {
                $logger->error("Failed to decode JSON from Lua script: $@");

                # Revert to the original methodology
                %tmpfilter = map { $_ => $redis->hget( $_, "lastreadtime" ) } @filtered;
            } else {

                # Convert the results into a hash table
                foreach my $item (@$data) {
                    $tmpfilter{ $item->[0] } = $item->[1];
                }
            }
        }

        # Sorting remains done in Perl -- Invert sort order for lastreadtime, biggest timestamps come first
        @sorted = map { $_->[0] }                    # Map back to only having the ID
          sort { $b->[1] <=> $a->[1] }               # Sort by the timestamp
          grep { defined $_->[1] && $_->[1] > 0 }    # Remove nil timestamps
          map  { [ $_, $tmpfilter{$_} ] }            # Map to an array containing the ID and the timestamp
          @filtered;                                 # List of IDs
    } else {

        # Prepare a Lua script to retrieve all ID-associated tags
        my $script = <<'LUA';
        local result = {}
        for i=1,#ARGV do
            local id = ARGV[i]
            local tags = redis.call('HGET', id, 'tags') or ""
            result[i] = {id, tags}
        end
        return cjson.encode(result)
LUA

        # Execute the Lua script
        my $sha;
        eval {
            $sha = $redis->script_load($script);
            my $total_time = time() - $start_time;
            $logger->debug("[PERF] Tag retrieval Lua script completed in ${total_time}s");
        };
        if ($@) {
            $logger->error("Failed to load Lua script: $@");

            # Revert to the original methodology
            my $re = qr/$sortkey/;
            %tmpfilter = map { $_ => ( $redis->hget( $_, "tags" ) =~ m/.*${re}:(.*?)(\,.*|$)/ ) ? $1 : "zzzz" } @filtered;
        } else {
            my $result = $redis->evalsha( $sha, 0, @filtered );
            my $data   = eval { decode_json($result) };
            if ($@) {
                $logger->error("Failed to decode JSON from Lua script: $@");

                # Revert to the original methodology
                my $re = qr/$sortkey/;
                %tmpfilter = map { $_ => ( $redis->hget( $_, "tags" ) =~ m/.*${re}:(.*?)(\,.*|$)/ ) ? $1 : "zzzz" } @filtered;
            } else {
                my $re = qr/$sortkey/;
                foreach my $item (@$data) {
                    my $id   = $item->[0];
                    my $tags = $item->[1];

                    # Find and use the first tag that matches the sortkey/namespace.
                    # (If no tag, defaults to "zzzz")
                    $tmpfilter{$id} = ( $tags =~ m/.*${re}:(.*?)(\,.*|$)/ ) ? $1 : "zzzz";
                }
            }
        }

        # Partition: archives with the sort namespace vs those without it
        my @keyed_ids   = grep { $tmpfilter{$_} ne "zzzz" } @filtered;
        my @unkeyed_ids = grep { $tmpfilter{$_} eq "zzzz" } @filtered;

        # Read comments from the bottom up for a better understanding of this sort algorithm.
        @sorted = map { $_->[0] }                  # Map back to only having the ID
          sort { ncmp( $a->[1], $b->[1] ) }        # Sort by the tag
          map  { [ $_, lc( $tmpfilter{$_} ) ] }    # Map to an array containing the ID and the lowercased tag
          @keyed_ids;                              # List of keyed archive IDs

        if ($sortorder) {
            @sorted = reverse @sorted;
        }

        # Archives missing the sort namespace always go to the back
        push @sorted, @unkeyed_ids;

        my $total_time = time() - $start_time;
        $logger->debug("[PERF] sort_results completed in ${total_time}s");
        $redis->quit();
        return ( scalar @keyed_ids, @sorted );
    }

    if ( $sortkey eq "lastread" && $sortorder ) {
        @sorted = reverse @sorted;
    }
    my $total_time = time() - $start_time;
    $logger->debug("[PERF] sort_results completed in ${total_time}s");

    # lastread: all returned archives are keyed (nil timestamps filtered out)
    $redis->quit();
    return ( -1, @sorted );
}

1;
