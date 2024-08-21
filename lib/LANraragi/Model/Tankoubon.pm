package LANraragi::Model::Tankoubon;

use feature qw(signatures fc);
no warnings 'experimental::signatures';

use strict;
use warnings;
use utf8;

use Redis;
use Mojo::JSON qw(decode_json encode_json);
use List::Util qw(min);

use LANraragi::Utils::Database  qw(redis_encode redis_decode invalidate_cache get_archive_json_multi get_tankoubons_by_file);
use LANraragi::Utils::Generic   qw(array_difference filter_hash_by_keys);
use LANraragi::Utils::Logging   qw(get_logger);

my %TANK_METADATA = (
        "name", 0,
        "summary", -1,
        "tags", -2
    );

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

        if ($redis->exists($tank_id)) {
            $redis->zrem( $tank_id, $n );
        }
    }

    # Default values for new group
    # Score 0 will be reserved for the name of the tank
    my $tank_title = redis_encode($name);

    # Add the tank name to LRR_TITLES so it shows up in tagless searches when tank grouping is enabled. 
    $redis_search->zadd( "LRR_TITLES", 0, "$tank_title\0$tank_id" );

    # Init metadata
    $redis->zadd( $tank_id, $TANK_METADATA{"name"}, redis_encode("name_${tank_title}") );
    $redis->zadd( $tank_id, $TANK_METADATA{"summary"}, "summary_" );
    $redis->zadd( $tank_id, $TANK_METADATA{"tags"}, "tags_" );

    $redis->quit;
    $redis_search->quit;

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
    my @allowed_keys = ('name', 'summary', 'tags', 'archives', 'full_data', 'id');
    my @archives;
    my @limit = split( ' ', "LIMIT " . ( $keysperpage * $page ) . " $keysperpage" );
    my ( %tank, $error ) = fetch_metadata_fields($tank_id);

    my %tankoubon;

    # Grab page
    if ( $page < 0 ) {
        %tankoubon = $redis->zrangebyscore( $tank_id, 1, "+inf", "WITHSCORES" );
    } else {
        %tankoubon = $redis->zrangebyscore( $tank_id, 1, "+inf", "WITHSCORES", @limit );
    }

    # Sort and add IDs to archives array
    foreach my $i ( sort { $tankoubon{$a} cmp $tankoubon{$b} } keys %tankoubon ) {
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

    %tank = filter_hash_by_keys(\@allowed_keys, %tank);

    my $total = $redis->zcard($tank_id) - 1;

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
        $redis->del($tank_id);
        # The ID will remain in LRR_TITLES until the next stats compute, but this'll prevent it from appearing in search.
        $redis_search->srem( "LRR_TANKGROUPED",  $tank_id ); 

        $redis->quit;
        $redis_search->quit;
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

    return ( $result, $err);
}

# update_metadata(tankoubonid, data)
#   Updates the metadata in the Tankoubon.
#   Returns 1 on success, 0 on failure alongside an error message.
sub update_metadata( $tank_id, $data ) {

    if ( not defined $data->{"metadata"} ) {
        return ( 1, "" );
    }

    my $logger          = get_logger( "Tankoubon", "lanraragi" );
    my $redis           = LANraragi::Model::Config->get_redis;
    my $err             = "";
    my $name            = $data->{"metadata"}->{"name"} || undef;
    my $summary         = $data->{"metadata"}->{"summary"} || undef;
    my $tags            = $data->{"metadata"}->{"tags"} || undef;

    if ( $redis->exists($tank_id) ) {
        if ( defined $name ) {
            update_metadata_field( $tank_id, "name", $name );
        }

        if ( defined $summary ) {
            update_metadata_field( $tank_id, "summary", $summary );
        }

        if ( defined $tags ) {
            update_metadata_field( $tank_id, "tags", $tags );
        }

        $redis->quit;
        return ( 1, $err );
    }

    $redis->quit;

    $err = "$tank_id doesn't exist in the database!";
    $logger->warn($err);
    $redis->quit;
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

        $redis->multi;
        $redis_search->multi;

        # Remove the ones not in the order
        if (@diff) {
            $redis->zrem( $tank_id, @diff );

            # Make removed archives visible in search again unless other tanks contain them
            foreach my $arc_id (@diff) {
                unless (get_tankoubons_containing_archive($arc_id)) {
                    $redis_search->sadd( "LRR_TANKGROUPED",  $arc_id );
                }
            }
        }

        # Prepare zadd array
        my $len = @tank_archives;

        if ( $len == 0 ) {
            $redis_search->srem( "LRR_TANKGROUPED", $tank_id );
        } else {
            $redis_search->sadd( "LRR_TANKGROUPED", $tank_id );
        }

        for ( my $i = 0; $i < $len; $i = $i + 1 ) {
            push @update, $i + 1;
            push @update, $tank_archives[$i];
            # Remove the ID if present, as it's been absorbed into the tank
            $redis_search->srem( "LRR_TANKGROUPED",  $tank_archives[$i] );
        }

        # Update
        if ( $len > 0 ) { # Move this line and the previous for inside the previous else?
            $redis->zadd( $tank_id, @update );
        }
        $redis->exec;
        $redis_search->exec;

        $redis->quit;
        $redis_search->quit;

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
        $redis->srem( "LRR_TANKGROUPED",  $arc_id );
        $redis->sadd( "LRR_TANKGROUPED",  $tank_id ); # Set elements are unique so no problem if the tank is already added here
        $redis->quit;
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
#   Returns 1 on success, 0 on failure alongside an error message.
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
            return ( 1, $err );
        }

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

        if ($redis->zcard($tank_id) == 1) {
            # No elements in tank, remove it from search
            $redis->srem( "LRR_TANKGROUPED", $tank_id );
        }

        $redis->quit;

        # Removing an archive from a tank might have it show up in main search again
        unless (get_tankoubons_containing_archive($arcid)) {
            $redis = LANraragi::Model::Config->get_redis_search;
            $redis->sadd( "LRR_TANKGROUPED", $arcid );
            $redis->quit;
        }
        invalidate_cache();

        return ( 1, $err );
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
    my $redis        = LANraragi::Model::Config->get_redis;
    my $logger       = get_logger( "Tankoubon", "lanraragi" );
    my $err          = "";

    $redis->zremrangebyscore( $tank_id, $TANK_METADATA{$field}, $TANK_METADATA{$field} );
    $redis->zadd( $tank_id, $TANK_METADATA{$field}, redis_encode("${field}_${value}") );

    return ( 1, $err );
}

sub fetch_metadata_fields ( $tank_id ) {
    my $redis        = LANraragi::Model::Config->get_redis;
    my $err          = "";

    # Fetch from DB
    my @keys = sort { $TANK_METADATA{$a} <=> $TANK_METADATA{$b} } keys(%TANK_METADATA);
    my @raw_values = $redis->zrangebyscore( $tank_id, $TANK_METADATA{$keys[0]}, 0 );

    # Clean the data
    my %metadata;
    foreach my $raw_value (@raw_values) {
        foreach my $key (@keys) {
            if ($raw_value =~ /^$key\_/) {
                my $clean_value = redis_decode($raw_value) || "";
                $clean_value =~ s/^$key\_//;
                $metadata{$key} = $clean_value;
                last;  # Exit the loop once the key is matched
            }
        }
    }

    return ( %metadata, $err );
}


1;
