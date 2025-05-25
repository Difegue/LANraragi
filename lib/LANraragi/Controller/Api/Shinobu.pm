package LANraragi::Controller::Api::Shinobu;
use Mojo::Base 'Mojolicious::Controller';
use Storable;
use Config;

use LANraragi::Utils::Generic qw(start_shinobu render_api_response);
use LANraragi::Utils::TempFolder qw(get_temp);

BEGIN {
    if ( $Config{osname} eq 'MSWin32') {
        require Win32::Process;
    }
}

sub shinobu_status {
    my $self    = shift;

    if ( $Config{osname} ne 'MSWin32') {
        my $shinobu = ${ retrieve( get_temp . "/shinobu.pid" ) };

        $self->render(
            json => {
                operation => "shinobu_status",
                success   => 1,
                is_alive  => $shinobu->poll(),
                pid       => $shinobu->pid
            }
        );
    } else {
        open( my $fh, "<", get_temp() . "/shinobu.pid-s6" );
        chomp(my $pid = <$fh>);
        close($fh);

        my $shinobu;
        Win32::Process::Open($shinobu, $pid, 0);

        $self->render(
            json => {
                operation => "shinobu_status",
                success   => 1,
                is_alive  => !$shinobu->Wait(1),
                pid       => "" . $shinobu->GetProcessID()
            }
        );
    }
}

sub reset_filemap {
    my $self = shift;

    # This is a shinobu endpoint even though we're deleting stuff in redis
    # since we'll have to restart shinobu anyway to proc filemap re-creation.

    my $redis = $self->LRR_CONF->get_redis_config;
    $redis->del("LRR_FILEMAP");
    $redis->quit();

    if ( $Config{osname} ne 'MSWin32') {
        my $shinobu = ${ retrieve( get_temp . "/shinobu.pid" ) };

        #commit sudoku
        $shinobu->kill();
    } else {
        open( my $fh, "<", get_temp() . "/shinobu.pid-s6" );
        chomp(my $pid = <$fh>);
        close($fh);
        kill HUP => $pid;
    }

    # Create a new Process, automatically stored in TEMP_FOLDER/shinobu.pid
    my $proc = start_shinobu($self);

    if ( $Config{osname} ne 'MSWin32') {
        $self->render(
            json => {
                operation => "shinobu_rescan",
                success   => $proc->poll(),
                new_pid   => $proc->pid
            }
        );
    } else {
        $self->render(
            json => {
                operation => "shinobu_rescan",
                success   => !$proc->Wait(1),
                new_pid   => "" . $proc->GetProcessID()
            }
        );
    }
}

sub stop_shinobu {
    my $self    = shift;

    if ( $Config{osname} ne 'MSWin32') {
        my $shinobu = ${ retrieve( get_temp . "/shinobu.pid" ) };

        #commit sudoku
        $shinobu->kill();
    } else {
        open( my $fh, "<", get_temp() . "/shinobu.pid-s6" );
        chomp(my $pid = <$fh>);
        close($fh);
        kill HUP => $pid;
    }

    render_api_response( $self, "shinobu_stop" );
}

sub restart_shinobu {
    my $self    = shift;

    if ( $Config{osname} ne 'MSWin32') {
        my $shinobu = ${ retrieve( get_temp . "/shinobu.pid" ) };

        #commit sudoku
        $shinobu->kill();
    } else {
        open( my $fh, "<", get_temp() . "/shinobu.pid-s6" );
        chomp(my $pid = <$fh>);
        close($fh);
        kill HUP => $pid;
    }

    # Create a new Process, automatically stored in TEMP_FOLDER/shinobu.pid
    my $proc = start_shinobu($self);

    if ( $Config{osname} ne 'MSWin32') {
        $self->render(
            json => {
                operation => "shinobu_restart",
                success   => $proc->poll(),
                new_pid   => $proc->pid
            }
        );
    } else {
        $self->render(
            json => {
                operation => "shinobu_restart",
                success   => !$proc->Wait(1),
                new_pid   => "" . $proc->GetProcessID()
            }
        );
    }
}

1;

