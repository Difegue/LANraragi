package LANraragi::Controller::Api::Readinggroup;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Encode;

use LANraragi::Model::ReadingGroup;
use LANraragi::Utils::Generic qw(render_api_response);

sub get_reading_group_list {

    my $self = shift;
    my @rgs = LANraragi::Model::ReadingGroup->get_reading_group_list;
    $self->render( json => \@rgs );

}

sub get_reading_group {

    my $self     = shift;
    my $rg_id    = $self->stash('id');
    my $req  = $self->req;

    my $decoded       = $req->param('decoded');
    $decoded //= 0;
    my %reading_group = LANraragi::Model::ReadingGroup::get_reading_group($rg_id, $decoded);

    unless (%reading_group) {
        render_api_response( $self, "get_reading_group", "The given reading group does not exist." );
        return;
    }

    $self->render( json => \%reading_group );
}

sub create_reading_group {

    my $self   = shift;
    my $name   = $self->req->param('name') || "";

    if ( $name eq "" ) {
        render_api_response( $self, "create_reading_group", "ReadingGroup name not specified." );
        return;
    }

    my $created_id = LANraragi::Model::ReadingGroup::create_reading_group( $name, "" );
    $self->render(
        json => {
            operation   => "create_reading_group",
            reading_group_id => $created_id,
            success     => 1
        }
    );

}

sub delete_reading_group {

    my $self  = shift;
    my $rgid = $self->stash('id');

    my $result = LANraragi::Model::ReadingGroup::delete_reading_group($rgid);

    if ($result) {
        render_api_response( $self, "delete_reading_group" );
    } else {
        render_api_response( $self, "delete_reading_group", "The given reading group does not exist." );
    }
}

sub update_archive_list {

    my $self  = shift;
    my $rgid = $self->stash('id');
    my $data = $self->req->json;

    my ( $result, $err ) = LANraragi::Model::ReadingGroup::update_archive_list( $rgid, $data );

    if ($result) {
        my %readinggroup   = LANraragi::Model::ReadingGroup::get_reading_group($rgid);
        my $successMessage = "Updated archives of reading group \"$readinggroup{name}\"!";

        render_api_response( $self, "update_archive_list", undef, $successMessage );
    } else {
        render_api_response( $self, "update_archive_list", $err );
    }
}

sub add_to_readinggroup {

    my $self  = shift;
    my $rgid = $self->stash('id');
    my $arcid = $self->stash('archive');

    my ( $result, $err ) = LANraragi::Model::ReadingGroup::add_to_readinggroup( $rgid, $arcid );

    if ($result) {
        my $successMessage = "Added $arcid to Reading Group $rgid!";

        render_api_response( $self, "add_to_readinggroup", undef, $successMessage );
    } else {
        render_api_response( $self, "add_to_readinggroup", $err );
    }
}

1;

