package LANraragi::Controller::Api::Plugins;
use Mojo::Base 'Mojolicious::Controller';

use LANraragi::Utils::Generic qw(render_api_response exec_with_lock);

sub update_plugin_config {
    my $self      = shift->openapi->valid_input or return;
    my $namespace = $self->stash('plugin_namespace');
    my $body      = $self->req->json;

    return unless exec_with_lock(
        $self,
        "plugin-write:" . uc($namespace),
        "update_plugin_config",
        $namespace,
        sub {
            my $redis   = $self->LRR_CONF->get_redis_config;
            my $namerds = "LRR_PLUGIN_" . uc($namespace);

            unless ( $redis->hexists( $namerds, "installed_path" ) ) {
                $redis->quit();
                $self->render(
                    openapi => {
                        operation => "update_plugin_config",
                        error     => "Plugin '$namespace' is not installed.",
                        success   => 0,
                    },
                    status => 404
                );
                return;
            }

            if ( exists $body->{enabled} ) {
                $redis->hset( $namerds, "enabled", $body->{enabled} ? "1" : "0" );
            }

            if ( exists $body->{hidden} ) {
                $redis->hset( $namerds, "hidden", $body->{hidden} ? "1" : "0" );
            }

            if ( exists $body->{priority} ) {
                $redis->hset( $namerds, "priority", $body->{priority} );
            }

            $redis->quit();

            render_api_response( $self, "update_plugin_config" );
        }
    );
}

1;
