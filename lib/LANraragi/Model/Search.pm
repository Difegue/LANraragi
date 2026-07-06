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

use LANraragi::Utils::Generic qw(intersect_arrays);
use LANraragi::Utils::String  qw(trim);
use LANraragi::Utils::Redis   qw(redis_decode redis_encode);
use LANraragi::Utils::Logging qw(get_logger);

use LANraragi::Model::Archive;
use LANraragi::Model::Category;
use LANraragi::Model::Tankoubon qw(tank_has_archive_in_set get_tank_unified_tags);

# do_search (filter, category_id, page, key, order, newonly, untaggedonly, grouptanks, hidecompleted)
# Performs a search on the database.
sub do_search ( $filter, $category_id, $start, $sortkey, $sortorder, $newonly, $untaggedonly, $grouptanks, $hidecompleted ) {

    my $redis  = LANraragi::Model::Config->get_redis_search;
    my $logger = get_logger( "Search Engine", "lanraragi" );

    unless ( $redis->exists("LAST_JOB_TIME") && ( $redis->exists("LRR_TANKGROUPED") || !$grouptanks ) ) {
        $logger->warn("Search engine is not initialized yet. Please wait a few seconds.");

        # TODO - This is the only case where the API returns -1, but it's not really handled well clientside at the moment.
        return ( -1, -1, () );
    }

    $filter = $filter // "";
    my $tankcount = $redis->scard("LRR_TANKGROUPED") + 0;

    # Get tank ids count
    my $tankidscount = scalar( LANraragi::Model::Config->get_redis->keys('TANK_??????????') );

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
        my $keyed_count;
        ( $keyed_count, @filtered ) =
          search_uncached( $category_id, $filter, $sortkey, $sortorder, $newonly, $untaggedonly, $grouptanks, $hidecompleted );

        # Cache this query in the search database, prepending the keyed count for partition-aware cache inversion
        eval { $redis->hset( "LRR_SEARCHCACHE", $cachekey, nfreeze [ $keyed_count, @filtered ] ); };
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

# Grab all our IDs, then filter them down according to the following filters and tokens' ID groups.
sub search_uncached ( $category_id, $filter, $sortkey, $sortorder, $newonly, $untaggedonly, $grouptanks, $hidecompleted ) {

    my $redis    = LANraragi::Model::Config->get_redis_search;
    my $redis_db = LANraragi::Model::Config->get_redis;
    my $logger   = get_logger( "Search Core", "lanraragi" );

    # Compute search filters
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
        my @new     = $redis->smembers("LRR_NEW");
        my %new_set = map { $_ => 1 } @new;
        @filtered = grep { /^TANK/ ? tank_has_archive_in_set( $_, \%new_set ) : $new_set{$_} } @filtered;
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
            my $keyed_count;
            ( $keyed_count, @filtered ) = sort_results( $sortkey, $sortorder, @filtered );

            $redis->quit();
            $redis_db->quit();
            return ( $keyed_count, @filtered );
        }
    }

    $redis->quit();
    $redis_db->quit();

    # Title sort and unfiltered results: all archives are keyed
    return ( -1, @filtered );
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

    my $start_time = time();
    my $redis      = LANraragi::Model::Config->get_redis;
    my $logger     = get_logger( "Search Sort", "lanraragi" );
    my %tmpfilter  = ();
    my @sorted     = ();

    # Should there be no IDs requiring sorting, return an empty array directly
    if ( scalar @filtered == 0 ) {
        return ( 0, @sorted );
    }

    # Employ Lua scripting to fetch data in bulk, thereby minimizing network request frequency
    if ( $sortkey eq "lastread" ) {

        # Prepare a Lua script to retrieve the lastreadtime for both tanks (via ZRANGEBYSCORE of member archives)
        # and regular archives (via HGET)
        my $script = <<'LUA';
        local result = {}
        for i = 1, #ARGV do
            local id = ARGV[i]
            local value
            if string.sub(id, 1, 4) == "TANK" then
                local members = redis.call('ZRANGEBYSCORE', id, 1, '+inf')
                local max_time = 0
                for j = 1, #members do
                    local t = tonumber(redis.call('HGET', members[j], 'lastreadtime') or "0") or 0
                    if t > max_time then max_time = t end
                end
                value = tostring(max_time)
            else
                value = redis.call('HGET', id, 'lastreadtime') or "0"
            end
            result[i] = {id, value}
        end
        return cjson.encode(result)
LUA

        my $sha;
        eval { $sha = $redis->script_load($script); };
        if ($@) {
            $logger->error("Failed to load Lua script: $@");
            _fallback_lastread( $redis, \%tmpfilter, @filtered );
        } else {
            my $result = $redis->evalsha( $sha, 0, @filtered );
            my $data   = eval { decode_json($result) };
            if ($@) {
                $logger->error("Failed to decode JSON from Lua script: $@");
                _fallback_lastread( $redis, \%tmpfilter, @filtered );
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

        if ($sortorder) {
            @sorted = reverse @sorted;
        }

        my $total_time = time() - $start_time;
        $logger->debug("[PERF] sort_results completed in ${total_time}s");

        # lastread: all returned archives are keyed (nil timestamps excluded)
        return ( -1, @sorted );

    } else {

        # Prepare a Lua script to retrieve all tags for both tanks (tags stored in ZSET at score -2)
        # and regular archives (tags stored in HGET)
        my $script = <<'LUA';
        local result = {}
        for i = 1, #ARGV do
            local id = ARGV[i]
            local tags
            if string.sub(id, 1, 4) == "TANK" then
                local raw = redis.call('ZRANGEBYSCORE', id, -2, -2)
                if #raw > 0 and string.sub(raw[1], 1, 5) == "tags_" then
                    tags = string.sub(raw[1], 6)
                else
                    tags = ""
                end
            else
                tags = redis.call('HGET', id, 'tags') or ""
            end
            result[i] = {id, tags}
        end
        return cjson.encode(result)
LUA

        my $re  = qr/$sortkey/;
        my $sha;
        eval { $sha = $redis->script_load($script); };
        if ($@) {
            $logger->error("Failed to load Lua script: $@");
            _fallback_tags( $redis, \%tmpfilter, $re, @filtered );
        } else {
            my $result = $redis->evalsha( $sha, 0, @filtered );
            my $data   = eval { decode_json($result) };
            if ($@) {
                $logger->error("Failed to decode JSON from Lua script: $@");
                _fallback_tags( $redis, \%tmpfilter, $re, @filtered );
            } else {
                foreach my $item (@$data) {
                    my $id   = $item->[0];
                    my $tags = $item->[1];

                    # Find and use the first tag that matches the sortkey/namespace.
                    # (If no tag, defaults to "zzzz")
                    $tmpfilter{$id} = ( $tags =~ m/.*${re}:(.*?)(\,.*|$)/ ) ? $1 : "zzzz";
                }
            }
        }

        # If this is a date_added/timestamp sort, we need to have the same behavior here
        # as in Tankoubon::get_tank_unified_tags, where timestamps are inferred by the containing archives. 
        if ( $sortkey eq "date_added" || $sortkey eq "timestamp" ) {
            _impute_tank_date_tags( \%tmpfilter, $sortkey, @filtered );
        }

        # Partition: IDs that have the sort namespace vs those that don't
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

        # IDs missing the sort namespace always go to the back
        push @sorted, @unkeyed_ids;

        my $total_time = time() - $start_time;
        $logger->debug("[PERF] sort_results completed in ${total_time}s");
        return ( scalar @keyed_ids, @sorted );
    }
}

# For tanks currently unkeyed in search results (filter is at "zzzz"),
# get the unified tags from the model and check if any of them match the sortkey namespace.  
# This is mostly meant for date_added/timestamp, which are inferred from the member archives if not present on the tank itself.
sub _impute_tank_date_tags ( $tmpfilter, $sortkey, @filtered ) {
    foreach my $id (@filtered) {
        next unless $id =~ /^TANK/;
        next unless ( $tmpfilter->{$id} // "zzzz" ) eq "zzzz";

        my $unified = get_tank_unified_tags($id);
        foreach my $tag ( @{ $unified->{imputed_tags} } ) {
            if ( $tag =~ /^\Q$sortkey\E:(\d+)$/i ) {
                $tmpfilter->{$id} = $1;
                last;
            }
        }
    }
}

# Fallback for lastread sorting when Lua is unavailable.
# Fetches lastreadtime manually for each ID, computing max across member archives for tanks.
sub _fallback_lastread ( $redis, $tmpfilter, @filtered ) {
    my @tank_ids    = grep { /^TANK/ } @filtered;
    my @archive_ids = grep { !/^TANK/ } @filtered;

    foreach my $tank_id (@tank_ids) {
        my @arc_ids  = $redis->zrangebyscore( $tank_id, 1, "+inf" );
        my $max_time = 0;
        foreach my $arc_id (@arc_ids) {
            my $t = $redis->hget( $arc_id, "lastreadtime" ) // 0;
            $max_time = $t if $t > $max_time;
        }
        $tmpfilter->{$tank_id} = $max_time;
    }

    %$tmpfilter = ( %$tmpfilter, map { $_ => $redis->hget( $_, "lastreadtime" ) } @archive_ids );
}

# Fallback for tag-based sorting when Lua is unavailable.
# Fetches tags via ZRANGEBYSCORE for tanks and HGET for archives, then extracts the sort key value.
sub _fallback_tags ( $redis, $tmpfilter, $re, @filtered ) {
    my @tank_ids    = grep { /^TANK/ } @filtered;
    my @archive_ids = grep { !/^TANK/ } @filtered;

    foreach my $tank_id (@tank_ids) {
        my @raw      = $redis->zrangebyscore( $tank_id, -2, -2 );
        my $tags_str = "";
        if ( @raw && $raw[0] =~ /^tags_(.*)/ ) {
            $tags_str = redis_decode($1) // "";
        }
        $tmpfilter->{$tank_id} = ( $tags_str =~ m/.*${re}:(.*?)(\,.*|$)/ ) ? $1 : "zzzz";
    }

    %$tmpfilter = (
        %$tmpfilter,
        map { $_ => ( $redis->hget( $_, "tags" ) =~ m/.*${re}:(.*?)(\,.*|$)/ ) ? $1 : "zzzz" } @archive_ids
    );
}

1;