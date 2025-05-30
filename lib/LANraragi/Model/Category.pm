package LANraragi::Model::Category;

use strict;
use warnings;
use utf8;

use Redis;
use Mojo::JSON qw(decode_json encode_json);

use LANraragi::Utils::Database qw(redis_encode redis_decode invalidate_cache);
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
        my %data = get_category($key);
        push( @result, \%data );
    }

    return @result;
}

# get_static_category_list()
#   Returns a list of all the static category objects.
sub get_static_category_list() {

    my @categories = get_category_list;

    # Filter out dynamic categories
    @categories = grep { %$_{"search"} eq "" } @categories;
    return @categories;
}

# get_categories_containing_archive(id)
#   Returns a list of all the categories that contain the given archive.
sub get_categories_containing_archive {
    my $archive_id = shift;

    my $logger = get_logger( "Categories", "lanraragi" );
    $logger->debug("Finding categories containing $archive_id");

    my @categories = get_category_list();
    @categories = grep { %$_{"search"} eq "" } @categories;

    my @filteredcats = ();

    # Check if the id is in any categories
    for my $category (@categories) {
        my @archives = @{ $category->{"archives"} };

        if ( grep( /^$archive_id$/, @archives ) ) {
            $logger->debug( "$archive_id is in '" . $category->{name} . "'" );
            push @filteredcats, $category;
        }
    }

    return @filteredcats;
}

# get_category(id)
#   Returns the category matching the given id.
#   Returns undef if the id doesn't exist.
sub get_category {

    my $cat_id = $_[0];
    my $logger = get_logger( "Categories", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis;

    if ( $cat_id eq "" ) {
        $logger->debug("No category ID provided.");
        return ();
    }

    unless ( length($cat_id) == 14 && $redis->exists($cat_id) ) {
        $logger->warn("$cat_id doesn't exist in the database!");
        return ();
    }

    my %category = $redis->hgetall($cat_id);

    # redis-decode the name, and the search terms if they exist
    ( $_ = redis_decode($_) ) for ( $category{name}, $category{search} );

    # Deserialize the archives list w. mojo::json
    if ( $category{search} eq "" ) {

        eval { $category{archives} = decode_json( $category{archives} ) };

        if ($@) {
            $logger->error("Couldn't deserialize contents of category $cat_id! $@");
        }
    } else {

        # This is a dynamic category, so $data{archives} must be an empty array.
        # (We could leave it as-is, but it'd give inconsistent API results depending on your category type...)
        $category{archives} = decode_json("[]");
    }

    # Add the key as well
    $category{id} = $cat_id;

    return %category;
}

# create_category(name, favtag, pinned, existing_id)
#   Create a Category.
#   If the "favtag" argument is supplied, the category will be Dynamic.
#   Otherwise, it'll be Static.
#   If an existing category ID is supplied, said category will be updated with the given parameters.
#   Returns the ID of the created/updated Category.
sub create_category {

    my ( $name, $favtag, $pinned, $cat_id ) = @_;
    my $redis = LANraragi::Model::Config->get_redis;

    # Set all fields of the category object
    unless ( length($cat_id) ) {
        $cat_id = "SET_" . time();

        my $isnewkey = 0;
        until ($isnewkey) {

            # Check if the category ID exists, move timestamp further if it does
            if ( $redis->exists($cat_id) ) {
                $cat_id = "SET_" . ( time() + 1 );
            } else {
                $isnewkey = 1;
            }
        }

        # Default values for new category
        $redis->hset( $cat_id, "archives",  "[]" );
    }

    # Set/update name, pin status and favtag
    $redis->hset( $cat_id, "name",   redis_encode($name) );
    $redis->hset( $cat_id, "search", redis_encode($favtag) );
    $redis->hset( $cat_id, "pinned", $pinned );

    $redis->quit;

    return $cat_id;
}

# delete_category(id)
#   Deletes the category with the given ID.
#   If bookmark is linked to the category, remove the link.
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
        if ( $redis->hget('LRR_CONFIG', 'bookmark_link') eq $cat_id ) {
            $redis->hdel('LRR_CONFIG', 'bookmark_link');
            $logger->info("Removed link from bookmark to category $cat_id.");
        }
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
#   Only valid if the category is Static.
#   Returns 1 on success, 0 on failure alongside an error message.
sub add_to_category {

    my ( $cat_id, $arc_id ) = @_;
    my $logger = get_logger( "Categories", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis;
    my $err    = "";

    if ( $redis->exists($cat_id) ) {

        unless ( $redis->hget( $cat_id, "search" ) eq "" ) {
            $err = "$cat_id is a favorite search/dynamic category, can't add archives to it.";
            $logger->error($err);
            $redis->quit;
            return ( 0, $err );
        }

        unless ( $redis->exists($arc_id) ) {
            $err = "$arc_id does not exist in the database.";
            $logger->error($err);
            $redis->quit;
            return ( 0, $err );
        }

        my @cat_archives;
        my $archives_from_redis = $redis->hget( $cat_id, "archives" );
        eval { @cat_archives = @{ decode_json($archives_from_redis) } };

        if ($@) {
            $err = "Couldn't deserialize archives in DB for $cat_id! Redis returned the following junk data: $archives_from_redis";
            $logger->error($err);
            $redis->quit;
            return ( 0, $err );
        }

        if ( "@cat_archives" =~ m/$arc_id/ ) {
            $err = "$arc_id already present in category $cat_id, doing nothing.";
            $logger->warn($err);
            $redis->quit;
            return ( 1, $err );
        }

        push @cat_archives, $arc_id;
        $redis->hset( $cat_id, "archives", encode_json( \@cat_archives ) );

        invalidate_cache();
        $redis->quit;
        return ( 1, $err );
    }

    $err = "$cat_id doesn't exist in the database!";
    $logger->warn($err);
    $redis->quit;
    return ( 0, $err );
}

# remove_from_category(categoryid, arcid)
#   Removes the given archive ID from the given category.
#   Only valid if the category is an Archive Set.
#   Returns 1 on success, 0 on failure alongside an error message.
sub remove_from_category {

    my ( $cat_id, $arc_id ) = @_;
    my $logger = get_logger( "Categories", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis;
    my $err    = "";

    if ( $redis->exists($cat_id) ) {

        unless ( $redis->hget( $cat_id, "search" ) eq "" ) {
            $err = "$cat_id is a favorite search, it doesn't contain archives.";
            $logger->error($err);
            $redis->quit;
            return ( 0, $err );
        }

        my @cat_archives;
        my $archives_from_redis = $redis->hget( $cat_id, "archives" );
        eval { @cat_archives = @{ decode_json($archives_from_redis) } };

        if ($@) {
            $err = "Couldn't deserialize archives in DB for $cat_id! Redis returned the following junk data: $archives_from_redis";
            $logger->error($err);
            $redis->quit;
            return ( 0, $err );
        }

        # Remove occurences of $cat_id in @cat_archives w. grep and array reassignment
        my $index = 0;
        $index++ until $cat_archives[$index] eq $arc_id || $index == scalar @cat_archives;
        splice( @cat_archives, $index, 1 );

        $redis->hset( $cat_id, "archives", encode_json( \@cat_archives ) );

        invalidate_cache();
        $redis->quit;
        return ( 1, $err );
    }

    $err = "$cat_id doesn't exist in the database!";
    $logger->warn($err);
    $redis->quit;
    return 0;
}

# get_bookmark_link()
#   Gets the ID of the category that is linked to the bookmark button.
#   If no such ID exists, returns an empty string.
sub get_bookmark_link {

    my $redis = LANraragi::Model::Config->get_redis;
    my $catid = $redis->hget('LRR_CONFIG', 'bookmark_link') || "";
    $redis->quit();
    return $catid;

}

# update_bookmark_link(cat_id)
#   Links the bookmark button to a static category.
#   Returns an HTTP status code, category ID, and response message.
sub update_bookmark_link {

    my $cat_id = shift;
    unless (defined $cat_id && $cat_id =~ /^SET_\d{10}$/) {
        return (400, $cat_id, "Input category ID is invalid.");
    }
    my $redis = LANraragi::Model::Config->get_redis;
    unless ( $redis->exists($cat_id) ) {
        $redis->quit();
        return (404, $cat_id, "Category does not exist!");
    }
    unless ( $redis->hget( $cat_id, "search" ) eq "" ) {
        $redis->quit();
        return (400, $cat_id, "Cannot link bookmark to a dynamic category.");
    }
    $redis->hset('LRR_CONFIG', 'bookmark_link', $cat_id);
    $redis->quit();
    return (200, $cat_id, "success");

}

# remove_bookmark_link()
#   Unlinks the bookmark from its current category and returns the category ID.
sub remove_bookmark_link() {
    my $redis = LANraragi::Model::Config->get_redis;
    my $cat_id = $redis->hget('LRR_CONFIG', 'bookmark_link') || "";
    $redis->hdel('LRR_CONFIG', 'bookmark_link');
    $redis->quit();
    return $cat_id;
}

1;
