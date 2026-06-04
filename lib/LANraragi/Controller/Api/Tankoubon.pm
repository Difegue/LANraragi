package LANraragi::Controller::Api::Tankoubon;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Encode;
use Scalar::Util qw(looks_like_number);

use LANraragi::Model::Archive;
use LANraragi::Model::Config;
use LANraragi::Model::Tankoubon;
use LANraragi::Utils::Generic qw(render_api_response exec_with_lock);
use LANraragi::Utils::Login   qw(is_logged_in_api);

sub get_tankoubon_list {

    my $self = shift->openapi->valid_input or return;
    my $req  = $self->req;

    my $page = $req->param('page');

    my ( $total, $filtered, @rgs ) = LANraragi::Model::Tankoubon::get_tankoubon_list($page);
    $self->render( openapi => { result => \@rgs, total => $total, filtered => $filtered } );

}

sub get_tankoubon {

    my $self    = shift->openapi->valid_input or return;
    my $tank_id = $self->stash('id');

    my %tankoubon = LANraragi::Model::Tankoubon::get_tankoubon($tank_id);

    unless (%tankoubon) {
        render_api_response( $self, "get_tankoubon", "The given tankoubon does not exist." );
        return;
    }

    $self->render( openapi => \%tankoubon );
}

sub get_tankoubon_full {

    my $self    = shift->openapi->valid_input or return;
    my $tank_id = $self->stash('id');
    my $req     = $self->req;

    my $fulldata = ( $self->req->param('include_full_data') && $self->req->param('include_full_data') ne "false" ) ? 1 : 0;
    my $page     = $req->param('page') // -1;

    my ( $total, $filtered, %tankoubon );
    if ( $page < 0 ) {
        %tankoubon = LANraragi::Model::Tankoubon::get_tankoubon( $tank_id, $fulldata, $page );
        $total    = scalar @{ $tankoubon{archives} // [] };
        $filtered = $total;
    } else {
        ( $total, $filtered, %tankoubon ) = LANraragi::Model::Tankoubon::get_tankoubon( $tank_id, $fulldata, $page );
    }

    unless (%tankoubon) {
        render_api_response( $self, "get_tankoubon", "The given tankoubon does not exist." );
        return;
    }

    $self->render( openapi => { result => \%tankoubon, total => $total, filtered => $filtered } );
}

sub create_tankoubon {

    my $self   = shift->openapi->valid_input or return;
    my $name   = $self->req->param('name')   || "";
    my $tankid = $self->req->param('tankid') || "";

    if ( $name eq "" ) {
        render_api_response( $self, "create_tankoubon", "Tankoubon name not specified." );
        return;
    }

    my $created_id = LANraragi::Model::Tankoubon::create_tankoubon( $name, $tankid );
    $self->render(
        openapi => {
            operation    => "create_tankoubon",
            tankoubon_id => $created_id,
            success      => 1
        }
    );

}

sub delete_tankoubon {

    my $self   = shift->openapi->valid_input or return;
    my $tankid = $self->stash('id');

    return unless exec_with_lock(
        $self,
        "tankoubon-write:$tankid",
        "delete_tankoubon",
        $tankid,
        sub {
            my $result = LANraragi::Model::Tankoubon::delete_tankoubon($tankid);

            if ($result) {
                render_api_response( $self, "delete_tankoubon" );
            } else {
                render_api_response( $self, "delete_tankoubon", "The given tankoubon does not exist." );
            }
        }
    );
}

sub update_tankoubon {

    my $self   = shift->openapi->valid_input or return;
    my $tankid = $self->stash('id');
    my $data   = $self->req->json;

    return unless exec_with_lock(
        $self,
        "tankoubon-write:$tankid",
        "update_tankoubon",
        $tankid,
        sub {
            my ( $result, $err ) = LANraragi::Model::Tankoubon::update_tankoubon( $tankid, $data );

            if ($result) {
                my %tankoubon      = LANraragi::Model::Tankoubon::get_tankoubon($tankid);
                my $successMessage = "Updated tankoubon \"$tankoubon{name}\"!";

                render_api_response( $self, "update_tankoubon", undef, $successMessage );

                # Queue thumbnail regeneration if the archive list changed
                if ( defined $data->{"archives"} ) {
                    my $thumbdir = LANraragi::Model::Config->get_thumbdir;
                    $self->minion->enqueue( tank_thumbnail_task => [ $thumbdir, $tankid ] => { priority => 0, attempts => 3 } );
                }
            } else {
                render_api_response( $self, "update_tankoubon", $err );
            }
        }
    );
}

sub add_to_tankoubon {

    my $self   = shift->openapi->valid_input or return;
    my $tankid = $self->stash('id');
    my $arcid  = $self->stash('archive');

    return unless exec_with_lock(
        $self,
        "tankoubon-write:$tankid",
        "add_to_tankoubon",
        $tankid,
        sub {
            my ( $result, $err ) = LANraragi::Model::Tankoubon::add_to_tankoubon( $tankid, $arcid );

            if ($result) {
                my $successMessage = "Added $arcid to tankoubon $tankid!";
                my %tankoubon      = LANraragi::Model::Tankoubon::get_tankoubon($tankid);
                my $title          = LANraragi::Model::Archive::get_title($arcid);

                if ( %tankoubon && defined($title) ) {
                    $successMessage = "Added \"$title\" to tankoubon \"$tankoubon{name}\"!";
                }

                render_api_response( $self, "add_to_tankoubon", undef, $successMessage );
            } else {
                render_api_response( $self, "add_to_tankoubon", $err );
            }
        }
    );
}

sub remove_from_tankoubon {

    my $self   = shift->openapi->valid_input or return;
    my $tankid = $self->stash('id');
    my $arcid  = $self->stash('archive');

    return unless exec_with_lock(
        $self,
        "tankoubon-write:$tankid",
        "remove_from_tankoubon",
        $tankid,
        sub {
            my ( $result, $err ) = LANraragi::Model::Tankoubon::remove_from_tankoubon( $tankid, $arcid );

            if ($result) {
                my $successMessage = "Removed $arcid from tankoubon $tankid!";
                my %tankoubon      = LANraragi::Model::Tankoubon::get_tankoubon($tankid);
                my $title          = LANraragi::Model::Archive::get_title($arcid);

                if ( %tankoubon && defined($title) ) {
                    $successMessage = "Removed \"$title\" from tankoubon \"$tankoubon{name}\"!";
                }

                render_api_response( $self, "remove_from_tankoubon", undef, $successMessage );

                # Queue thumbnail regeneration for the tankoubon if we removed the first archive
                # (This technically messes up custom user thumbnails if they set one up, but we don't have a way to differentiate at the moment)
                if ( $result == 1 ) {
                    my $thumbdir = LANraragi::Model::Config->get_thumbdir;
                    $self->minion->enqueue( tank_thumbnail_task => [ $thumbdir, $tankid ] => { priority => 0, attempts => 3 } );
                }
            } else {
                render_api_response( $self, "remove_from_tankoubon", $err );
            }
        }
    );
}

sub serve_tankoubon_thumbnail {
    my $self    = shift->openapi->valid_input or return;
    my $tank_id = $self->stash('id');
    LANraragi::Model::Tankoubon::serve_tankoubon_thumbnail( $self, $tank_id );
}

sub update_tankoubon_thumbnail {
    my $self    = shift->openapi->valid_input or return;
    my $tank_id = $self->stash('id');
    LANraragi::Model::Tankoubon::update_tankoubon_thumbnail( $self, $tank_id );
}

sub update_tank_progress {

    my $self    = shift->openapi->valid_input or return;
    my $tank_id = $self->stash('id');
    my $page    = $self->stash('page') || 0;
    my $time    = time();

    # Enforce authentication if authprogress is enabled
    if ( LANraragi::Model::Config->enable_authprogress ) {
        unless ( is_logged_in_api($self) ) {
            return $self->render(
                openapi => {
                    operation => "update_tank_progress",
                    error     => "This operation requires authentication.",
                    success   => 0
                },
                status => 401
            );
        }
    }

    if ( LANraragi::Model::Config->enable_localprogress && !LANraragi::Model::Config->enable_authprogress ) {
        render_api_response( $self, "update_tank_progress", "Server-side Progress Tracking is disabled on this instance." );
        return;
    }

    unless ( looks_like_number($page) && $page > 0 ) {
        render_api_response( $self, "update_tank_progress", "Invalid progress value." );
        return;
    }

    my ( $result, $err ) = LANraragi::Model::Tankoubon::update_tank_progress( $tank_id, $page );

    if ($result) {
        $self->render(
            openapi => {
                operation    => "update_tank_progress",
                id           => $tank_id,
                page         => int($page),
                lastreadtime => $time,
                success      => 1
            }
        );
    } else {
        render_api_response( $self, "update_tank_progress", $err );
    }
}

sub get_tankoubons_file {

    my $self  = shift->openapi->valid_input or return;
    my $arcid = $self->stash('id');

    if ( $arcid eq "" ) {
        render_api_response( $self, "get_tankoubons_file", "Archive not specified." );
        return;
    }

    my @tanks = LANraragi::Model::Tankoubon::get_tankoubons_containing_archive($arcid);

    $self->render(
        openapi => {
            operation  => "find_arc_tankoubons",
            tankoubons => \@tanks,
            success    => 1
        }
    );
}

1;

