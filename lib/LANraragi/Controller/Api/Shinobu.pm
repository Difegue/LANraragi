package LANraragi::Controller::Api::Shinobu;
use Mojo::Base 'Mojolicious::Controller';
use Storable;

use LANraragi::Utils::Generic qw(start_shinobu render_api_response);
use LANraragi::Utils::TempFolder qw(get_temp);

sub shinobu_status {
    my $self    = shift;
    my $shinobu = ${ retrieve( get_temp . "/shinobu.pid" ) };

    $self->render(
        json => {
            operation => "shinobu_status",
            success   => 1,
            is_alive  => $shinobu->poll(),
            pid       => $shinobu->pid
        }
    );
}

sub reset_filemap {
    my $self = shift;

    # This is a shinobu endpoint even though we're deleting stuff in redis
    # since we'll have to restart shinobu anyway to proc filemap re-creation.

    my $redis = $self->LRR_CONF->get_redis;
    $redis->del("LRR_FILEMAP");

    my $shinobu = ${ retrieve( get_temp . "/shinobu.pid" ) };

    #commit sudoku
    $shinobu->kill();

    # Create a new Process, automatically stored in TEMP_FOLDER/shinobu.pid
    my $proc = start_shinobu($self);

    $self->render(
        json => {
            operation => "shinobu_rescan",
            success   => $proc->poll(),
            new_pid   => $proc->pid
        }
    );
}

sub stop_shinobu {
    my $self    = shift;
    my $shinobu = ${ retrieve( get_temp . "/shinobu.pid" ) };

    #commit sudoku
    $shinobu->kill();
    render_api_response( $self, "shinobu_stop" );
}

sub restart_shinobu {
    my $self    = shift;
    my $shinobu = ${ retrieve( get_temp . "/shinobu.pid" ) };

    #commit sudoku
    $shinobu->kill();

    # Create a new Process, automatically stored in TEMP_FOLDER/shinobu.pid
    my $proc = start_shinobu($self);

    $self->render(
        json => {
            operation => "shinobu_restart",
            success   => $proc->poll(),
            new_pid   => $proc->pid
        }
    );
}

1;

