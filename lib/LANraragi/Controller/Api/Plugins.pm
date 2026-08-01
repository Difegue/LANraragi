package LANraragi::Controller::Api::Plugins;
use Mojo::Base 'Mojolicious::Controller';

use LANraragi::Model::Plugins;
use LANraragi::Utils::Generic qw(render_api_response exec_with_lock);

# Install a managed plugin.
sub install_plugin {
    my $self        = shift->openapi->valid_input or return;
    my $body        = $self->req->json;
    my $namespace   = $body->{namespace};
    my $registry_id = $body->{registry};
    my $version     = $body->{version};
    my $force       = $body->{force} // 0;

    my $jobid = $self->minion->enqueue(
        install_plugin => [ $namespace, $registry_id, $version, $force ] => { priority => 0, attempts => 1 } );

    $self->render(
        openapi => {
            operation   => "install_plugin",
            namespace   => $namespace,
            success     => 1,
            job         => $jobid,
        }
    );
}

# Uninstall a managed plugin.
sub uninstall_plugin {
    my $self      = shift->openapi->valid_input or return;
    my $namespace = $self->stash('plugin_namespace');

    return unless exec_with_lock(
        $self,
        "plugin-write:" . uc($namespace),
        "uninstall_plugin",
        $namespace,
        sub {
            my $redis = $self->LRR_CONF->get_redis_config;
            my ( $status, $message ) = LANraragi::Model::Plugins::uninstall_plugin(
                $namespace, $redis
            );
            $redis->quit();

            unless ( $status == 200 ) {
                $self->render(
                    openapi => { operation => "uninstall_plugin", error => $message, success => 0 },
                    status  => $status
                );
                return;
            }

            render_api_response( $self, "uninstall_plugin" );
        }
    );
}

1;
