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

    my $name   = $self->req->param('name')   || $category{name};
    my $search = $self->req->param('search') || $category{search};
    my $pinned = ( $self->req->param('pinned') && $self->req->param('pinned') ne "false" ) ? 1 : 0;

    my $updated_id = LANraragi::Model::Category::create_category( $name, $search, $pinned, $catid );

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

    my $result = LANraragi::Model::Category::delete_category($catid);

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

    my ( $result, $err ) = LANraragi::Model::Category::add_to_category( $catid, $arcid );

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

    my ( $result, $err ) = LANraragi::Model::Category::remove_from_category( $catid, $arcid );

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

sub get_highlight_category {

    my $self = shift;
    my $catid = LANraragi::Model::Category::get_highlight_category();
    return $self->render(
        json => {
            operation   => "get_highlight_category",
            success     => 1,
            category_id => $catid
        }
    );

}

sub update_highlight_category {

    my $self = shift;
    my $catid = $self->stash('id');
    my ($status_code, $message);
    ($status_code, $catid, $message) = LANraragi::Model::Category::update_highlight_category($catid);
    unless ( $status_code == 200 ) {
        return $self->render(
            json => {
                operation   => "update_highlight_category",
                success     => 0,
                category_id => $catid,
                error       => $message
            },
            status => $status_code
        );
    }
    return $self->render(
        json => {
            operation   => "update_highlight_category",
            category_id => $catid,
            success     => 1
        },
        status => 200
    );

}

sub delete_highlight_category {

    my $self = shift;
    my $catid = LANraragi::Model::Category::delete_highlight_category();
    return $self->render(
        json => {
            operation   => "delete_highlight_category",
            category_id => $catid,
            success     => 1
        }
    );

}

1;

