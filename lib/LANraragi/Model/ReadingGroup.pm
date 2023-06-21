package LANraragi::Model::ReadingGroup;

use strict;
use warnings;
use utf8;

use Redis;
use Mojo::JSON qw(decode_json encode_json);

use LANraragi::Utils::Database qw(redis_encode redis_decode invalidate_cache get_archive_json_multi);
use LANraragi::Utils::Logging qw(get_logger);

# get_reading_group_list()
#   Returns a list of all the reading group objects.
sub get_reading_group_list {

    my $redis = LANraragi::Model::Config->get_redis;

    # Categories are represented by RG_[timestamp] in DB. Can't wait for 2038!
    my @rgs = $redis->keys('RG_??????????');

    # Jam categories into an array of hashes
    my @result;
    foreach my $key (@rgs) {
        my %data = get_reading_group($key);
        push( @result, \%data );
    }

    # # Only get the first X keys
    # my $keysperpage = LANraragi::Model::Config->get_pagesize;

    # # Return total keys and the filtered ones
    # my $end = min( $start + $keysperpage - 1, $#filtered );
    # return ( $total, $#filtered + 1, @filtered[ $start .. $end ] );

    return @result;
}

# create_reading_group(name, existing_id)
#   Create a Reading Group.
#   If an existing Reading Group ID is supplied, said Reading Group will be updated with the given parameters.
#   Returns the ID of the created/updated Reading Group.
sub create_reading_group {

    my ( $name, $rg_id ) = @_;
    my $redis = LANraragi::Model::Config->get_redis;

    # Set all fields of the group object
    unless ( length($rg_id) ) {
        $rg_id = "RG_" . time();

        my $isnewkey = 0;
        until ($isnewkey) {

            # Check if the group ID exists, move timestamp further if it does
            if ( $redis->exists($rg_id) ) {
                $rg_id = "RG_" . ( time() + 1 );
            } else {
                $isnewkey = 1;
            }
        }

        # Default values for new group
        $redis->hset( $rg_id, "archives",  "[]" );
        $redis->hset( $rg_id, "name",   redis_encode($name) );
    }

    $redis->quit;

    return $rg_id;
}

# get_reading_group(id, decoded)
#   Returns the Reading Group matching the given id.
#   Returns undef if the id doesn't exist.
sub get_reading_group {

    #my $rg_id = $_[0];
    my ($rg_id,$decoded) = @_;
    my $logger = get_logger( "Reading Groups", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis;

    if ( $rg_id eq "" ) {
        $logger->debug("No Reading Group ID provided.");
        return ();
    }

    unless ( length($rg_id) == 13 && $redis->exists($rg_id) ) {
        $logger->warn("$rg_id doesn't exist in the database!");
        return ();
    }

    my %readinggroup = $redis->hgetall($rg_id);

    # redis-decode the name, and the search terms if they exist
    ( $_ = redis_decode($_) ) for ( $readinggroup{name});

    if ($decoded) {
        my @data = get_archive_json_multi(@{ decode_json($readinggroup{archives}) });
        eval {$readinggroup{archives} = \@data}
    } else {
        eval { $readinggroup{archives} = decode_json( $readinggroup{archives} ) };
    }

    if ($@) {
        $logger->error("Couldn't deserialize contents of readinggroup $rg_id! $@");
    }

    # Add the key as well
    $readinggroup{id} = $rg_id;

    return %readinggroup;
}

# delete_reading_group(id)
#   Deletes the reading group with the given ID.
#   Returns 0 if the given ID isn't a reading group ID, 1 otherwise
sub delete_reading_group {

    my $rg_id = $_[0];
    my $logger = get_logger( "Reading Groups", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis;

    if ( length($rg_id) != 13 ) {

        # Probably not a readinggroup ID
        $logger->error("$rg_id is not a readinggroup ID, doing nothing.");
        $redis->quit;
        return 0;
    }

    if ( $redis->exists($rg_id) ) {
        $redis->del($rg_id);
        $redis->quit;
        return 1;
    } else {
        $logger->warn("$rg_id doesn't exist in the database!");
        $redis->quit;
        return 1;
    }
}

# add_to_reading_group(categoryid, arcid)
#   Adds the given archive ID to the given reading group.
#   Returns 1 on success, 0 on failure alongside an error message.
sub update_archive_list {

    my ( $rg_id, $data ) = @_;
    my $logger = get_logger( "Reading Groups", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis;
    my $err    = "";
    my @rg_archives = @{$data->{"archives"}};

    if ( $redis->exists($rg_id) ) {

        foreach my $key (@rg_archives) {
            $logger->error($key);
            unless ( $redis->exists($key) ) {
                $err = "$key does not exist in the database.";
                $logger->error($err);
                $redis->quit;
                return ( 0, $err );
            }
        }

        $redis->hset( $rg_id, "archives", encode_json( \@rg_archives ) );

        invalidate_cache();
        $redis->quit;
        return ( 1, $err );
    }

    $err = "$rg_id doesn't exist in the database!";
    $logger->warn($err);
    $redis->quit;
    return ( 0, $err );
}

# add_to_readinggroup(readinggroupid, arcid)
#   Adds the given archive ID to the given readinggroup.
#   Returns 1 on success, 0 on failure alongside an error message.
sub add_to_readinggroup {

    my ( $rg_id, $arc_id ) = @_;
    my $logger = get_logger( "ReadingGroup", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis;
    my $err    = "";

    if ( $redis->exists($rg_id) ) {

        unless ( $redis->exists($arc_id) ) {
            $err = "$arc_id does not exist in the database.";
            $logger->error($err);
            $redis->quit;
            return ( 0, $err );
        }

        my @rg_archives;
        my $archives_from_redis = $redis->hget( $rg_id, "archives" );
        eval { @rg_archives = @{ decode_json($archives_from_redis) } };

        if ($@) {
            $err = "Couldn't deserialize archives in DB for $rg_id! Redis returned the following junk data: $archives_from_redis";
            $logger->error($err);
            $redis->quit;
            return ( 0, $err );
        }

        if ( "@rg_archives" =~ m/$arc_id/ ) {
            $err = "$arc_id already present in category $rg_id, doing nothing.";
            $logger->warn($err);
            $redis->quit;
            return ( 1, $err );
        }

        push @rg_archives, $arc_id;
        $redis->hset( $rg_id, "archives", encode_json( \@rg_archives ) );

        $redis->quit;
        return ( 1, $err );
    }

    $err = "$rg_id doesn't exist in the database!";
    $logger->warn($err);
    $redis->quit;
    return ( 0, $err );
}

1;