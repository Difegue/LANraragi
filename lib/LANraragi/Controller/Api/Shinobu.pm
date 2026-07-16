package LANraragi::Controller::Api::Shinobu;
use Mojo::Base 'Mojolicious::Controller';
use Storable;
use Config;

use LANraragi::Utils::Generic qw(start_shinobu render_api_response);
use LANraragi::Utils::TempFolder qw(get_temp);
use LANraragi::Model::Metrics;

use constant IS_UNIX => ( $Config{osname} ne 'MSWin32' );

BEGIN {
    if ( !IS_UNIX ) {
        require Win32::Process;
        Win32::Process->import( qw(NORMAL_PRIORITY_CLASS) );
    }
}

sub shinobu_status {
    my $self    = shift->openapi->valid_input or return;

    if ( IS_UNIX ) {
        my $shinobu = ${ retrieve( get_temp . "/shinobu.pid" ) };

        $self->render(
            openapi => {
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
        eval {
            Win32::Process::Open($shinobu, $pid, 0);

            $self->render(
                openapi => {
                    operation => "shinobu_status",
                    success   => 1,
                    is_alive  => ($shinobu->GetProcessID() != 0) ? 1 : 0,
                    pid       => int($shinobu->GetProcessID())
                }
            );
        };
    }
}

sub reset_filemap {
    my $self = shift->openapi->valid_input or return;

    # This is a shinobu endpoint even though we're deleting stuff in redis
    # since we'll have to restart shinobu anyway to proc filemap re-creation.

    my $redis = $self->LRR_CONF->get_redis_config;
    $redis->del("LRR_FILEMAP");
    $redis->quit();

    if ( IS_UNIX ) {
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

    if ( IS_UNIX ) {
        $self->render(
            openapi => {
                operation => "shinobu_rescan",
                success   => $proc->poll(),
                new_pid   => $proc->pid
            }
        );
    } else {
        eval {
            $self->render(
                openapi => {
                    operation => "shinobu_rescan",
                    success   => ($proc->GetProcessID() != 0) ? 1 : 0,
                    new_pid   => int($proc->GetProcessID())
                }
            );
        };
    }
}

sub stop_shinobu {
    my $self    = shift->openapi->valid_input or return;

    if ( IS_UNIX ) {
        my $shinobu = ${ retrieve( get_temp . "/shinobu.pid" ) };

        #commit sudoku
        $shinobu->kill();
    } else {
        open( my $fh, "<", get_temp() . "/shinobu.pid-s6" );
        chomp(my $pid = <$fh>);
        close($fh);
        kill HUP => $pid;
    }

    if ( $self->LRR_CONF->enable_metrics ) {
        LANraragi::Model::Metrics::unregister_shinobu();
    }

    render_api_response( $self, "shinobu_stop" );
}

sub restart_shinobu {
    my $self    = shift->openapi->valid_input or return;

    if ( IS_UNIX ) {
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

    if ( IS_UNIX ) {
        $self->render(
            openapi => {
                operation => "shinobu_restart",
                success   => $proc->poll(),
                new_pid   => $proc->pid
            }
        );
    } else {
        eval {
            $self->render(
                openapi => {
                    operation => "shinobu_restart",
                    success   => ($proc->GetProcessID() != 0) ? 1 : 0,
                    new_pid   => int($proc->GetProcessID())
                }
            );
        };
    }
}

1;

