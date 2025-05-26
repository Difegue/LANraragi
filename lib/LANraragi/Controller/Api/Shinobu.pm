package LANraragi::Controller::Api::Shinobu;
use Mojo::Base 'Mojolicious::Controller';
use Storable;
use Config;

use LANraragi::Utils::Generic qw(start_shinobu render_api_response);
use LANraragi::Utils::TempFolder qw(get_temp);

use constant IS_WIN => ( $Config{osname} eq 'MSWin32' );

BEGIN {
    if ( IS_WIN ) {
        require Win32::Process;
        Win32::Process->import( qw(NORMAL_PRIORITY_CLASS) );
    }
}

sub shinobu_status {
    my $self    = shift;

    if ( !IS_WIN ) {
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
        eval {
            Win32::Process::Open($shinobu, $pid, 0);

            $self->render(
                json => {
                    operation => "shinobu_status",
                    success   => 1,
                    is_alive  => $shinobu->GetProcessID() != 0,
                    pid       => "" . $shinobu->GetProcessID()
                }
            );
        };
    }
}

sub reset_filemap {
    my $self = shift;

    # This is a shinobu endpoint even though we're deleting stuff in redis
    # since we'll have to restart shinobu anyway to proc filemap re-creation.

    my $redis = $self->LRR_CONF->get_redis_config;
    $redis->del("LRR_FILEMAP");
    $redis->quit();

    if ( !IS_WIN ) {
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

    if ( !IS_WIN ) {
        $self->render(
            json => {
                operation => "shinobu_rescan",
                success   => $proc->poll(),
                new_pid   => $proc->pid
            }
        );
    } else {
        eval {
            $self->render(
                json => {
                    operation => "shinobu_rescan",
                    success   => $proc->GetProcessID() != 0,
                    new_pid   => "" . $proc->GetProcessID()
                }
            );
        };
    }
}

sub stop_shinobu {
    my $self    = shift;

    if ( !IS_WIN ) {
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

    if ( !IS_WIN ) {
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

    if ( !IS_WIN ) {
        $self->render(
            json => {
                operation => "shinobu_restart",
                success   => $proc->poll(),
                new_pid   => $proc->pid
            }
        );
    } else {
        eval {
            $self->render(
                json => {
                    operation => "shinobu_restart",
                    success   => $proc->GetProcessID() != 0,
                    new_pid   => "" . $proc->GetProcessID()
                }
            );
        };
    }
}

1;

