package LANraragi::Controller::Api::Category;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Encode;
use Mojo::JSON qw(decode_json encode_json from_json);

use LANraragi::Model::Category;
use LANraragi::Utils::Generic qw(render_api_response);

sub get_category_list {

    my $self = shift;
    my @cats = LANraragi::Model::Category::get_category_list;
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
        render_api_response( $self, "add_to_category" );
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
        render_api_response( $self, "remove_from_category" );
    } else {
        render_api_response( $self, "remove_from_category", $err );
    }
}

1;

