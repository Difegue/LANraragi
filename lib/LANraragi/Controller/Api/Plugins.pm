package LANraragi::Controller::Api::Plugins;
use Mojo::Base 'Mojolicious::Controller';

use LANraragi::Model::Plugins;
use LANraragi::Utils::Generic qw(render_api_response exec_with_lock);
use LANraragi::Utils::Logging qw(get_logger);

# Update metadata plugin configuration.
# TODO(REVIEW): what if the plugin does not exist on disk? If a plugin is not installed,
# should its configs be updatable?
sub update_metadata_plugin_config {
    my $self        = shift->openapi->valid_input or return;
    my $namespace   = $self->stash('plugin_namespace');
    my $body        = $self->req->json; # TODO(REVIEW): document shape of body

    return unless exec_with_lock(
        $self,
        "plugin-write:" . uc($namespace),
        "update_metadata_plugin_config",
        $namespace,
        sub {
            my $redis   = $self->LRR_CONF->get_redis_config;
            my $namerds = "LRR_PLUGIN_" . uc($namespace);

            unless ( $redis->hexists( $namerds, "installed_path" ) ) {
                $redis->quit();
                $self->render(
                    openapi => {
                        operation => "update_metadata_plugin_config",
                        error     => "Plugin '$namespace' is not installed.",
                        success   => 0,
                    },
                    status => 404
                );
                return;
            }

            # Check that our type exists and is metadata.
            # if no type, then something's very wrong ...
            my $type = $redis->hget( $namerds, "type" );
            unless ( defined $type ) {
                $redis->quit();
                get_logger( "Plugin System", "lanraragi" )
                    ->error("Plugin '$namespace' is registered without a type.");
                $self->render(
                    openapi => {
                        operation => "update_metadata_plugin_config",
                        error     => "Plugin '$namespace' has no recorded type.",
                        success   => 0,
                    },
                    status => 500
                );
                return;
            }

            if ( $type ne "metadata" ) {
                $redis->quit();
                $self->render(
                    openapi => {
                        operation => "update_metadata_plugin_config",
                        error     => "Plugin '$namespace' is not a metadata plugin; enabled/hidden/priority do not apply.",
                        success   => 0,
                    },
                    status => 400
                );
                return;
            }

            # TODO(REVIEW): transaction + error handling
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

            render_api_response( $self, "update_metadata_plugin_config" );
        }
    );
}

sub install_plugin {
    my $self              = shift->openapi->valid_input or return;
    my $body              = $self->req->json;
    my $namespace   = $body->{namespace};
    my $registry_id = $body->{registry};
    my $version     = $body->{version};
    my $force       = $body->{force} // 0;              # upgrade path

    return unless exec_with_lock(
        $self,
        "plugin-write:" . uc($namespace),
        "install_plugin",
        $namespace,
        sub {
            my $redis = $self->LRR_CONF->get_redis_config;
            # Since a plugin namespace can be built-in or managed, we'll need to check redis first.
            # If a plugin exists and is not managed, installation may not continue.
            # The user will have to remove/uninstall the existing plugin before installing a managed plugin
            # by the same namespace.
            my $namerds = "LRR_PLUGIN_" . uc($namespace);
            if ( $redis->hexists( $namerds, "installed_path" ) ) {
                my $source     = LANraragi::Model::Plugins::infer_plugin_source( $namerds, $redis );
                my $currentreg = $redis->hget( $namerds, "installed_registry" );
                my $currentver = $redis->hget( $namerds, "installed_version" );

                if ( $source ne "managed" ) {
                    $redis->quit();
                    render_api_response(
                        $self,
                        "install_plugin",
                        "Plugin '$namespace' already exists as a $source plugin. Remove it first before installing from a registry."
                    );
                    return;
                }

                my $is_installed = $currentreg && $currentreg ne $registry_id;
                if ( $is_installed && !$force ) {
                    $redis->quit();
                    render_api_response(
                        $self,
                        "install_plugin",
                        "Plugin '$namespace' already installed from '$currentreg' (v$currentver). Use force to overwrite."
                    );
                    return;
                }
            }

            my $logger = get_logger( "Registry", "lanraragi" );
            my $install_error;
            my ( $status, $plugmeta, $message ) = eval {
                LANraragi::Model::Plugins::install_plugin(
                    $namespace, $redis, $registry_id, $version
                );
            };
            $install_error = $@;

            if ($install_error) {
                $redis->quit();
                $logger->error("install_plugin failed for '$namespace': $install_error");
                render_api_response( $self, "install_plugin", "Plugin installation failed." );
                return;
            }

            $redis->quit();

            unless ( $status == 200 ) {
                $self->render(
                    openapi => { operation => "install_plugin", error => $message, success => 0 },
                    status  => $status
                );
                return;
            }

            $self->render(
                openapi => {
                    operation          => "install_plugin",
                    success            => 1,
                    name               => $plugmeta->{name},
                    namespace          => $namespace,
                    version            => $plugmeta->{version},
                    installed_registry => $plugmeta->{installed_registry},
                    installed_sha256   => $plugmeta->{installed_sha256},
                }
            );
        },
        60,
    );
}

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
            my ( $status, $success, $message ) = LANraragi::Model::Plugins::uninstall_plugin(
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
