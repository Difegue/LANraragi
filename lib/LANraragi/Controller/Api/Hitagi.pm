package LANraragi::Controller::Api::Hitagi;
use Mojo::Base 'Mojolicious::Controller';
use Storable;
use Config;

use LANraragi::Utils::Generic qw(render_api_response);
use LANraragi::Utils::Hitagi;

sub hitagi_available {
    my $self = shift->openapi->valid_input or return;

    $self->render(
        openapi => {
            operation     => "hitagi_available",
            success       => 1,
            is_available  => LANraragi::Utils::Hitagi::available() ? 1 : 0,
        }
    );
}

sub hitagi_pid {
    my $self   = shift->openapi->valid_input or return;
    my $target = $self->stash( "target" );

    if ( LANraragi::Utils::Hitagi::available() ) {
        my $pid = LANraragi::Utils::Hitagi::pid( $target );

        $self->render(
            openapi => {
                operation => "hitagi_pid",
                success   => 1,
                pid       => $pid
            }
        );
    } else {
        $self->render(
            openapi => {
                operation      => "hitagi_pid",
                error          => "Hitagi unavailable",
                success        => 0,
                successMessage => ""
            },
            status => 501
        );
    }
}

sub hitagi_restart {
    my $self   = shift->openapi->valid_input or return;
    my $target = $self->stash( "target" );

    if ( LANraragi::Utils::Hitagi::available() ) {
        my $pid = LANraragi::Utils::Hitagi::restart( $target );

        $self->render(
            openapi => {
                operation => "hitagi_restart",
                success   => 1,
                pid       => $pid
            }
        );
    } else {
        $self->render(
            openapi => {
                operation      => "hitagi_restart",
                error          => "Hitagi unavailable",
                success        => 0,
                successMessage => ""
            },
            status => 501
        );
    }
}

sub hitagi_stop {
    my $self   = shift->openapi->valid_input or return;
    my $target = $self->stash( "target" );

    if ( LANraragi::Utils::Hitagi::available() ) {
        my $result = LANraragi::Utils::Hitagi::stop( $target );

        $self->render(
            openapi => {
                operation => "hitagi_stop",
                success   => $result,
            }
        );
    } else {
        $self->render(
            openapi => {
                operation      => "hitagi_stop",
                error          => "Hitagi unavailable",
                success        => 0,
                successMessage => ""
            },
            status => 501
        );
    }
}

1;
