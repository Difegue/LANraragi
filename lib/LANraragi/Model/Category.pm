package LANraragi::Model::Category;

use strict;
use warnings;
use utf8;

use Redis;
use Encode;
use Mojo::JSON qw(decode_json encode_json);

use LANraragi::Utils::Generic qw(remove_newlines);
use LANraragi::Utils::Database qw(redis_decode invalidate_cache);
use LANraragi::Utils::Logging qw(get_logger);

# get_category_list()
#   Returns a list of all the category objects.
sub get_category_list {

    my $redis = LANraragi::Model::Config->get_redis;

    # Categories are represented by SET_[timestamp] in DB. Can't wait for 2038!
    my @cats = $redis->keys('SET_??????????');

    # Jam categories into an array of hashes
    my @result;
    foreach my $key (@cats) {
        my %data = $redis->hgetall($key);

        # redis-decode the name, and the search terms if they exist
        ( $_ = redis_decode($_) ) for ( $data{name}, $data{search} );
        push( @result, \%data );
    }

    return @result;
}

# create_category(name, favtag, existing_id)
#   Create a Category.
#   If the "favtag" argument is supplied, the category will be a Favorite Search.
#   Otherwise, it'll be an Archive Set.
#   If an existing category ID is supplied, said category will be updated with the given parameters.
#   Returns the ID of the created/updated Category.
sub create_category {

    my ( $name, $favtag, $cat_id ) = @_;
    my $redis = LANraragi::Model::Config->get_redis;

    unless ( length($cat_id) ) {
        $cat_id = "SET_" . time();
    }

    # Set all fields of the category object
    $redis->hset( $cat_id, "name",      encode_utf8($name) );
    $redis->hset( $cat_id, "search",    encode_utf8($favtag) );
    $redis->hset( $cat_id, "archives",  "[]" );
    $redis->hset( $cat_id, "last_used", time() );
    $redis->hset( $cat_id, "pinned",    "0" );
    $redis->quit;

    return $cat_id;
}

# delete_category(id)
#   Deletes the category with the given ID.
#   Returns 0 if the given ID isn't a category ID, 1 otherwise
sub delete_category {

    my $cat_id = $_[0];
    my $logger = get_logger( "Categories", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis;

    if ( length($cat_id) != 14 ) {

        # Probably not a category ID
        $logger->error("$cat_id is not a category ID, doing nothing.");
        $redis->quit;
        return 0;
    }

    if ( $redis->exists($cat_id) ) {
        $redis->del($cat_id);
        $redis->quit;
        return 1;
    } else {
        $logger->warn("$cat_id doesn't exist in the database!");
        $redis->quit;
        return 1;
    }
}

# add_to_category(categoryid, arcid)
#   Adds the given archive ID to the given category.
#   Only valid if the category is an Archive Set.
#   Returns 1 on success, 0 on failure.
sub add_to_category {

    my ( $cat_id, $arc_id ) = @_;
    my $logger = get_logger( "Categories", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis;

    if ( $redis->exists($cat_id) ) {

        unless ( $redis->hget( $cat_id, "search" ) eq "" ) {
            $logger->error("$cat_id is a favorite search, can't add archives to it.");
            $redis->quit;
            return 0;
        }

        my @cat_archives = decode_json( $redis->hget( $cat_id, "archives" ) );

        if ( "@cat_archives" =~ m/$arc_id/ ) {
            $logger->warn("$arc_id already present in category $cat_id, doing nothing.");
            $redis->quit;
            return 1;
        }

        push @cat_archives, $arc_id;
        $redis->hset( $cat_id, encode_json(@cat_archives) );
        invalidate_cache();
        $redis->quit;
        return 1;
    }

    $logger->warn("$cat_id doesn't exist in the database!");
    $redis->quit;
    return 0;
}

# remove_from_category(categoryid, arcid)
#   Removes the given archive ID from the given category.
#   Only valid if the category is an Archive Set.
sub remove_from_category {

    my ( $cat_id, $arc_id ) = @_;
    my $logger = get_logger( "Categories", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis;

    if ( $redis->exists($cat_id) ) {

        unless ( $redis->hget( $cat_id, "search" ) eq "" ) {
            $logger->error("$cat_id is a favorite search, it doesn't contain archives.");
            $redis->quit;
            return 0;
        }

        # Remove occurences of $cat_id in @cat_archives w. grep and array reassignment
        my @cat_archives = decode_json( $redis->hget( $cat_id, "archives" ) );
        @cat_archives = grep { !/$cat_id/ } @cat_archives;
        $redis->hset( $cat_id, encode_json(@cat_archives) );

        invalidate_cache();
        $redis->quit;
        return 1;
    }

    $logger->warn("$cat_id doesn't exist in the database!");
    $redis->quit;
    return 0;
}

1;
