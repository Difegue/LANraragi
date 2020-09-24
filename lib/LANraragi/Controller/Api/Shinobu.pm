package LANraragi::Controller::Api::Shinobu;
use Mojo::Base 'Mojolicious::Controller';
use Storable;

use LANraragi::Utils::Generic qw(start_shinobu render_api_response);

sub shinobu_status {
    my $self    = shift;
    my $shinobu = ${ retrieve("./script/shinobu.pid") };

    $self->render(
        json => {
            operation => "shinobu_status",
            success   => 1,
            is_alive  => $shinobu->poll(),
            pid       => $shinobu->pid
        }
    );
}

sub stop_shinobu {
    my $self    = shift;
    my $shinobu = ${ retrieve("./script/shinobu.pid") };

    #commit sudoku
    $shinobu->kill();
    render_api_response( $self, "shinobu_stop" );
}

sub restart_shinobu {
    my $self    = shift;
    my $shinobu = ${ retrieve("./script/shinobu.pid") };

    #commit sudoku
    $shinobu->kill();

    # Create a new Process, automatically stored in script/shinobu.pid
    my $proc = start_shinobu();

    $self->render(
        json => {
            operation => "shinobu_restart",
            success   => $proc->poll(),
            new_pid   => $proc->pid
        }
    );
}

1;

