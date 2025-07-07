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
use Time::HiRes qw(time);

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
    
    $logger->debug("Starting do_search with filter: $filter, category: $category_id, sortkey: $sortkey, sortorder: $sortorder");
    # Ensure all parameters have default values to avoid 'uninitialized value' warnings
    $filter = "" unless defined $filter;
    $category_id = "" unless defined $category_id;
    $start = 0 unless defined $start;
    $sortkey = "" unless defined $sortkey;
    #$sortkey = "date_added" unless (defined $sortkey && $sortkey ne "") || $sortkey eq "title";

    if ($sortkey eq "date_added") {
    $sortorder = 1;
    } else {
    # 当 sortkey 不是 "date_added" 时，检查 sortorder 是否未定义
    $sortorder = 1 unless defined $sortorder;
    }

    $newonly = 0 unless defined $newonly;
    $untaggedonly = 0 unless defined $untaggedonly;
    $grouptanks = 0 unless defined $grouptanks;
    $logger->debug("ending do_search with filter: $filter, category: $category_id, sortkey: $sortkey, sortorder: $sortorder");

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
    # Ensure sortkey has a default value to avoid 'uninitialized value' warnings
    my $sortkey_safe = defined $sortkey ? $sortkey : "";
    my $cachekey      = redis_encode("$category_id-$filter-$sortkey_safe-$sortorder-$newonly-$untaggedonly-$grouptanks");
    my $cachekey_inv  = redis_encode("$category_id-$filter-$sortkey_safe-$sortorder_inv-$newonly-$untaggedonly-$grouptanks");
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

    # Ensure all parameters have default values to avoid 'uninitialized value' warnings
    $cachekey = "" unless defined $cachekey;
    $cachekey_inv = "" unless defined $cachekey_inv;

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
sub search_uncached ( $category_id, $filter, $sortkey, $sortorder, $newonly, $untaggedonly, $grouptanks ) {

    my $start_time = time();
    my $redis    = LANraragi::Model::Config->get_redis_search;
    my $redis_db = LANraragi::Model::Config->get_redis;
    my $logger   = get_logger( "Search Core", "lanraragi" );
    
    $logger->debug("Starting search_uncached with filter: $filter, category: $category_id, sortkey: $sortkey, sortorder: $sortorder");
    
    # Ensure all parameters have default values to avoid 'uninitialized value' warnings
    $filter = "" unless defined $filter;
    $category_id = "" unless defined $category_id;
    #$sortkey = "" unless defined $sortkey;
    $sortkey = "date_added" unless (defined $sortkey && $sortkey ne "") || $sortkey eq "title";

    if ($sortkey eq "date_added") {
    $sortorder = 1;
    } else {
    # 当 sortkey 不是 "date_added" 时，检查 sortorder 是否未定义
    $sortorder = 1 unless defined $sortorder;
    }
    
    $newonly = 0 unless defined $newonly;
    $untaggedonly = 0 unless defined $untaggedonly;
    $grouptanks = 0 unless defined $grouptanks;

    $logger->debug("ending search_uncached with filter: $filter, category: $category_id, sortkey: $sortkey, sortorder: $sortorder");

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
                my $operator  = $2 || "="; # If no operator is specified, we assume it's an exact match
                my $pagecount = $3;

                $logger->debug("Searching for IDs with $operator $pagecount $col");

                # Change the column based off the tag searched.
                # "pages" -> "pagecount"
                # "read" -> "progress"
                $col = $col eq "pages" ? "pagecount" : "progress";
                
                # Use Lua script to batch process pagecount/progress filtering
                my $script = <<'LUA';
                local ids = ARGV[1]
                local col = ARGV[2]
                local operator = ARGV[3]
                local pagecount = tonumber(ARGV[4])
                local result = {}
                
                -- Convert comma-separated IDs string to table
                local id_table = {}
                for id in string.gmatch(ids, "[^,]+") do
                    table.insert(id_table, id)
                end
                
                for i, id in ipairs(id_table) do
                    -- Skip tank IDs
                    if not string.match(id, "^TANK") then
                        -- Default to 0 if null
                        local count = tonumber(redis.call('HGET', id, col) or 0)
                        
                        local match = false
                        if operator == "=" and count == pagecount then
                            match = true
                        elseif operator == ">" and count > pagecount then
                            match = true
                        elseif operator == ">=" and count >= pagecount then
                            match = true
                        elseif operator == "<" and count < pagecount then
                            match = true
                        elseif operator == "<=" and count <= pagecount then
                            match = true
                        end
                        
                        if match then
                            table.insert(result, id)
                        end
                    end
                end
                
                return result
LUA
                
                # Convert filtered array to comma-separated string for Lua
                my $ids_str = join(",", @filtered);
                my @result = $redis_db->eval($script, 0, $ids_str, $col, $operator, $pagecount);
                @ids = @result;
                $logger->debug("Found " . scalar @ids . " IDs matching $operator $pagecount $col");
            }

            # Use Lua script to batch process tag search for better performance
            my $script;
            if ($isexact) {
                # For exact tag searches, just check if an index for it exists and get its members
                $script = <<'LUA';
                local tag = ARGV[1]
                local key = "INDEX_"..tag
                if redis.call('EXISTS', key) == 1 then
                    return redis.call('SMEMBERS', key)
                else
                    return {}
                end
LUA
                my @result = $redis->eval($script, 0, $tag);
                @ids = @result;
                $logger->debug("Found tag index for $tag, containing " . scalar @ids . " IDs");
            } else {
                # For fuzzy tag searches, get all matching keys and their members in one go
                $script = <<'LUA';
                local tag = ARGV[1]
                local has_namespace = string.find(tag, ":") ~= nil
                local pattern = has_namespace and "INDEX_"..tag.."*" or "INDEX_*"..tag.."*"
                local keys = redis.call('KEYS', pattern)
                local result = {}
                
                for i, key in ipairs(keys) do
                    local members = redis.call('SMEMBERS', key)
                    for j, member in ipairs(members) do
                        table.insert(result, member)
                    end
                end
                
                return result
LUA
                my @result = $redis->eval($script, 0, $tag);
                @ids = @result;
                $logger->debug("Found " . scalar @ids . " IDs for fuzzy tag search: $tag");
            }

            # Append fuzzy title search using Lua script for better performance
            my $namesearch = $isexact ? "$tag\x00*" : "*$tag*";
            $logger->trace("Scanning for title matches: $namesearch");
            
            # Use Lua script to perform the entire zscan operation in one go
            my $script = <<'LUA';
            local pattern = ARGV[1]
            local result = {}
            local cursor = 0
            local done = false
            
            while not done do
                local scan_result = redis.call('ZSCAN', 'LRR_TITLES', cursor, 'MATCH', pattern, 'COUNT', 1000)
                cursor = tonumber(scan_result[1])
                
                -- Process the results, skipping scores (every other element)
                for i = 1, #scan_result[2], 2 do
                    local title = scan_result[2][i]
                    if title ~= "0" then
                        -- Find the position of the null byte and extract the ID
                        local pos = string.find(title, string.char(0))
                        if pos then
                            local id = string.sub(title, pos + 1)
                            table.insert(result, id)
                        end
                    end
                end
                
                -- Check if we're done scanning
                if cursor == 0 then
                    done = true
                end
            end
            
            return result
LUA
            
            my @title_ids = $redis->eval($script, 0, $namesearch);
            $logger->debug("Found " . scalar @title_ids . " title matches for: $tag");
            push @ids, @title_ids;

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
            $sortkey = "date_added";
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
    
    my $end_time = time();
    $logger->debug("Search completed in " . ($end_time - $start_time) . " seconds, found " . scalar(@filtered) . " results");
    
    return @filtered;
}

# Transform the search engine syntax into a list of tokens.
# A token object contains the tag, whether it must be an exact match, and whether it must be absent.
sub compute_search_filter ($filter) {

    my $logger = get_logger( "Search Core", "lanraragi" );
    my @tokens = ();
    
    # Ensure filter has a default value
    $filter = "" unless defined $filter;

    # Special characters:
    # "" for exact search (or $, but is that one really useful now?)
    # ?/_ for any character
    # * % for multiple characters
    # - to exclude the next tag

    my $b = reverse($filter);
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
    my $redis = LANraragi::Model::Config->get_redis;
    my $logger = get_logger( "Search Sort", "lanraragi" );
    my %tmpfilter = ();
    my @sorted    = ();

    # Should there be no IDs requiring sorting, return an empty array directly
    if (scalar @filtered == 0) {
        return @sorted;
    }

    # Ensure all parameters have default values to avoid 'uninitialized value' warnings
    $sortkey = "" unless defined $sortkey;
    $sortorder = 0 unless defined $sortorder;

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
            $logger->debug("[PERF] Lua script completedin ${total_time}s");
        };
        if ($@) {
            $logger->error("Failed to load Lua script: $@");
            # Revert to the original methodology
            %tmpfilter = map { $_ => $redis->hget( $_, "lastreadtime" ) } @filtered;
        } else {
            my $result = $redis->evalsha($sha, 0, @filtered);
            my $data = eval { decode_json($result) };
            if ($@) {
                $logger->error("Failed to decode JSON from Lua script: $@");
                # Revert to the original methodology
                %tmpfilter = map { $_ => $redis->hget( $_, "lastreadtime" ) } @filtered;
            } else {
                # Convert the results into a hash table
                foreach my $item (@$data) {
                    $tmpfilter{$item->[0]} = $item->[1];
                }
            }
        }

        # The sorting logic shall remain unaltered
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
            $logger->debug("[PERF] another Lua script completed in ${total_time}s");
        };
        if ($@) {
            $logger->error("Failed to load Lua script: $@");
            # Revert to the original methodology
            my $re = qr/$sortkey/;
            %tmpfilter = map { $_ => ( $redis->hget( $_, "tags" ) =~ m/.*${re}:(.*?)(\,.*|$)/ ) ? $1 : "zzzz" } @filtered;
        } else {
            my $result = $redis->evalsha($sha, 0, @filtered);
            my $data = eval { decode_json($result) };
            if ($@) {
                $logger->error("Failed to decode JSON from Lua script: $@");
                # Revert to the original methodology
                my $re = qr/$sortkey/;
                %tmpfilter = map { $_ => ( $redis->hget( $_, "tags" ) =~ m/.*${re}:(.*?)(\,.*|$)/ ) ? $1 : "zzzz" } @filtered;
            } else {
                my $re = qr/$sortkey/;
                foreach my $item (@$data) {
                    my $id = $item->[0];
                    my $tags = $item->[1];
                    $tmpfilter{$id} = ($tags =~ m/.*${re}:(.*?)(\,.*|$)/) ? $1 : "zzzz";
                }
            }
        }

        # The sorting logic shall remain unaltered
        @sorted = map { $_->[0] }                  # Map back to only having the ID
          sort { ncmp( $a->[1], $b->[1] ) }        # Sort by the tag
          map  { [ $_, lc( $tmpfilter{$_} ) ] }    # Map to an array containing the ID and the lowercased tag
          @filtered;                               # List of IDs
    }

    if ($sortorder) {
        @sorted = reverse @sorted;
    }
    my $total_time = time() - $start_time;
    $logger->debug("[PERF] sort_results completed in ${total_time}s");
    return @sorted;
}

1;