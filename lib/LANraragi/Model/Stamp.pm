package LANraragi::Model::Stamp;

use v5.36;
use experimental 'try';

use strict;
use warnings;
use utf8;

use Redis;
use Time::HiRes qw(time);
use Mojo::JSON qw(decode_json encode_json);

use LANraragi::Utils::Logging   qw(get_logger);
use LANraragi::Utils::Redis     qw(redis_encode redis_decode);
use LANraragi::Utils::Generic   qw(filter_hash_by_keys);


# get_stamp(stamp_id)
#   Gets the requested stamp.
#   Returns the stamp object.
sub get_stamp {
    my ( $stamp_id ) = @_;

    my $redis  = LANraragi::Model::Config->get_redis;
    my $logger = get_logger( "Stamps", "lanraragi" );
    my $err     = "";

    if ( $stamp_id eq "" ) {
        $logger->debug("No stamp ID provided.");
        return ();
    }

    unless ( $redis->exists($stamp_id) ) {
        $logger->warn("$stamp_id doesn't exist in the database!");
        return ();
    }

    my %stamp = convert_stamp_to_object( $redis, $stamp_id );

    $redis->quit;

    return ( \%stamp, $err );
}

# get_stamps_by_page(id, page)
#   Gets the list of pages that have at least one stamp.
#   Returns an array of stamps objects.
# TODO Pagination
sub get_stamps_by_page {
    my ( $archive_id, $index ) = @_;

    my $redis  = LANraragi::Model::Config->get_redis;
    my $logger = get_logger( "Stamps", "lanraragi" );
    my $err     = "";
    my @stamps;

    unless ( $redis->exists($archive_id) ) {
        $err = "$archive_id does not exist in the database.";
        $logger->error($err);
        $redis->quit;
        return ( 0, $err );
    }

    if ( $redis->hexists($archive_id => "stamps") ) {
        my @stamp_ids = decode_json($redis->hget( $archive_id, "stamps" ));
        my @filtered_stamps = filter_stamps_by_page(@stamp_ids, $index);
        @stamps = convert_stamps_to_object($redis, @filtered_stamps);
    }

    $redis->quit;

    return ( \@stamps, $err );
}

# get_stamped_pages(id)
#   Gets the list of pages that have at least one stamp.
#   Returns an array of page numbers.
sub get_stamped_pages {
	my ( $archive_id ) = @_;

	my $redis  = LANraragi::Model::Config->get_redis;
    my $logger = get_logger( "Stamps", "lanraragi" );
    my $err    = "";
    my @keys;

    unless ( $redis->exists($archive_id) ) {
        $err = "$archive_id does not exist in the database.";
        $logger->error($err);
        $redis->quit;
        return ( 0, $err );
    }

    if ( $redis->hexists($archive_id => "stamps") ) {
        my %indexes;
        my $stamps    = $redis->hget( $archive_id, "stamps" );
        $stamps = deserialize_stamp_list($stamps);

        if (!defined $stamps) {
            $redis->quit();
            $err = "There was a problem deserializing the stamps";
            return ( 0, $err );
        }

        my @stamps = @$stamps;

        foreach my $stamp (@stamps) {
            # Extract the page number
            my (undef, $index, undef) = split(/_/, $stamp, 3);
            $indexes{$index} = 1;
        }

        @keys = keys %indexes;
    }

    $redis->quit();

    return ( \@keys, $err );
}

# add_stamp(archive_id, page, content, position)
#   Add the stamp to the page.
#   Returns the stamp key.
sub add_stamp {
	my ( $archive_id, $index, $content, $position ) = @_;

    my $redis  = LANraragi::Model::Config->get_redis;
    my $logger = get_logger( "Stamps", "lanraragi" );
    my $err    = "";

    unless ( $redis->exists($archive_id) ) {
        $err = "$archive_id does not exist in the database.";
        $logger->error($err);
        $redis->quit;
        return ( 0, $err );
    }

    # Page and creation date are saved in the key.
    # This one uses Time::HiRes to get timestamp in milliseconds.
    my $key = "STAMPS_" . $index . "_" . int(time() * 1000);

    # Probably unnecessary since this is in ms.
    my $isnewkey = 0;
    until ($isnewkey) {
        if ( $redis->exists($key) ) {
            $key = "STAMPS_" . $index . "_" . int(time() * 1000 + 1);
        } else {
            $isnewkey = 1;
        }
    }

    $redis->hset( $key, "content", redis_encode($content) );
    $redis->hset( $key, "position", redis_encode($position) );
    # This one is probably redundant, but I'll add it for the purpose of reverse searches, maybe for cache build up.
    $redis->hset( $key, "archive_id", redis_encode($archive_id) );

    # Add to archive
    my $stamps    = $redis->hget( $archive_id, "stamps" );
    my @stamps;

    no warnings 'experimental::try';
    try {
        eval { @stamps = @{ decode_json($stamps) } };
        if ($@) {
            $err = "Couldn't deserialize stamps in DB for $archive_id! Redis returned the following junk data: $stamps";
            $redis->del($key);
            $logger->error($err);
            $redis->quit;
            return ( 0, $err );
        }
        push @stamps, $key;
        $stamps          = encode_json(\@stamps);
    } catch ($e) {
        $logger->warn(
            "Error while updating Stamps: $e -- Will overwrite with a Stamps containing the new data. (This is normal if this ID had no Stamps yet.)"
        );
        @stamps          = [];
        push @stamps, $key;
        $stamps          = encode_json(\@stamps);
    }
    $redis->hset( $archive_id, "stamps", $stamps );

    $redis->quit();

    return ( $key, $err );
}

# update_stamp(id, content, position)
#   Removes the stamp from the page.
#   Returns 1 on success, 0 on failure alongside an error message.
sub update_stamp {
    my ( $stamp_id, $content, $position ) = @_;

    my $logger = get_logger( "Stamps", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis;
    my $err    = "";

    if ( $redis->exists($stamp_id) ) {
        if ( defined $position ) {
            $redis->hset( $stamp_id, "position", redis_encode($position) )
        }

        if ( defined $content ) {
            $redis->hset( $stamp_id, "content", redis_encode($content) )
        }

        $redis->quit();
        return ( 1, $err );
    }

    $err = "$stamp_id doesn't exist in the database!";
    $logger->warn($err);
    $redis->quit();
    return ( 0, $err );
}

# remove_stamp(key)
#   Removes the stamp from the page.
#   Returns 1 on success, 0 on failure alongside an error message.
sub remove_stamp {
	my ( $key ) = @_;

    my $logger = get_logger( "Stamps", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis;
    my $err    = "";

    if ( $redis->exists($key) ) {
        # Remove key from archive.
        # This should not throw an error, since the stamp should have been linked to the archive at creation.
        my $archive_id      = $redis->hget( $key, "archive_id" );
        my $stamps          = $redis->hget( $archive_id, "stamps" );
        $stamps             = deserialize_stamp_list($stamps);
        my @stamps          = remove_stampid_from_list($stamps, $key);
        $redis->hset( $archive_id, "stamps", encode_json(\@stamps) );

        $redis->del($key);

        $redis->quit();
        return ( 1, $err );
    }

    $err = "$key doesn't exist in the database!";
    $logger->warn($err);
    $redis->quit();
    return ( 0, $err );
}

# Converts a stamp register to object
sub convert_stamp_to_object {
    my ( $redis, $stamp_id ) = @_;

    my @allowed_keys = ( 'content', 'position' );
    my %stamp = $redis->hgetall($stamp_id);
    ( $_ = redis_decode($_) ) for ( $stamp{content}, $stamp{position} );
    %stamp = filter_hash_by_keys( \@allowed_keys, %stamp );
    $stamp{id} = $stamp_id;

    return %stamp;
}

# Converts an array of stamp registers to an array ob objects
sub convert_stamps_to_object {
    my ( $redis, @stamp_ids) = @_;

    my @stamps;

    # Convert stamp registers to objects
    foreach my $i (@stamp_ids) {
        my %stamp = convert_stamp_to_object($redis, $i);
        push @stamps, \%stamp;  
    }

    return @stamps;
}

sub remove_stampid_from_list {
    my ($stamps, $stamp) = @_;

    my @new_stamps = grep { $_ ne $stamp } @$stamps;
    
    return @new_stamps;
}

# Returns stamps whose page in STAMPS_<page>_<ts> matches.
sub filter_stamps_by_page {
    my ($stamps, $page) = @_;
    
    my @filtered = grep {
        my (undef, $index, undef) = split(/_/, $_, 3);
        defined $index && $index == $page;
    } @$stamps;
    
    return @filtered;
}

# Convert JSON string to array.
sub deserialize_stamp_list {
    my ($stamps) = @_;

    my $decoded;
    eval {
        $decoded = decode_json($stamps);
        die "There was a problem serializing stamps" unless ref($decoded) eq 'ARRAY';
    };

    if ($@) {
        return undef;
    }

    return $decoded;
}

1;