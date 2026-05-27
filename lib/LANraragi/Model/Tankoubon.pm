package LANraragi::Model::Tankoubon;

use feature qw(signatures fc);
no warnings 'experimental::signatures';
use experimental 'try';

use strict;
use warnings;
use utf8;

use Redis;
use Mojo::JSON qw(decode_json encode_json);
use List::Util      qw(min);
use List::MoreUtils qw(uniq);
use File::Copy qw(copy);
use File::Path qw(make_path);

use LANraragi::Utils::Archive  qw(extract_thumbnail);
use LANraragi::Utils::Database qw(invalidate_cache get_archive_json_multi get_tankoubons_by_file update_indexes);
use LANraragi::Utils::Generic  qw(array_difference filter_hash_by_keys render_api_response);
use LANraragi::Utils::Logging  qw(get_logger);
use LANraragi::Utils::Redis    qw(redis_decode redis_encode);
use LANraragi::Utils::String   qw(trim);
use LANraragi::Utils::Tags     qw(join_tags_to_string split_tags_to_array);

my %TANK_METADATA = ( "name", 0, "summary", -1, "tags", -2, "progress", -3 );

use Exporter 'import';
our @EXPORT_OK = qw(tank_has_archive_in_set set_tank_tags get_tank_unified_tags update_tank_imputed_indexes serve_tankoubon_thumbnail update_tankoubon_thumbnail update_tank_progress);

# get_tankoubon_list(page)
#   Returns a list of all the Tankoubon objects.
sub get_tankoubon_list ( $page = 0 ) {

    my $redis  = LANraragi::Model::Config->get_redis;
    my $logger = get_logger( "Tankoubon", "lanraragi" );

    $page //= 0;

    # Tankoubons are represented by TANK_[timestamp] in DB. Can't wait for 2038!
    my @tanks = $redis->keys('TANK_??????????');

    # Jam tanks into an array of hashes
    my @result;
    foreach my $key ( sort @tanks ) {
        my ( $total, $filtered, %data ) = get_tankoubon($key);
        push( @result, \%data );
    }

    # # Only get the first X keys
    my $keysperpage = LANraragi::Model::Config->get_pagesize;

    # Return total keys and the filtered ones
    my $total = $#tanks + 1;
    my $start = $page * $keysperpage;
    my $end   = min( $start + $keysperpage - 1, $#result );

    if ( $page < 0 ) {
        return ( $total, $total, @result );
    } else {
        return ( $total, $#result + 1, @result[ $start .. $end ] );
    }

    #return @result;
}

# create_tankoubon(name, existing_id)
#   Create a Tankoubon.
#   If an existing Tankoubon ID is supplied, said Tankoubon will be updated with the given parameters.
#   Returns the ID of the created/updated Tankoubon.
sub create_tankoubon ( $name, $tank_id ) {

    my $redis        = LANraragi::Model::Config->get_redis;
    my $redis_search = LANraragi::Model::Config->get_redis_search;
    my $logger       = get_logger( "Tankoubon", "lanraragi" );

    # Set all fields of the group object
    unless ( length($tank_id) ) {
        $tank_id = "TANK_" . time();

        my $isnewkey = 0;
        until ($isnewkey) {

            # Check if the group ID exists, move timestamp further if it does
            if ( $redis->exists($tank_id) ) {
                $tank_id = "TANK_" . ( time() + 1 );
            } else {
                $isnewkey = 1;
            }
        }
    } else {

        # Get name
        my @old_name = $redis->zrangebyscore( $tank_id, 0, 0, qw{LIMIT 0 1} );
        my $n        = redis_decode( $old_name[0] );

        if ( $redis->exists($tank_id) ) {
            $redis->zrem( $tank_id, $n );
        }
    }

    # Add the tank name to LRR_TITLES so it shows up in tagless searches when tank grouping is enabled.
    # Title must be lowercased to match how search queries are processed.
    my $tank_title_lower = lc($name);
    $redis_search->zadd( "LRR_TITLES", 0, "$tank_title_lower\0$tank_id" );

    # Default values for metadata
    # Score 0 is reserved for the name of the tank
    $redis->zadd( $tank_id, $TANK_METADATA{"name"},     redis_encode("name_${name}") );
    $redis->zadd( $tank_id, $TANK_METADATA{"summary"},  "summary_" );
    $redis->zadd( $tank_id, $TANK_METADATA{"tags"},     "tags_" );
    $redis->zadd( $tank_id, $TANK_METADATA{"progress"}, "progress_0" );

    $redis->quit;
    $redis_search->quit;
    invalidate_cache();

    return $tank_id;
}

# get_tankoubon(tankoubonid, fulldata, page)
#   Returns the Tankoubon matching the given id.
#   Returns undef if the id doesn't exist.
sub get_tankoubon ( $tank_id, $fulldata = 0, $page = 0 ) {

    my $logger      = get_logger( "Tankoubon", "lanraragi" );
    my $redis       = LANraragi::Model::Config->get_redis;
    my $keysperpage = LANraragi::Model::Config->get_pagesize;

    $page //= 0;

    if ( $tank_id eq "" ) {
        $logger->debug("No Tankoubon ID provided.");
        return ();
    }

    unless ( length($tank_id) == 15 && $redis->exists($tank_id) ) {
        $logger->warn("$tank_id doesn't exist in the database!");
        return ();
    }

    # Declare some needed variables
    my @allowed_keys = ( 'name', 'summary', 'tags', 'progress', 'archives', 'full_data', 'id' );
    my @archives;
    my @limit = split( ' ', "LIMIT " . ( $keysperpage * $page ) . " $keysperpage" );
    my %tank  = fetch_metadata_fields($tank_id);

    my %tankoubon;

    # Grab page
    if ( $page < 0 ) {
        %tankoubon = $redis->zrangebyscore( $tank_id, 1, "+inf", "WITHSCORES" );
    } else {
        %tankoubon = $redis->zrangebyscore( $tank_id, 1, "+inf", "WITHSCORES", @limit );
    }

    # Sort and add IDs to archives array
    foreach my $i ( sort { $tankoubon{$a} <=> $tankoubon{$b} } keys %tankoubon ) {
        push( @archives, $i );
    }

    # Verify if we require fulldata files or just IDs
    if ($fulldata) {
        my @data = get_archive_json_multi(@archives);
        eval { $tank{archives}  = \@archives };
        eval { $tank{full_data} = \@data }
    } else {
        eval { $tank{archives} = \@archives };
    }

    if ($@) {
        $logger->error("Couldn't deserialize contents of Tankoubon $tank_id! $@");
    }

    # Add the key as well
    $tank{id} = $tank_id;

    %tank = filter_hash_by_keys( \@allowed_keys, %tank );

    # Coerce progress to integer
    $tank{progress} = int( $tank{progress} || 0 );

    my $total = $redis->zcount($tank_id, 1, "+inf");

    return ( $total, $#archives + 1, %tank );
}

# delete_tankoubon(tankoubonid)
#   Deletes the Tankoubon with the given ID.
#   Returns 0 if the given ID isn't a Tankoubon ID, 1 otherwise
sub delete_tankoubon ($tank_id) {

    my $logger       = get_logger( "Tankoubon", "lanraragi" );
    my $redis        = LANraragi::Model::Config->get_redis;
    my $redis_search = LANraragi::Model::Config->get_redis_search;

    if ( length($tank_id) != 15 ) {

        # Probably not a Tankoubon ID
        $logger->error("$tank_id is not a Tankoubon ID, doing nothing.");
        $redis->quit;
        return 0;
    }

    if ( $redis->exists($tank_id) ) {

        # Get archives in the tank before deleting, so we can re-add them to LRR_TANKGROUPED
        my @archives = $redis->zrangebyscore( $tank_id, 1, "+inf" );

        $redis->del($tank_id);

        # The ID will remain in LRR_TITLES until the next stats compute, but this'll prevent it from appearing in search.
        $redis_search->srem( "LRR_TANKGROUPED", $tank_id );

        # Re-add archives to LRR_TANKGROUPED if they're not in any other tank
        foreach my $arc_id (@archives) {
            unless ( get_tankoubons_containing_archive($arc_id) ) {
                $redis_search->sadd( "LRR_TANKGROUPED", $arc_id );
            }
        }

        $redis->quit;
        $redis_search->quit;
        invalidate_cache();

        return 1;
    } else {
        $logger->warn("$tank_id doesn't exist in the database!");
        $redis->quit;
        return 1;
    }
}

# update_tankoubon(name, data)
#   Updates metadata and archive list.
#   Returns 1 on success, 0 on failure alongside an error message.
sub update_tankoubon ( $tank_id, $data ) {

    my ( $result, $err ) = update_metadata( $tank_id, $data );
    if ($result) {
        my ( $result, $err ) = update_archive_list( $tank_id, $data );
    }

    return ( $result, $err );
}

# update_metadata(tankoubonid, data)
#   Updates the metadata in the Tankoubon.
#   Returns 1 on success, 0 on failure alongside an error message.
sub update_metadata ( $tank_id, $data ) {

    if ( not defined $data->{"metadata"} ) {
        return ( 1, "" );
    }

    my $logger  = get_logger( "Tankoubon", "lanraragi" );
    my $redis   = LANraragi::Model::Config->get_redis;
    my $err     = "";
    my $name    = $data->{"metadata"}->{"name"}    || undef;
    my $summary = exists $data->{"metadata"}->{"summary"} ? $data->{"metadata"}->{"summary"} : undef;
    my $tags = exists $data->{"metadata"}->{"tags"} ? $data->{"metadata"}->{"tags"} : undef;

    if ( $redis->exists($tank_id) ) {
        if ( defined $name ) {
            update_metadata_field( $tank_id, "name", $name );
        }

        if ( defined $summary ) {
            update_metadata_field( $tank_id, "summary", $summary );
        }

        if ( defined $tags ) {
            set_tank_tags( $tank_id, $tags );
        }

        $redis->quit;
        invalidate_cache();
        return ( 1, $err );
    }

    $redis->quit;

    $err = "$tank_id doesn't exist in the database!";
    $logger->warn($err);

    return ( 0, $err );
}

# update_archive_list(tankoubonid, arcid)
#   Updates the archives list in a Tankoubon.
#   Returns 1 on success, 0 on failure alongside an error message.
sub update_archive_list ( $tank_id, $data ) {

    if ( not defined $data->{"archives"} ) {
        return ( 1, "" );
    }

    my $logger        = get_logger( "Tankoubon", "lanraragi" );
    my $redis         = LANraragi::Model::Config->get_redis;
    my $redis_search  = LANraragi::Model::Config->get_redis_search;
    my $err           = "";
    my @tank_archives = @{ $data->{"archives"} };

    if ( $redis->exists($tank_id) ) {

        foreach my $key (@tank_archives) {
            unless ( $redis->exists($key) ) {
                $err = "$key does not exist in the database.";
                $logger->error($err);
                $redis->quit;
                return ( 0, $err );
            }
        }

        my @origs = $redis->zrangebyscore( $tank_id, 1, "+inf" );
        my @diff  = array_difference( \@tank_archives, \@origs );
        my @update;

        # Collect tags from removed archives for index cleanup
        my @removed_tags;
        foreach my $arc_id (@diff) {
            my $arc_tags_str = redis_decode( $redis->hget( $arc_id, "tags" ) ) // "";
            push @removed_tags, split_tags_to_array($arc_tags_str);
        }

        $redis->multi;
        $redis_search->multi;

        # Remove the ones not in the order
        if (@diff) {
            $redis->zrem( $tank_id, @diff );

            # Make removed archives visible in search again unless other tanks contain them
            foreach my $arc_id (@diff) {
                unless ( get_tankoubons_containing_archive($arc_id) ) {
                    $redis_search->sadd( "LRR_TANKGROUPED", $arc_id );
                }
            }
        }

        # Prepare zadd array
        my $len = @tank_archives;

        if ( $len == 0 ) {
            $redis_search->srem( "LRR_TANKGROUPED", $tank_id );
        } else {
            $redis_search->sadd( "LRR_TANKGROUPED", $tank_id );

            for ( my $i = 0; $i < $len; $i = $i + 1 ) {
                push @update, $i + 1;
                push @update, $tank_archives[$i];

                # Remove the ID if present, as it's been absorbed into the tank
                $redis_search->srem( "LRR_TANKGROUPED", $tank_archives[$i] );
            }

            # Update
            $redis->zadd( $tank_id, @update );
        }
        $redis->exec;
        $redis_search->exec;

        $redis->quit;
        $redis_search->quit;

        # Update imputed tag indexes (handles both additions and removals)
        update_tank_imputed_indexes( $tank_id, \@removed_tags );

        invalidate_cache();
        return ( 1, $err );
    }

    $err = "$tank_id doesn't exist in the database!";
    $logger->warn($err);
    $redis->quit;
    return ( 0, $err );
}

# add_to_tankoubon(tankoubonid, arcid)
#   Adds the given archive ID to the given Tankoubon.
#   Returns 1 on success, 0 on failure alongside an error message.
sub add_to_tankoubon ( $tank_id, $arc_id ) {

    my $logger = get_logger( "Tankoubon", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis;
    my $err    = "";

    if ( $redis->exists($tank_id) ) {

        unless ( $redis->exists($arc_id) ) {
            $err = "$arc_id does not exist in the database.";
            $logger->error($err);
            $redis->quit;
            return ( 0, $err );
        }

        if ( $redis->zscore( $tank_id, $arc_id ) ) {
            $err = "$arc_id already present in category $tank_id, doing nothing.";
            $logger->warn($err);
            $redis->quit;
            return ( 1, $err );
        }

        my $score = $redis->zcard($tank_id);

        $redis->zadd( $tank_id, $score, $arc_id );
        $redis->quit;

        # Adding an archive to the tank will always hide it from main search, and show the tank instead
        $redis = LANraragi::Model::Config->get_redis_search;
        $redis->srem( "LRR_TANKGROUPED", $arc_id );
        $redis->sadd( "LRR_TANKGROUPED", $tank_id );    # Set elements are unique so no problem if the tank is already added here
        $redis->quit;

        # Update imputed tag indexes for the tank (pure addition, no removed_tags)
        update_tank_imputed_indexes($tank_id);

        invalidate_cache();
        return ( 1, $err );
    }

    $err = "$tank_id doesn't exist in the database!";
    $logger->warn($err);
    $redis->quit;
    return ( 0, $err );
}

# remove_from_tankoubon(tankoubonid, arcid)
#   Removes the given archive ID from the given Tankoubon.
#   Returns the position of the removed ID (starting at 1) on success, 0 on failure alongside an error message.
sub remove_from_tankoubon ( $tank_id, $arcid ) {

    my $logger = get_logger( "Tankoubon", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis;
    my $err    = "";

    if ( $redis->exists($tank_id) ) {

        unless ( $redis->exists($arcid) ) {
            $err = "$arcid does not exist in the database.";
            $logger->error($err);
            $redis->quit;
            return ( 0, $err );
        }

        # Get the score for reference
        my $score = $redis->zscore( $tank_id, $arcid );

        unless ($score) {
            $err = "$arcid not in tankoubon $tank_id, doing nothing.";
            $logger->warn($err);
            $redis->quit;
            return ( 0, $err );
        }

        # Get archive's tags before removal for index cleanup
        my $arc_tags_str = redis_decode( $redis->hget( $arcid, "tags" ) ) // "";
        my @arc_tags = split_tags_to_array($arc_tags_str);

        # Get all the elements after the one to remove to update the score
        my %toupdate = $redis->zrangebyscore( $tank_id, $score + 1, "+inf", "WITHSCORES" );

        my @update;

        # Build new scores
        foreach my $i ( keys %toupdate ) {
            push @update, $toupdate{$i} - 1;
            push @update, $i;
        }

        # Remove element
        $redis->zrem( $tank_id, $arcid );

        # Update scores
        if ( scalar @update ) {
            $redis->zadd( $tank_id, @update );
        }

        if ( $redis->zcard($tank_id) == 1 ) {

            # No elements in tank, remove it from search
            $redis->srem( "LRR_TANKGROUPED", $tank_id );
        }

        $redis->quit;

        # Removing an archive from a tank might have it show up in main search again
        unless ( get_tankoubons_containing_archive($arcid) ) {
            $redis = LANraragi::Model::Config->get_redis_search;
            $redis->sadd( "LRR_TANKGROUPED", $arcid );
            $redis->quit;
        }

        # Update imputed tag indexes for the tank (pass removed archive's tags for cleanup)
        update_tank_imputed_indexes( $tank_id, \@arc_tags );

        # We could reset progress on the tank here when archives are removed, but it feels like bad UX
        # update_metadata_field( $tank_id, "progress", 0 );

        invalidate_cache();
        # Subtract 3 from the score to exclude the metadata fields
        # A bit brittle if we add more fields later...
        return ( $score - 3, $err );
    }

    $err = "$tank_id doesn't exist in the database!";
    $logger->warn($err);
    $redis->quit;
    return ( 0, $err );
}

# get_tankoubons_containing_archive(arcid)
#   Gets a list of Tankoubons where archive ID is contained.
#   Returns an array of tank IDs.
sub get_tankoubons_containing_archive ($arcid) {

    my $redis = LANraragi::Model::Config->get_redis;
    my @tankoubons;

    my $logger = get_logger( "Tankoubon", "lanraragi" );
    my $err    = "";

    unless ( $redis->exists($arcid) ) {
        $err = "$arcid does not exist in the database.";
        $logger->error($err);
        $redis->quit;
        return ();
    }

    my @tanks = $redis->keys('TANK_??????????');

    foreach my $key ( sort @tanks ) {

        if ( $redis->zscore( $key, $arcid ) ) {
            push( @tankoubons, $key );
        }
    }

    $redis->quit;
    return @tankoubons;
}

sub update_metadata_field ( $tank_id, $field, $value ) {
    my $redis = LANraragi::Model::Config->get_redis;

    $redis->zremrangebyscore( $tank_id, $TANK_METADATA{$field}, $TANK_METADATA{$field} );
    $redis->zadd( $tank_id, $TANK_METADATA{$field}, redis_encode("${field}_${value}") );

    return 1;
}

# update_tank_progress(tank_id, page)
#   Saves the given page number as the tank's reading progress.
#   Returns 1 on success, 0 on failure alongside an error message.
sub update_tank_progress ( $tank_id, $page ) {

    my $logger = get_logger( "Tankoubon", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis;
    my $err    = "";

    unless ( $redis->exists($tank_id) ) {
        $err = "$tank_id doesn't exist in the database!";
        $logger->warn($err);
        $redis->quit;
        return ( 0, $err );
    }

    $redis->quit;

    update_metadata_field( $tank_id, "progress", $page );

    return ( 1, $err );
}

sub fetch_metadata_fields ($tank_id) {
    my $redis = LANraragi::Model::Config->get_redis;

    # Fetch from DB
    my @keys       = sort { $TANK_METADATA{$a} <=> $TANK_METADATA{$b} } keys(%TANK_METADATA);
    my @raw_values = $redis->zrangebyscore( $tank_id, $TANK_METADATA{ $keys[0] }, 0 );

    # Clean the data
    my %metadata;
    foreach my $raw_value (@raw_values) {
        foreach my $key (@keys) {
            if ( $raw_value =~ /^$key\_/ ) {
                my $clean_value = redis_decode($raw_value) || "";
                $clean_value =~ s/^$key\_//;
                $metadata{$key} = $clean_value;
                last;    # Exit the loop once the key is matched
            }
        }
    }

    return %metadata;
}

# set_tank_tags(tank_id, newtags, append)
#   Set tags for a tankoubon, updating search indexes.
#   Set $append to 1 to append tags instead of replacing.
#   Returns 1 on success, 0 on failure with error message.
sub set_tank_tags ( $tank_id, $newtags, $append = 0 ) {

    my $logger = get_logger( "Tankoubon", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis;

    unless ( $redis->exists($tank_id) ) {
        $redis->quit;
        my $err = "$tank_id doesn't exist in the database!";
        $logger->warn($err);
        return ( 0, $err );
    }

    # Get old tags from ZSET score -2
    my @raw = $redis->zrangebyscore( $tank_id, -2, -2 );
    my $oldtags = "";
    if ( @raw && $raw[0] =~ /^tags_(.*)/ ) {
        $oldtags = redis_decode($1) // "";
    }
    $redis->quit;

    if ($append) {

        # If the new tags are empty, don't do anything
        unless ( length $newtags ) { return ( 1, "" ); }

        if ( $oldtags ne "" ) {
            $newtags = $oldtags . "," . $newtags;
        }
    }

    # Deduplicate tags
    $newtags = join_tags_to_string( uniq( split_tags_to_array($newtags) ) );

    # Update search indexes
    update_indexes( $tank_id, $oldtags, $newtags );

    # Update the ZSET
    update_metadata_field( $tank_id, "tags", $newtags );

    invalidate_cache();
    return ( 1, "" );
}

# get_tank_unified_tags(tank_id, archive_tags_list)
#   Computes the unified tagset for a tank.
#   Parameters:
#     $tank_id - The tank ID
#     $archive_tags_list - Optional arrayref of archive tag strings. If not provided, fetches from DB.
#   Returns: Hashref with:
#     own_tags     => arrayref of tank's own tags (trimmed)
#     imputed_tags => arrayref of archive tags, deduplicated, excluding own_tags
sub get_tank_unified_tags ( $tank_id, $archive_tags_list = undef ) {
    my $redis = LANraragi::Model::Config->get_redis;

    # Get tank's own tags from ZSET score -2
    my @raw_tank_tags = $redis->zrangebyscore( $tank_id, -2, -2 );
    my $tank_tags_str = "";
    if ( @raw_tank_tags && $raw_tank_tags[0] =~ /^tags_(.*)/ ) {
        $tank_tags_str = redis_decode($1) // "";
    }

    # Parse and trim tank's own tags
    my @own_tags = split_tags_to_array($tank_tags_str);

    # Get archive tags if not provided
    if ( !defined $archive_tags_list ) {
        my @archives = $redis->zrangebyscore( $tank_id, 1, "+inf" );
        $archive_tags_list = [];
        foreach my $arc_id (@archives) {
            if ( $redis->hexists( $arc_id, "tags" ) ) {
                push @$archive_tags_list, redis_decode( $redis->hget( $arc_id, "tags" ) );
            }
        }
    }

    $redis->quit;

    # Build set of own tags for deduplication (case-insensitive)
    my %own_tags_lc = map { lc($_) => 1 } @own_tags;

    # Track date-type tags for coalescing (date_added and timestamp)
    my %own_date_tags;
    my %max_imputed_dates;

    # Check if tank has its own date_added or timestamp tags
    foreach my $t (@own_tags) {
        if ( $t =~ /^(date_added|timestamp):(\d+)$/i ) {
            $own_date_tags{ lc($1) } = 1;
        }
    }

    # Parse archive tags, deduplicate, exclude own_tags
    my %seen;
    my @imputed_tags;
    foreach my $tags_str (@$archive_tags_list) {
        next unless defined $tags_str && $tags_str ne "";
        foreach my $t ( split( /,/, $tags_str ) ) {
            $t = trim($t);
            next if $t eq "";
            my $t_lc = lc($t);

            # Handle date-type tags specially - track max value per namespace
            if ( $t =~ /^(date_added|timestamp):(\d+)$/i ) {
                my ( $ns, $val ) = ( lc($1), $2 );
                if ( !exists $max_imputed_dates{$ns} || $val > $max_imputed_dates{$ns}{value} ) {
                    $max_imputed_dates{$ns} = { value => $val, tag => $t };
                }
                next;
            }

            next if $seen{$t_lc}++;
            next if $own_tags_lc{$t_lc};
            push @imputed_tags, $t;
        }
    }

    # Add winning imputed date tags (only if tank has no own tag for that namespace)
    foreach my $ns ( keys %max_imputed_dates ) {
        if ( !exists $own_date_tags{$ns} ) {
            push @imputed_tags, $max_imputed_dates{$ns}{tag};
        }
    }

    return { own_tags => \@own_tags, imputed_tags => \@imputed_tags };
}

# update_tank_imputed_indexes(tank_id, removed_tags)
#   Updates INDEX_* sets for a tank's unified tagset (its own + tags from contained archives).
#   Does NOT update LRR_STATS (tags from existing archives shouldn't be duped).
#
#   $removed_tags - optional arrayref of tags that might need removal
#                   (from removed archive or changed archive tags)
sub update_tank_imputed_indexes ( $tank_id, $removed_tags = undef ) {

    my $logger = get_logger( "Tankoubon", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis_search;

    # Get current unified tagset (own + imputed)
    my $unified  = get_tank_unified_tags($tank_id);
    my @all_tags = ( @{ $unified->{own_tags} }, @{ $unified->{imputed_tags} } );

    $redis->multi;

    # Add tank to all current tag indexes 
    foreach my $tag (@all_tags) {
        my $encoded_tag = redis_encode( lc($tag) );
        $redis->sadd( "INDEX_" . $encoded_tag, $tank_id );
    }

    # If removed_tags provided, srem tank from indexes for tags no longer in unified tagset
    if ( $removed_tags && @$removed_tags ) {
        my %current = map { lc($_) => 1 } @all_tags;

        foreach my $tag (@$removed_tags) {
            next unless defined $tag && $tag ne "";
            my $tag_lc = lc($tag);
            unless ( $current{$tag_lc} ) {
                my $encoded_tag = redis_encode($tag_lc);
                $redis->srem( "INDEX_" . $encoded_tag, $tank_id );
            }
        }
    }

    $redis->exec;
    $redis->quit;

    $logger->debug("Updated imputed tag indexes for $tank_id");
}

# translate_global_page(tank_id, global_page)
#   Translates a page number to (archive_id, local_page).
#   Returns an empty list if the page is out of range or archives have no pagecount data.
sub translate_global_page ( $tank_id, $global_page ) {

    my $redis    = LANraragi::Model::Config->get_redis;
    my @archives = $redis->zrangebyscore( $tank_id, 1, "+inf" );

    my $offset = 0;
    foreach my $arc_id (@archives) {
        my $pagecount = $redis->hget( $arc_id, "pagecount" ) || 0;
        if ( $global_page <= $offset + $pagecount ) {
            $redis->quit;
            return ( $arc_id, $global_page - $offset );
        }
        $offset += $pagecount;
    }

    $redis->quit;
    return ();
}

# serve_tankoubon_thumbnail(self, tank_id)
#   Serve the cover thumbnail for a Tankoubon.
#   If the thumbnail doesn't exist and no_fallback=true, queues a Minion job and returns 202.
#   Otherwise falls back to the placeholder image.
sub serve_tankoubon_thumbnail {

    my ( $self, $tank_id ) = @_;

    my $no_fallback = $self->req->param('no_fallback');
    $no_fallback = ( $no_fallback && $no_fallback eq "true" ) || "0";

    my $thumbdir        = LANraragi::Model::Config->get_thumbdir;
    my $use_jxl         = LANraragi::Model::Config->get_jxlthumbpages;
    my $format          = $use_jxl         ? 'jxl' : 'jpg';
    my $fallback_format = $format eq 'jxl' ? 'jpg' : 'jxl';

    my $thumbbase      = "$thumbdir/TA/$tank_id";
    my $thumbname      = "$thumbbase.$format";
    my $fallback_thumb = "$thumbbase.$fallback_format";

    unless ( -e $thumbname ) {
        $thumbname = $fallback_thumb;
    }

    unless ( -e $thumbname ) {

        if ($no_fallback) {

            my $job_id = $self->minion->enqueue( tank_thumbnail_task => [ $thumbdir, $tank_id ] => { priority => 0, attempts => 3 } );
            $self->render(
                openapi => {
                    operation => "serve_tankoubon_thumbnail",
                    success   => 1,
                    job       => $job_id
                },
                status => 202
            );
        } else {
            $self->render_file( filepath => "./public/img/noThumb.png" );
        }
        return;
    }

    $self->render_file( filepath => $thumbname );
}

# update_tankoubon_thumbnail(self, tank_id)
#   Set the tankoubon cover thumbnail from a global page number spanning all archives in the tank.
sub update_tankoubon_thumbnail {

    my ( $self, $tank_id ) = @_;

    my $page = $self->req->param('page');
    $page = 1 unless $page;

    my $logger   = get_logger( "Tankoubon", "lanraragi" );
    my $thumbdir = LANraragi::Model::Config->get_thumbdir;
    my $use_jxl  = LANraragi::Model::Config->get_jxlthumbpages;
    my $format   = $use_jxl ? 'jxl' : 'jpg';

    my ( $arc_id, $local_page ) = translate_global_page( $tank_id, $page );

    unless ( defined $arc_id ) {
        render_api_response( $self, "update_tankoubon_thumbnail", "Page $page is out of range for this tankoubon." );
        return;
    }

    my $newthumb = "";
    my $tank_thumb = "$thumbdir/TA/$tank_id.$format";

    no warnings 'experimental::try';
    try {
        $newthumb = extract_thumbnail( $thumbdir, $arc_id, $local_page, 0, 1 );

        # Copy extracted page thumbnail to the tank's cover thumbnail path
        make_path("$thumbdir/TA") unless -d "$thumbdir/TA";
        copy( $newthumb, $tank_thumb );

    } catch ($e) {
        render_api_response( $self, "update_tankoubon_thumbnail", $e );
        return;
    }

    unless ($tank_thumb) {
        render_api_response( $self, "update_tankoubon_thumbnail", "Thumbnail not generated." );
        return;
    }

    $logger->debug("Set tank $tank_id thumbnail from archive $arc_id page $local_page");

    $self->render(
        openapi => {
            operation     => "update_tankoubon_thumbnail",
            new_thumbnail => $tank_thumb,
            success       => 1
        }
    );
}

# tank_has_archive_in_set(tank_id, set_ref)
#   Check if a tankoubon has any archive that exists in the given set.
#   Used for filters like "newonly" where we want tanks containing new archives.
#   $set_ref is a hashref with archive IDs as keys.
sub tank_has_archive_in_set ( $tank_id, $set_ref ) {
    my $redis    = LANraragi::Model::Config->get_redis;
    my @archives = $redis->zrangebyscore( $tank_id, 1, "+inf" );
    $redis->quit;
    for my $arc (@archives) {
        return 1 if exists $set_ref->{$arc};
    }
    return 0;
}

1;
