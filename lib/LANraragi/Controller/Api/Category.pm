package LANraragi::Controller::Api::Category;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Encode;
use Mojo::JSON qw(decode_json encode_json from_json);

use LANraragi::Model::Category;
use LANraragi::Utils::Generic qw(success);

sub get_category_list {

    my $self = shift;
    my @cats = LANraragi::Model::Category::get_category_list;
    $self->render( json => \@cats );

}

sub create_category {

    my $self   = shift;
    my $name   = $self->req->param('name') || "";
    my $search = $self->req->param('search') || "";
    my $pinned = $self->req->param('pinned') ? 1 : 0;

    if ( $name eq "" ) {
        $self->render(
            json => {
                operation => "create_category",
                error     => "Category name not specified.",
                success   => 0
            },
            status => 400
        );
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
        $self->render(
            json => {
                operation => "update_category",
                error     => "The given category does not exist.",
                success   => 0
            },
            status => 400
        );
        return;
    }

    my $name   = $self->req->param('name')   || $category{name};
    my $search = $self->req->param('search') || $category{search};
    my $pinned = $self->req->param('pinned') ? 1 : 0;

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

    # TODO: refactor success so it can show an error depending on the return code
    success( $self, "delete_category" );
}

sub add_to_category {

    my $self  = shift;
    my $catid = $self->stash('id');
    my $arcid = $self->stash('archive');

    my $result = LANraragi::Model::Category::add_to_category( $catid, $arcid );

    # TODO: refactor success so it can show an error depending on the return code
    success( $self, "add_to_category" );
}

sub remove_from_category {

    my $self  = shift;
    my $catid = $self->stash('id');
    my $arcid = $self->stash('archive');

    my $result = LANraragi::Model::Category::remove_from_category( $catid, $arcid );

    # TODO: refactor success so it can show an error depending on the return code
    success( $self, "remove_from_category" );
}

1;

