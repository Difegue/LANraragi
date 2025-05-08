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

use LANraragi::Utils::Generic  qw(split_workload_by_cpu intersect_arrays);
use LANraragi::Utils::String   qw(trim);
use LANraragi::Utils::Database qw(redis_decode redis_encode);
use LANraragi::Utils::Logging  qw(get_logger);

use LANraragi::Model::Archive;
use LANraragi::Model::Category;

# do_search (filter, category_id, page, key, order, newonly, untaggedonly)
# Performs a search on the database.
sub do_search ( $filter, $category_id, $start, $sortkey, $sortorder, $newonly, $untaggedonly, $grouptanks ) {

    my $redis  = LANraragi::Model::Config->get_redis_search;
    my $logger = get_logger( "Search Engine", "lanraragi" );

    unless ( $redis->exists("LAST_JOB_TIME") && ( $redis->exists("LRR_TANKGROUPED") || !$grouptanks ) ) {
        $logger->error("Search engine is not initialized yet. Please wait a few seconds.");

        # TODO - This is the only case where the API returns -1, but it's not really handled well clientside at the moment.
        return ( -1, -1, () );
    }

    my $tankcount = $redis->scard("LRR_TANKGROUPED") + 0;

    # Get tank ids count
    my $tankidscount = scalar( LANraragi::Model::Config->get_redis->keys('TANK_??????????') );

    # Total number of archives (as int)
    my $total = $grouptanks ? $tankcount : $redis->zcard("LRR_TITLES") - $tankidscount;

    # Look in searchcache first
    my $sortorder_inv = $sortorder ? 0 : 1;
    my $cachekey      = redis_encode("$category_id-$filter-$sortkey-$sortorder-$newonly-$untaggedonly-$grouptanks");
    my $cachekey_inv  = redis_encode("$category_id-$filter-$sortkey-$sortorder_inv-$newonly-$untaggedonly-$grouptanks");
    my ( $cachehit, @filtered ) = check_cache( $cachekey, $cachekey_inv );

    # Don't use cache for history searches since setting lastreadtime doesn't (and shouldn't) cachebust
    unless ( $cachehit && $sortkey ne "lastread" ) {
        $logger->debug("No cache available (or history-sorted search), doing a full DB parse.");
        @filtered = search_uncached( $category_id, $filter, $sortkey, $sortorder, $newonly, $untaggedonly, $grouptanks );

        # Cache this query in the search database
        eval { $redis->hset( "LRR_SEARCHCACHE", $cachekey, nfreeze \@filtered ); };
    }
    $redis->quit();

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

sub check_cache ( $cachekey, $cachekey_inv ) {

    my $redis  = LANraragi::Model::Config->get_redis_search;
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

sub search_uncached( $category_id, $filter, $sortkey, $sortorder, $newonly, $untaggedonly, $grouptanks ) {

    my $category_id_dnf     = defined $category_id ? [[$category_id]] : [[undef]];
    my $filter_dnf          = defined $filter ? [$filter] : [undef];

    return search_uncached_composite( $category_id_dnf, $filter_dnf, $sortkey, $sortorder, $newonly, $untaggedonly, $grouptanks );
    # Keeping the old singleton implementation for backwards compatibility if needed
    # return search_uncached_singleton( $category_id_dnf, $filter_dnf, $sortkey, $sortorder, $newonly, $untaggedonly, $grouptanks );

}

# Grab all our IDs, then filter them down according to the following filters and tokens' ID groups.
sub search_uncached_singleton ( $category_id_dnf, $filter_dnf, $sortkey, $sortorder, $newonly, $untaggedonly, $grouptanks ) {

    my $redis    = LANraragi::Model::Config->get_redis_search;
    my $redis_db = LANraragi::Model::Config->get_redis;
    my $logger   = get_logger( "Search Core", "lanraragi" );

    # Compute search filters
    # Take only the first item from each array for backwards compatibility
    # Future implementation will handle the full OR/AND logic
    my $category_id = $category_id_dnf->[0][0];
    my $filter = $filter_dnf->[0];
    my @tokens = compute_search_filter($filter);

    # Prepare array: For each token, we'll have a list of matching archive IDs.
    # We intersect those lists as we proceed to get the final result.
    my @filtered;
    if ($grouptanks) {

        # Start with our tank IDs, and all other archive IDs that aren't in tanks
        @filtered = $redis->smembers("LRR_TANKGROUPED");
    } else {

        # Start with all our archive IDs. Tank IDs won't be present in this search.
        @filtered = $redis_db->keys('????????????????????????????????????????');
    }

    # If we're using a category, we'll need to get its source data first.
    my %category = LANraragi::Model::Category::get_category($category_id);

    if (%category) {

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
        my @untagged = $redis->smembers("LRR_UNTAGGED");
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
            # Just use the old sort algorithm at this point.
            @filtered = sort_results( $sortkey, $sortorder, @filtered );

            # We could theoretically use the tag indexes for this by scanning them all
            # to find the filtered IDs and then ordering on those namespace/ID pairs, but that's a lot of work for little gain.
        }
    }

    $redis->quit();
    $redis_db->quit();
    return @filtered;
}

# Perform a search using OR/AND logic via disjunctive normal forms
# Logic is generalization of search_uncached_singleton, except we will reduce
# the category DNF and filter DNF to a tokens DNF, then apply tokens DNF to list of filtered IDs.
sub search_uncached_composite ( $category_id_dnf, $filter_dnf, $sortkey, $sortorder, $newonly, $untaggedonly, $grouptanks ) {
    my $redis    = LANraragi::Model::Config->get_redis_search;
    my $redis_db = LANraragi::Model::Config->get_redis;
    my $logger   = get_logger( "Search Core", "lanraragi" );

    # Start with all archive IDs
    my @filtered;
    if ($grouptanks) {
        # Start with our tank IDs, and all other archive IDs that aren't in tanks
        @filtered = $redis->smembers("LRR_TANKGROUPED");
    } else {
        # Start with all our archive IDs. Tank IDs won't be present in this search.
        @filtered = $redis_db->keys('????????????????????????????????????????');
    }

    # Apply the category DNF filter first
    my @category_filtered = process_category_dnf($category_id_dnf, \@filtered, $redis, $redis_db, $logger);

    # Early return if no results after category filtering
    if (scalar @category_filtered == 0) {
        $logger->debug("No results after category filtering, halting search.");
        $redis->quit();
        $redis_db->quit();
        return ();
    }

    # Apply the untagged and new filters
    @category_filtered = apply_common_filters(\@category_filtered, $newonly, $untaggedonly, $redis);

    # Early return if no results after common filtering
    if (scalar @category_filtered == 0) {
        $logger->debug("No results after applying common filters, halting search.");
        $redis->quit();
        $redis_db->quit();
        return ();
    }

    # Process the filter DNF
    my @final_filtered = process_filter_dnf($filter_dnf, \@category_filtered, $redis, $redis_db, $logger);

    # Apply sorting if we have results
    if (scalar @final_filtered > 0) {
        $logger->debug("Found " . scalar @final_filtered . " results after filtering.");

        if (!$sortkey) {
            $sortkey = "title";
        }

        @final_filtered = apply_sorting(\@final_filtered, $sortkey, $sortorder, $redis, $redis_db);
    }

    $redis->quit();
    $redis_db->quit();
    return @final_filtered;
}

# Process the category DNF (list of lists of category IDs)
# Each outer list element is combined with OR
# Each inner list element is combined with AND
sub process_category_dnf {
    my ($category_id_dnf, $filtered_ref, $redis, $redis_db, $logger) = @_;
    my @result = ();

    $logger->debug("Processing category DNF with " . scalar @$category_id_dnf . " OR terms");

    # Process each OR term (outer list)
    for my $and_categories (@$category_id_dnf) {
        # Skip empty category lists
        next if !defined $and_categories || scalar @$and_categories == 0;

        $logger->debug("Processing AND term with " . scalar @$and_categories . " categories");

        # Start with the full list for each OR term
        my @current_term_result = @$filtered_ref;

        # Process each category in this AND term
        for my $category_id (@$and_categories) {
            # Skip undefined categories
            next if !defined $category_id;

            # Get the category data
            my %category = LANraragi::Model::Category::get_category($category_id);

            if (%category) {
                if ($category{search} ne "") {
                    # For dynamic categories, apply their search tokens to the current result
                    my @cat_tokens = compute_search_filter($category{search});
                    @current_term_result = apply_tokens_to_ids(\@cat_tokens, \@current_term_result, $redis, $redis_db, $logger);

                    # Early exit if this AND term has no results
                    if (scalar @current_term_result == 0) {
                        $logger->debug("No results for this AND term, skipping to next OR term");
                        last;
                    }
                } else {
                    # For static categories, intersect with the category's archive list
                    @current_term_result = intersect_arrays($category{archives}, \@current_term_result, 0);
                    
                    # Early exit if this AND term has no results
                    if (scalar @current_term_result == 0) {
                        $logger->debug("No results for this AND term after intersecting with static category, skipping to next OR term");
                        last;
                    }
                }
            }
        }

        # Add this OR term's results to the final result
        push @result, @current_term_result;
    }

    # Remove duplicates
    my %seen;
    @result = grep { !$seen{$_}++ } @result;

    $logger->debug("Category DNF processing yielded " . scalar @result . " results");
    return @result;
}

# Process the filter DNF (list of filters)
# Each filter is combined with OR
sub process_filter_dnf {
    my ($filter_dnf, $filtered_ref, $redis, $redis_db, $logger) = @_;

    # If there are no filters, return the input as is
    return @$filtered_ref if !defined $filter_dnf || scalar @$filter_dnf == 0;

    $logger->debug("Processing filter DNF with " . scalar @$filter_dnf . " filters");

    my @result = ();

    # Process each filter (OR term)
    for my $filter (@$filter_dnf) {
        # Skip undefined filters
        next if !defined $filter;

        # Convert filter to tokens
        my @tokens = compute_search_filter($filter);

        # Apply tokens to the current filtered IDs
        my @filter_result = apply_tokens_to_ids(\@tokens, $filtered_ref, $redis, $redis_db, $logger);

        # Add results from this filter to overall results
        push @result, @filter_result;
    }

    # Remove duplicates
    my %seen;
    @result = grep { !$seen{$_}++ } @result;

    $logger->debug("Filter DNF processing yielded " . scalar @result . " results");
    return @result;
}

# Apply a list of tokens to a list of IDs
# All tokens are combined with AND
sub apply_tokens_to_ids {
    my ($tokens, $ids_ref, $redis, $redis_db, $logger) = @_;

    # Return the original IDs if there are no tokens
    return @$ids_ref if scalar @$tokens == 0;

    # Start with the full list
    my @filtered = @$ids_ref;

    # Return empty if nothing to filter
    return () if scalar @filtered == 0;

    # Iterate through each token and intersect the results with the previous ones
    foreach my $token (@$tokens) {
        my $tag     = $token->{tag};
        my $isneg   = $token->{isneg};
        my $isexact = $token->{isexact};

        $logger->debug("Searching for $tag, isneg=$isneg, isexact=$isexact");

        # Encode tag as we'll use it in redis operations
        $tag = redis_encode($tag);

        my @ids = ();

        # Specific case for pagecount searches
        if ($tag =~ /^(read|pages):(>|<|>=|<=)?(\d+)$/) {
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
            foreach my $id (@filtered) {
                # Tanks don't have a set pagecount property
                if ($id =~ /^TANK/) {
                    next;
                }

                # Default to 0 if null.
                my $count = $redis_db->hget($id, $col) || 0;

                if (($operator eq "=" && $count == $pagecount)
                    || ($operator eq ">"  && $count > $pagecount)
                    || ($operator eq ">=" && $count >= $pagecount)
                    || ($operator eq "<"  && $count < $pagecount)
                    || ($operator eq "<=" && $count <= $pagecount)) {
                    push @ids, $id;
                }
            }
        } 
        # For exact tag searches, just check if an index for it exists
        elsif ($isexact && $redis->exists("INDEX_$tag")) {
            # Get the list of IDs for this tag
            @ids = $redis->smembers("INDEX_$tag");
            $logger->debug("Found tag index for $tag, containing " . scalar @ids . " IDs");
        } 
        else {
            # Get index keys that match this tag
            my $indexkey = $tag =~ /:/ ? "INDEX_$tag*" : "INDEX_*$tag*";
            my @keys = $redis->keys($indexkey);

            # Get the list of IDs for each key
            foreach my $key (@keys) {
                my @keyids = $redis->smembers($key);
                $logger->trace("Found index $key for $tag, containing " . scalar @keyids . " IDs");
                push @ids, @keyids;
            }

            # Append fuzzy title search
            my $namesearch = $isexact ? "$tag\x00*" : "*$tag*";
            my $scan = -1;

            while ($scan != 0) {
                # First iteration
                if ($scan == -1) { $scan = 0; }
                $logger->trace("Scanning for $namesearch, cursor=$scan");

                my @result = $redis->zscan("LRR_TITLES", $scan, "MATCH", $namesearch, "COUNT", 100);
                $scan = $result[0];

                foreach my $title (@{$result[1]}) {
                    if ($title eq "0") { next; }  # Skip scores
                    $logger->trace("Found title match: $title");

                    # Strip everything before \x00 to get the ID out of the key
                    my $id = substr($title, index($title, "\x00") + 1);
                    push @ids, $id;
                }
            }
        }
        
        if (scalar @ids == 0 && !$isneg) {
            # No more results, we can end search here
            $logger->trace("No results for this token, halting search.");
            @filtered = ();
            last;
        } else {
            $logger->trace("Found " . scalar @ids . " results for this token.");

            # Intersect the new list with the previous ones
            @filtered = intersect_arrays(\@ids, \@filtered, $isneg);

            if (scalar @filtered == 0) {
                $logger->trace("No more results after intersection, halting search.");
                last;
            }
        }
    }
    
    return @filtered;
}

# Apply the untagged and new filters
sub apply_common_filters {
    my ($filtered_ref, $newonly, $untaggedonly, $redis) = @_;
    my @filtered = @$filtered_ref;

    # If the untagged filter is enabled, call the untagged files API
    if ($untaggedonly) {
        my @untagged = $redis->smembers("LRR_UNTAGGED");
        @filtered = intersect_arrays(\@untagged, \@filtered, 0);
    }

    # Check new filter
    if ($newonly) {
        my @new = $redis->smembers("LRR_NEW");
        @filtered = intersect_arrays(\@new, \@filtered, 0);
    }

    return @filtered;
}

# Apply sorting to the filtered results
sub apply_sorting {
    my ($filtered_ref, $sortkey, $sortorder, $redis, $redis_db) = @_;
    my @filtered = @$filtered_ref;

    if ($sortkey eq "title") {
        my @ordered = ();

        # For title sorting, we can just use the LRR_TITLES set, which is sorted lexicographically (but not naturally).
        @ordered = nsort($redis->zrangebylex("LRR_TITLES", "-", "+"));
        if ($sortorder) {
            @ordered = reverse(@ordered);
        }

        # Remove the titles from the keys, which are stored as "title\x00id"
        @ordered = map { substr($_, index($_, "\x00") + 1) } @ordered;

        # Just intersect the ordered list with the filtered one to get the final result
        @filtered = intersect_arrays(\@filtered, \@ordered, 0);
    } else {
        # For other sorting, we need to get the metadata for each archive and sort it manually.
        @filtered = sort_results($sortkey, $sortorder, @filtered);
    }

    return @filtered;
}

# Transform the search engine syntax into a list of tokens.
# A token object contains the tag, whether it must be an exact match, and whether it must be absent.
sub compute_search_filter ($filter) {

    my $logger = get_logger( "Search Core", "lanraragi" );
    my @tokens = ();
    if ( !$filter ) { $filter = ""; }

    # Special characters:
    # "" for exact search (or $, but is that one really useful now?)
    # ?/_ for any character
    # * % for multiple characters
    # - to exclude the next tag

    $b = reverse($filter);
    while ( $b ne "" ) {

        my $char  = chop $b;
        my $isneg = 0;

        # Skip spaces
        while ( $char eq " " && $b ne "" ) {
            $char = chop $b;
        }

        if ( $char eq "-" ) {
            $isneg = 1;
            $char  = chop $b;
        }

        # Get characters until the next comma, or the next " if the following char is "
        my $delimiter = ',';
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

        #If last char is $ or delimiter was ", enable isexact
        if ( $delimiter eq '"' ) {
            $isexact = 1;

            # Quotes then $ is an accepted syntax, even though it does nothing
            $char = chop $b;
            unless ( $char eq "\$" ) {
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

        $tag = trim($tag);

        # Escape characters according to redis zscan rules
        $tag =~ s/([\[\]\^\\])/\\$1/g;

        # Replace placeholders with glob-style patterns,
        # ? or _ => ?
        $tag =~ s/\_/\?/g;

        # * or % => *
        $tag =~ s/\%/\*/g;

        if ( $tag ne "" ) {    # Blank tokens shouldn't be added as theyll slow down search
            push @tokens,
              { tag     => lc($tag),
                isneg   => $isneg,
                isexact => $isexact
              };
        }

    }
    return @tokens;
}

sub sort_results ( $sortkey, $sortorder, @filtered ) {

    my $redis = LANraragi::Model::Config->get_redis;

    my %tmpfilter = ();
    my @sorted    = ();

    # Map our archives to a hash, where the key is the ID and the value is what we want to sort by.
    # For lastreadtime, we just get the value directly.
    if ( $sortkey eq "lastread" ) {
        %tmpfilter = map { $_ => $redis->hget( $_, "lastreadtime" ) } @filtered;

        # Invert sort order for lastreadtime, biggest timestamps come first
        @sorted = map { $_->[0] }                    # Map back to only having the ID
          sort { $b->[1] <=> $a->[1] }               # Sort by the timestamp
          grep { defined $_->[1] && $_->[1] > 0 }    # Remove nil timestamps
          map  { [ $_, $tmpfilter{$_} ] }            # Map to an array containing the ID and the timestamp
          @filtered;                                 # List of IDs
    } else {

        my $re = qr/$sortkey/;

        # For other tags, we use the first tag we found that matches the sortkey/namespace.
        # (If no tag, defaults to "zzzz")
        %tmpfilter = map { $_ => ( $redis->hget( $_, "tags" ) =~ m/.*${re}:(.*?)(\,.*|$)/ ) ? $1 : "zzzz" } @filtered;

        # Read comments from the bottom up for a better understanding of this sort algorithm.
        @sorted = map { $_->[0] }                  # Map back to only having the ID
          sort { ncmp( $a->[1], $b->[1] ) }        # Sort by the tag
          map  { [ $_, lc( $tmpfilter{$_} ) ] }    # Map to an array containing the ID and the lowercased tag
          @filtered;                               # List of IDs
    }

    if ($sortorder) {
        @sorted = reverse @sorted;
    }

    return @sorted;
}

1;
