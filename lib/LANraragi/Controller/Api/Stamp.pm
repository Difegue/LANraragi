package LANraragi::Controller::Api::Stamp;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Encode;

use LANraragi::Model::Stamp;
use LANraragi::Utils::Generic qw(render_api_response exec_with_lock);


sub get_stamp {

    my $self    = shift->openapi->valid_input or return;
    my $id      = $self->stash('id');
    my $stamp_id    = $self->req->param('stamp_id');

    my ( $stamp, $err ) = LANraragi::Model::Stamp::get_stamp($id, $stamp_id);

    unless (%$stamp) {
        render_api_response($self, "get_stamp", "The given stamp does not exist.");
        return;
    }

    $self->render( openapi => { result => $stamp } );
}

sub get_stamps_by_page {

    my $self    = shift->openapi->valid_input or return;
    my $id      = $self->stash('id');
    my $index    = $self->stash('index');

    my ( $stamps, $err ) = LANraragi::Model::Stamp::get_stamps_by_page($id, $index);

    $self->render( openapi => { result => $stamps } );
}

sub get_stamped_pages {

    my $self    = shift->openapi->valid_input or return;
    my $id      = $self->stash('id');

    my ( $indexes, $err ) = LANraragi::Model::Stamp::get_stamped_pages( $id );

    $self->render( openapi => { result => $indexes } );
}

sub add_stamp {

    my $self    = shift->openapi->valid_input or return;
    my $id      = $self->stash('id');
    my $index    = $self->stash('index');
    my $content = $self->req->param('content') || "";
    my $position = $self->req->param('position') || "";

    unless ( defined $index ) {
        return render_api_response( $self, "add_stamp", "Archive page." );
    }

    my ( $created_id, $err ) = LANraragi::Model::Stamp::add_stamp( $id, $index, $content, $position );

    if ($created_id) {
        $self->render(
            openapi => {
                operation    => "add_stamp",
                stamp_id => $created_id,
                success      => 1
            }
        );
    } else {
        $self->render(
            openapi => {
                operation    => "add_stamp",
                stamp_id => $created_id,
                success      => 0
            }
        );
    }

}

sub update_stamp {

    my $self        = shift->openapi->valid_input or return;
    my $id          = $self->stash('id');
    my $stamp_id    = $self->req->param('stamp_id');
    my $position    = $self->req->param('position') || undef;
    my $content     = $self->req->param('content') || undef;

    return unless exec_with_lock(
        $self,
        "stamp-write:$stamp_id",
        "update_stamp",
        $stamp_id,
        sub {
            my ( $result, $err ) = LANraragi::Model::Stamp::update_stamp( $id, $stamp_id, $content, $position );

            if ($result) {
                my %stamp      = LANraragi::Model::Stamp::get_stamp( $id, $stamp_id );
                my $successMessage = "Updated stamp \"$stamp_id\"!";

                render_api_response( $self, "update_stamp", undef, $successMessage );
            } else {
                render_api_response( $self, "update_stamp", $err );
            }
        }
    );

}

sub delete_stamp {

    my $self   = shift->openapi->valid_input or return;
    my $id = $self->stash('id');
    my $stamp_id = $self->req->param('stamp_id');

    return unless exec_with_lock(
        $self,
        "stamp-write:$stamp_id",
        "delete_stamp",
        $stamp_id,
        sub {
            my ( $result, $err ) = LANraragi::Model::Stamp::remove_stamp($id, $stamp_id);

            if ($result) {
                render_api_response( $self, "delete_stamp" );
            } else {
                render_api_response( $self, "delete_stamp", "The given stamp does not exist." );
            }
        }
    );
}

1;

