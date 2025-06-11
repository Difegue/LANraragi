package LANraragi::Controller::Api::Category;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Encode;

use LANraragi::Model::Category;
use LANraragi::Model::Config;
use LANraragi::Utils::Generic qw(render_api_response);

sub get_category_list {

    my $self = shift;
    my @cats = LANraragi::Model::Category->get_category_list;
    $self->render( json => \@cats );

}

sub get_category {

    my $self     = shift;
    my $catid    = $self->stash('id');
    my %category = LANraragi::Model::Category::get_category($catid);

    unless (%category) {
        render_api_response( $self, "get_category", "The given category does not exist." );
        return;
    }

    $self->render( json => \%category );
}

sub create_category {

    my $self   = shift;
    my $name   = $self->req->param('name') || "";
    my $search = $self->req->param('search') || "";
    my $pinned = ( $self->req->param('pinned') && $self->req->param('pinned') ne "false" ) ? 1 : 0;

    if ( $name eq "" ) {
        render_api_response( $self, "create_category", "Category name not specified." );
        return;
    }

    my $created_id = LANraragi::Model::Category::create_category( $name, $search, $pinned, "" );
    $self->render(
        json => {
            operation   => "create_category",
            category_id => $created_id,
            success     => 1
        }
    );

}

sub update_category {

    my $self     = shift;
    my $catid    = $self->stash('id');
    my %category = LANraragi::Model::Category::get_category($catid);

    unless (%category) {
        render_api_response( $self, "update_category", "The given category does not exist." );
        return;
    }

    # lock resource
    my $redis = LANraragi::Model::Config->get_redis;
    my $lock = $redis->setnx( "category-write:$catid", 1 );
    if ( !$lock ) {
        return $self->render(
            json => {
                operation => "update_category",
                success   => 0,
                error     => "Locked resource: $catid."
            },
            status => 423
        );
    }
    $redis->expire( "category-write:$catid", 10 );

    my $name   = $self->req->param('name')   || $category{name};
    my $search = $self->req->param('search') || $category{search};
    my $pinned = ( $self->req->param('pinned') && $self->req->param('pinned') ne "false" ) ? 1 : 0;

    my $updated_id = LANraragi::Model::Category::create_category( $name, $search, $pinned, $catid );
    $redis->del( "category-write:$catid" );
    $redis->quit();
    $self->render(
        json => {
            operation   => "update_category",
            category_id => $updated_id,
            success     => 1
        }
    );
}

sub delete_category {

    my $self  = shift;
    my $catid = $self->stash('id');

    # lock resource
    my $redis = LANraragi::Model::Config->get_redis;
    my $lock = $redis->setnx( "category-write:$catid", 1 );
    if ( !$lock ) {
        return $self->render(
            json => {
                operation => "delete_category",
                success   => 0,
                error     => "Locked resource: $catid."
            },
            status => 423
        );
    }
    $redis->expire( "category-write:$catid", 10 );

    my $result = LANraragi::Model::Category::delete_category($catid);
    $redis->del( "category-write:$catid" );
    $redis->quit();

    if ($result) {
        render_api_response( $self, "delete_category" );
    } else {
        render_api_response( $self, "delete_category", "The given category does not exist." );
    }
}

sub add_to_category {

    my $self  = shift;
    my $catid = $self->stash('id');
    my $arcid = $self->stash('archive');

    # lock resource
    my $redis = LANraragi::Model::Config->get_redis;
    my $lock = $redis->setnx( "category-write:$catid", 1 );
    if ( !$lock ) {
        return $self->render(
            json => {
                operation => "add_to_category",
                success   => 0,
                error     => "Locked resource: $catid."
            },
            status => 423
        );
    }
    $redis->expire( "category-write:$catid", 10 );

    my ( $result, $err ) = LANraragi::Model::Category::add_to_category( $catid, $arcid );
    $redis->del( "category-write:$catid" );
    $redis->quit();

    if ($result) {
        my $successMessage = "Added $arcid to Category $catid!";
        my %category       = LANraragi::Model::Category::get_category($catid);
        my $title          = LANraragi::Model::Archive::get_title($arcid);

        if ( %category && defined($title) ) {
            $successMessage = "Added \"$title\" to category \"$category{name}\"!";
        }

        render_api_response( $self, "add_to_category", undef, $successMessage );
    } else {
        render_api_response( $self, "add_to_category", $err );
    }
}

sub remove_from_category {

    my $self  = shift;
    my $catid = $self->stash('id');
    my $arcid = $self->stash('archive');

    # lock resource
    my $redis = LANraragi::Model::Config->get_redis;
    my $lock = $redis->setnx( "category-write:$catid", 1 );
    if ( !$lock ) {
        return $self->render(
            json => {
                operation => "remove_from_category",
                success   => 0,
                error     => "Locked resource: $catid."
            },
            status => 423
        );
    }
    $redis->expire( "category-write:$catid", 10 );
    my ( $result, $err ) = LANraragi::Model::Category::remove_from_category( $catid, $arcid );
    $redis->del( "category-write:$catid" );
    $redis->quit();

    if ($result) {
        my $successMessage = "Removed $arcid from Category $catid!";
        my %category       = LANraragi::Model::Category::get_category($catid);
        my $title          = LANraragi::Model::Archive::get_title($arcid);

        if ( %category && defined($title) ) {
            $successMessage = "Removed \"$title\" from category \"$category{name}\"!";
        }

        render_api_response( $self, "remove_from_category", undef, $successMessage );
    } else {
        render_api_response( $self, "remove_from_category", $err );
    }
}

sub get_bookmark_link {

    my $self = shift;
    my $catid = LANraragi::Model::Category::get_bookmark_link();
    return $self->render(
        json => {
            operation   => "get_bookmark_link",
            success     => 1,
            category_id => $catid
        }
    );

}

sub update_bookmark_link {

    my $self = shift;
    my $catid = $self->stash('id');
    my ($status_code, $message);
    ($status_code, $catid, $message) = LANraragi::Model::Category::update_bookmark_link($catid);
    unless ( $status_code == 200 ) {
        return $self->render(
            json => {
                operation   => "update_bookmark_link",
                success     => 0,
                category_id => $catid,
                error       => $message
            },
            status => $status_code
        );
    }
    return $self->render(
        json => {
            operation   => "update_bookmark_link",
            category_id => $catid,
            success     => 1
        },
        status => 200
    );

}

sub remove_bookmark_link {

    my $self = shift;
    my $catid = LANraragi::Model::Category::remove_bookmark_link();
    return $self->render(
        json => {
            operation   => "remove_bookmark_link",
            category_id => $catid,
            success     => 1
        }
    );

}

1;

