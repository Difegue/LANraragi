package LANraragi::Model::Stamp;

use v5.36;
use experimental 'try';

use strict;
use warnings;
use utf8;

use Redis;

use LANraragi::Utils::Logging    qw(get_logger);
use LANraragi::Utils::Redis      qw(redis_encode);


# get_stamp(id, stamp_id)
#   Gets the requested stamp.
#   Returns the stamp object.
sub get_stamp {
    my ( $id, $stamp_id ) = @_;

    my $redis  = LANraragi::Model::Config->get_redis;
    my $logger = get_logger( "Stamps", "lanraragi" );
    my $faves_id = "FAVES_" . $id;
    my $err     = "";

    if ( $redis->hexists($faves_id => $stamp_id) ) {
        my $content = $redis->hget($faves_id => $stamp_id);
        my %stamp = convert_stamp_to_object($stamp_id, $content);

        return ( \%stamp, $err );
    }

    return ();
}

# get_stamps_by_page(id)
#   Gets the list of pages that have at least one stamp.
#   Returns an array of stamps objects.
# TODO Pagination
sub get_stamps_by_page {
    my ( $id, $index ) = @_;

    my $redis  = LANraragi::Model::Config->get_redis;
    my $logger = get_logger( "Stamps", "lanraragi" );
    my $faves_id = "FAVES_" . $id;
    my $err     = "";

    my $data = get_stamps_data($redis, $faves_id, $index);
    my @stamps = convert_stamps_to_object(%$data);

    return ( \@stamps, $err );
}

# get_stamped_pages(id)
#   Gets the list of pages that have at least one stamp.
#   Returns an array of page numbers.
sub get_stamped_pages {
	my ( $id ) = @_;

	my $redis  = LANraragi::Model::Config->get_redis;
    my $logger = get_logger( "Stamps", "lanraragi" );
    my $faves_id = "FAVES_" . $id;
    my $err    = "";

    my $fields = $redis->hkeys($faves_id);

    my %indexes;

    foreach my $field (@$fields) {
        # Extract the page number
        my ($index) = split(/:/, $field, 2);
        $indexes{$index} = 1;
    }

    my @keys = keys %indexes;

    return ( \@keys, $err );
}

# add_stamp(id, key, content, position)
#   Add the stamp to the page.
#   Returns the stamp key.
sub add_stamp {
	my ( $id, $index, $content, $position ) = @_;

    my $redis  = LANraragi::Model::Config->get_redis;
    my $logger = get_logger( "Stamps", "lanraragi" );
    my $faves_id = "FAVES_" . $id;
    my $err    = "";

    unless ( $redis->exists($id) ) {
        $err = "$id does not exist in the database.";
        $logger->error($err);
        $redis->quit;
        return ( 0, $err );
    }

    $content = remove_separator($content, "|");
    $position = remove_separator($position, "|");

    # page:timestamp
    my $key = $index . ":" . time();

    $redis->hset( $faves_id, $key, redis_encode("${position}|${content}") );

    $redis->quit;

    return ( $key, $err );
}

# update_stamp(id, key, content, position)
#   Removes the stamp from the page.
#   Returns 1 on success, 0 on failure alongside an error message.
sub update_stamp {
    my ( $id, $key, $content, $position ) = @_;

    my $logger = get_logger( "Stamps", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis;
    my $err    = "";
    my $faves_id = "FAVES_" . $id;

    my $current = $redis->hget($faves_id => $key);
    my @c_content = split(/\|/, $current);

    if ( defined $position ) {
        $position = remove_separator($position, "|");
    } else {
        $position = $c_content[0]
    }

    if ( defined $content ) {
        $content = remove_separator($content, "|");
    } else {
        $content = $c_content[1]
    }

    if ( $redis->exists($faves_id) ) {
        $redis->hset( $faves_id, $key, redis_encode("${position}|${content}") );
        $redis->quit;
        return ( 1, $err );
    }

    $err = "$faves_id doesn't exist in the database!";
    $logger->warn($err);
    $redis->quit;
    return ( 0, $err );
}

# remove_stamp(id, key)
#   Removes the stamp from the page.
#   Returns 1 on success, 0 on failure alongside an error message.
sub remove_stamp {
	my ( $id, $key ) = @_;

    my $logger = get_logger( "Stamps", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis;
    my $err    = "";
    my $faves_id = "FAVES_" . $id;

    if ( $redis->exists($faves_id) ) {
        $redis->hdel($faves_id, $key);
        $redis->quit;
        return ( 1, $err );
    }

    $err = "$faves_id doesn't exist in the database!";
    $logger->warn($err);
    $redis->quit;
    return ( 0, $err );
}

# Replaces | for " " in the given string
sub remove_separator {
    my ($string, $char) = @_;
    
    # Escape special regex characters in $char
    my $escaped_char = quotemeta($char);
    
    # Replace all occurrences with a space
    $string =~ s/$escaped_char/ /g;
    
    return $string;
}

# Extracts the stamps related to a page using HSCAN
sub get_stamps_data {
    my ($redis, $faves_id, $index) = @_;

    my $cursor = 0;
    my %result;
    my $pattern = "$index:*";
    my $logger = get_logger( "Stamps", "lanraragi" );

    # Use a Do While until the cursor goes back to 0
    do {
        my ($next_cursor, $data) = $redis->hscan($faves_id, $cursor, 'MATCH', $pattern);

        # Append data to the dictionary
        for (my $i = 0; $i < @$data; $i += 2) {
            my $field = $data->[$i];
            my $value = $data->[$i + 1];

            $result{$field} = $value;
        }

        $cursor = $next_cursor;

    } while ($cursor != 0);

    return \%result;
}

# Gets the number of stamps in the page
sub size_stamps_by_page {
    my ($redis, $faves_id, $index) = @_;

    my $data = get_stamps_data($redis, $faves_id, $index);

    return scalar keys %$data;
}

# Converts a stamp register to object
sub convert_stamp_to_object {
    my ( $stamp_id, $content ) = @_;

    # Separate the string and classify the fields
    my @x = split(/\|/, $content);
    my %stamp = (
        id       => $stamp_id,
        position => $x[0],
        content  => $x[1],
    );

    return %stamp;
}

# Converts an array of stamp registers to an array ob objects
sub convert_stamps_to_object {
    my (%stamps_raw) = @_;

    my @stamps;

    # Convert stamp registers to objects
    foreach my $i (keys %stamps_raw) {
        my %stamp = convert_stamp_to_object($i, $stamps_raw{$i});
        push @stamps, \%stamp;  
    }

    return @stamps;
}

1;