package LANraragi::Model::Tankoubon;

use feature qw(signatures);
no warnings 'experimental::signatures';

use experimental "try";

use strict;
use warnings;
use utf8;

use Redis;
use Mojo::JSON qw(decode_json encode_json);
use List::Util qw(min);

use LANraragi::Utils::Database qw(redis_encode redis_decode invalidate_cache get_archive_json_multi);
use LANraragi::Utils::Logging qw(get_logger);

# get_tankoubon_list(page)
#   Returns a list of all the Tankoubon objects.
# NEEDS PAGINATION
sub get_tankoubon_list($page=0) {

    my $redis = LANraragi::Model::Config->get_redis;
    my $logger = get_logger( "Tankoubon", "lanraragi" );

    # Tankoubons are represented by RG_[timestamp] in DB. Can't wait for 2038!
    my @tanks = $redis->keys('TANK_??????????');  

    # Jam tanks into an array of hashes
    my @result;
    foreach my $key (sort @tanks) {
        my %data = get_tankoubon($key);
        push( @result, \%data );
    }

    # # Only get the first X keys
    my $keysperpage = LANraragi::Model::Config->get_pagesize;

    # Return total keys and the filtered ones
    my $total = $#tanks+1;
    my $start = $page*$keysperpage;
    my $end = min( $start + $keysperpage - 1, $#result );
    return ( $total, $#result + 1, @result[ $start .. $end ] );

    #return @result;
}

# create_tankoubon(name, existing_id)
#   Create a Tankoubon.
#   If an existing Tankoubon ID is supplied, said Tankoubon will be updated with the given parameters.
#   Returns the ID of the created/updated Tankoubon.
sub create_tankoubon( $name, $tank_id ) {

    my $redis = LANraragi::Model::Config->get_redis;

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
    }

    # Default values for new group
    # Score 0 will be reserved for the name of the tank
    $redis->zadd( $tank_id, 0, redis_encode($name)); 

    $redis->quit;

    return $tank_id;
}

# get_tankoubon(tankoubonid, decoded, page)
#   Returns the Tankoubon matching the given id.
#   Returns undef if the id doesn't exist.
sub get_tankoubon($tank_id,$decoded=0,$page=0) {

    my $logger = get_logger( "Tankoubon", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis;
    my $keysperpage = LANraragi::Model::Config->get_pagesize;

    if ( $tank_id eq "" ) {
        $logger->debug("No Tankoubon ID provided.");
        return ();
    }

    unless ( length($tank_id) == 15 && $redis->exists($tank_id) ) {
        $logger->warn("$tank_id doesn't exist in the database!");
        return ();
    }

    # Declare some needed variables
    my %tank;
    my @archives; 
    my @limit = split(' ', "LIMIT " . ($keysperpage * $page) . " $keysperpage");

    # Get name
    my @name = $redis->zrangebyscore($tank_id, 0, 0, qw{LIMIT 0 1});
    $tank{name} = redis_decode($name[0]);

    # Grab page
    my %tankoubon = $redis->zrangebyscore($tank_id, 1, "+inf", "WITHSCORES", @limit);

    # Sort and add IDs to archives array
    foreach my $i (sort { $tankoubon{$a} <=> $tankoubon{$b} } keys %tankoubon) {
        push( @archives, $i );
    }

    # Verify if we require decoded files or just IDs
    if ($decoded) {
        my @data = get_archive_json_multi(@archives);
        eval {$tank{archives} = \@data}
    } else {
        eval { $tank{archives} = \@archives };
    }

    if ($@) {
        $logger->error("Couldn't deserialize contents of Tankoubon $tank_id! $@");
    }

    # Add the key as well
    $tank{id} = $tank_id;

    return %tank;
}

# delete_tankoubon(tankoubonid)
#   Deletes the Tankoubon with the given ID.
#   Returns 0 if the given ID isn't a Tankoubon ID, 1 otherwise
sub delete_tankoubon($tank_id) {

    my $logger = get_logger( "Tankoubon", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis;

    if ( length($tank_id) != 15 ) {

        # Probably not a Tankoubon ID
        $logger->error("$tank_id is not a Tankoubon ID, doing nothing.");
        $redis->quit;
        return 0;
    }

    if ( $redis->exists($tank_id) ) {
        $redis->del($tank_id);
        $redis->quit;
        return 1;
    } else {
        $logger->warn("$tank_id doesn't exist in the database!");
        $redis->quit;
        return 1;
    }
}

# update_archive_list(tankoubonid, arcid)
#   Updates the archives list in a Tankoubon.
#   Returns 1 on success, 0 on failure alongside an error message.
sub update_archive_list($tank_id, $data) {

    my $logger = get_logger( "Tankoubon", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis;
    my $err    = "";
    my @tank_archives = @{$data->{"archives"}};

    if ( $redis->exists($tank_id) ) {

        foreach my $key (@tank_archives) {
            unless ( $redis->exists($key) ) {
                $err = "$key does not exist in the database.";
                $logger->error($err);
                $redis->quit;
                return ( 0, $err );
            }
        }

        my @origs = $redis->zrangebyscore($tank_id, 1, "+inf");
        my @diff = array_difference(\@tank_archives, \@origs);
        my @update;

        # Remove the ones not in the order
        if (@diff) {
            $redis->zrem($tank_id, @diff);
        }

        # Prepare zadd array
        my $len = @tank_archives;

        for (my $i = 0; $i < $len; $i = $i + 1) {
            push @update, $i+1;
            push @update, $tank_archives[$i];
        }

        # Update
        $redis->zadd( $tank_id, @update);

        $redis->quit;
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
sub add_to_tankoubon( $tank_id, $arc_id ) {

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

        if ($redis->zscore($tank_id, $arc_id)) {
            $err = "$arc_id already present in category $tank_id, doing nothing.";
            $logger->warn($err);
            $redis->quit;
            return ( 1, $err );
        }

        my $score = $redis->zcard($tank_id);

        $redis->zadd($tank_id, $score, $arc_id);

        $redis->quit;
        return ( 1, $err );
    }

    $err = "$tank_id doesn't exist in the database!";
    $logger->warn($err);
    $redis->quit;
    return ( 0, $err );
}


# UTILS - Probably better to move to another file
sub array_difference($array1, $array2) {
    my %seen;
    my @difference;
    
    # Add all elements from array1 to the hash
    $seen{$_} = 1 for @$array1;
    
    # Check elements in array2 and add the ones not seen in array1 to the difference array
    foreach my $element (@$array2) {
        push @difference, $element unless $seen{$element};
    }
    
    return @difference;
}

1;