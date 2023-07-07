package LANraragi::Controller::Api::Tankoubon;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Encode;

use LANraragi::Model::Tankoubon;
use LANraragi::Utils::Generic qw(render_api_response);

sub get_tankoubon_list {

    my $self = shift;
    my $req  = $self->req;

    my $page       = $req->param('page');
    $page //= 0;

    my ( $total, $filtered, @rgs ) = LANraragi::Model::Tankoubon::get_tankoubon_list($page);
    $self->render( json => {result => \@rgs, total => $total, filtered => $filtered} );

}

sub get_tankoubon {

    my $self     = shift;
    my $tank_id    = $self->stash('id');
    my $req  = $self->req;

    my $decoded       = $req->param('decoded');
    $decoded //= 0;

    my $page       = $req->param('page');
    $page //= 0;

    my %tankoubon = LANraragi::Model::Tankoubon::get_tankoubon($tank_id, $decoded, $page);

    unless (%tankoubon) {
        render_api_response( $self, "get_tankoubon", "The given tankoubon does not exist." );
        return;
    }

    $self->render( json => \%tankoubon );
}

sub create_tankoubon {

    my $self   = shift;
    my $name   = $self->req->param('name') || "";

    if ( $name eq "" ) {
        render_api_response( $self, "create_tankoubon", "Tankoubon name not specified." );
        return;
    }

    my $created_id = LANraragi::Model::Tankoubon::create_tankoubon( $name, "" );
    $self->render(
        json => {
            operation   => "create_tankoubon",
            tankoubon_id => $created_id,
            success     => 1
        }
    );

}

sub delete_tankoubon {

    my $self  = shift;
    my $tankid = $self->stash('id');

    my $result = LANraragi::Model::Tankoubon::delete_tankoubon($tankid);

    if ($result) {
        render_api_response( $self, "delete_tankoubon" );
    } else {
        render_api_response( $self, "delete_tankoubon", "The given tankoubon does not exist." );
    }
}

sub update_archive_list {

    my $self  = shift;
    my $tankid = $self->stash('id');
    my $data = $self->req->json;

    my ( $result, $err ) = LANraragi::Model::Tankoubon::update_archive_list( $tankid, $data );

    if ($result) {
        my %tankoubon   = LANraragi::Model::Tankoubon::get_tankoubon($tankid);
        my $successMessage = "Updated archives of tankoubon \"$tankoubon{name}\"!";

        render_api_response( $self, "update_archive_list", undef, $successMessage );
    } else {
        render_api_response( $self, "update_archive_list", $err );
    }
}

sub add_to_tankoubon {

    my $self  = shift;
    my $tankid = $self->stash('id');
    my $arcid = $self->stash('archive');

    my ( $result, $err ) = LANraragi::Model::Tankoubon::add_to_tankoubon( $tankid, $arcid );

    if ($result) {
        my $successMessage = "Added $arcid to tankoubon $tankid!";
        my %tankoubon   = LANraragi::Model::Tankoubon::get_tankoubon($tankid);
        my $title          = LANraragi::Model::Archive::get_title($arcid);

        if ( %tankoubon && defined($title) ) {
            $successMessage = "Added \"$title\" to tankoubon \"$tankoubon{name}\"!";
        }

        render_api_response( $self, "add_to_tankoubon", undef, $successMessage );
    } else {
        render_api_response( $self, "add_to_tankoubon", $err );
    }
}

sub get_tankoubons_file {

    my $self = shift;
    my $arcid   = $self->req->param('arcid') || "";

    if ( $arcid eq "" ) {
        render_api_response( $self, "get_tankoubons_file", "Archive no specified." );
        return;
    }

    my @tanks = LANraragi::Model::Tankoubon::get_tankoubons_file( $arcid );

    $self->render( json => \@tanks );
}

1;

