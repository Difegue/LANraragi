package LANraragi::Controller::Api::Registry;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON qw(decode_json);

use LANraragi::Model::Registry;
use LANraragi::Utils::Generic qw(render_api_response exec_with_lock);

sub get_registry {
    my $self    = shift->openapi->valid_input or return;
    my $redis   = $self->LRR_CONF->get_redis_config;

    unless ( $redis->exists("LRR_REGISTRY") ) {
        $redis->quit();
        $self->render(
            openapi => {
                operation   => "get_registry",
                success     => 1,
                registry    => undef,
            }
        );
        return;
    }

    my %registry = $redis->hgetall("LRR_REGISTRY");
    $redis->quit();

    $self->render(
        openapi => {
            operation   => "get_registry",
            success     => 1,
            registry    => \%registry,
        }
    );
}

sub set_registry {
    my $self    = shift->openapi->valid_input or return;
    my $body    = $self->req->json;
    my $type    = $body->{type};

    unless ( $type eq "git" || $type eq "local" ) {
        render_api_response( $self, "set_registry", "Invalid registry type: must be 'git' or 'local'." );
        return;
    }

    if ( $type eq "git" ) {
        unless ( $body->{url} ) {
            render_api_response( $self, "set_registry", "Missing required field 'url' for git registry." );
            return;
        }
        my $provider = $body->{provider};
        unless ( $provider && ( $provider eq "github" || $provider eq "gitlab" || $provider eq "gitea" ) ) {
            render_api_response( $self, "set_registry", "Missing or invalid 'provider': must be 'github', 'gitlab', or 'gitea'." );
            return;
        }
    }

    if ( $type eq "local" ) {
        unless ( $body->{path} ) {
            render_api_response( $self, "set_registry", "Missing required field 'path' for local registry." );
            return;
        }
    }

    return unless exec_with_lock(
        $self,
        "registry-write",
        "set_registry",
        "registry",
        sub {
            my $redis = $self->LRR_CONF->get_redis_config;

            # Clear existing registry config before setting new one
            $redis->del("LRR_REGISTRY");

            $redis->hset( "LRR_REGISTRY", "type", $type );

            if ( $type eq "git" ) {
                $redis->hset( "LRR_REGISTRY", "provider", $body->{provider} );
                $redis->hset( "LRR_REGISTRY", "url", $body->{url} );
                $redis->hset( "LRR_REGISTRY", "ref", $body->{ref} // "main" );
            } elsif ( $type eq "local" ) {
                $redis->hset( "LRR_REGISTRY", "path", $body->{path} );
            }

            my %registry = $redis->hgetall("LRR_REGISTRY");
            $redis->quit();

            $self->render(
                openapi => {
                    operation   => "set_registry",
                    success     => 1,
                    registry    => \%registry,
                }
            );
        }
    );
}

sub delete_registry {
    my $self    = shift->openapi->valid_input or return;

    return unless exec_with_lock(
        $self,
        "registry-write",
        "delete_registry",
        "registry",
        sub {
            my $redis = $self->LRR_CONF->get_redis_config;

            $redis->del("LRR_REGISTRY");
            $redis->del("LRR_REGISTRY_INDEX");
            $redis->quit();

            render_api_response( $self, "delete_registry" );
        }
    );
}

sub refresh_registry {
    my $self    = shift->openapi->valid_input or return;

    return unless exec_with_lock(
        $self,
        "registry-write",
        "refresh_registry",
        "registry",
        sub {
            my $redis = $self->LRR_CONF->get_redis_config;

            unless ( $redis->exists("LRR_REGISTRY") ) {
                $redis->quit();
                render_api_response( $self, "refresh_registry", "No registry configured." );
                return;
            }

            my %config = $redis->hgetall("LRR_REGISTRY");
            my $type   = $config{type};

            my ( $content, $error ) = LANraragi::Model::Registry::fetch_registry_index( $type, %config );

            if ($error) {
                $redis->quit();
                render_api_response( $self, "refresh_registry", $error );
                return;
            }

            # Validate the index has a version field
            my $index = eval { decode_json($content) };
            if ($@) {
                $redis->quit();
                render_api_response( $self, "refresh_registry", "Invalid registry.json: $@" );
                return;
            }

            unless ( $index->{version} ) {
                $redis->quit();
                render_api_response( $self, "refresh_registry", "Invalid registry.json: missing 'version' field." );
                return;
            }

            # Cache the raw JSON
            $redis->set( "LRR_REGISTRY_INDEX", $content );
            $redis->quit();

            $self->render(
                openapi => {
                    operation   => "refresh_registry",
                    success     => 1,
                    index       => $index,
                }
            );
        }
    );
}

sub install_plugin {
    my $self        = shift->openapi->valid_input or return;
    my $body        = $self->req->json;
    my $namespace   = $body->{namespace};

    unless ($namespace) {
        render_api_response( $self, "install_plugin", "Missing required field 'namespace'." );
        return;
    }

    return unless exec_with_lock(
        $self,
        "plugin-write:$namespace",
        "install_plugin",
        $namespace,
        sub {
            my $redis = $self->LRR_CONF->get_redis_config;
            my ( $plugin_meta, $error ) = eval { LANraragi::Model::Registry::install_plugin( $namespace, $redis ) };
            if ($@) {
                $redis->quit();
                render_api_response( $self, "install_plugin", "Internal error: $@" );
                return;
            }
            $redis->quit();

            if ($error) {
                render_api_response( $self, "install_plugin", $error );
                return;
            }

            $self->render(
                openapi => {
                    operation   => "install_plugin",
                    success     => 1,
                    name        => $plugin_meta->{name},
                    namespace   => $namespace,
                    version     => $plugin_meta->{version},
                }
            );
        }
    );
}

sub uninstall_plugin {
    my $self        = shift->openapi->valid_input or return;
    my $namespace   = $self->stash('plugin_namespace');

    return unless exec_with_lock(
        $self,
        "plugin-write:$namespace",
        "uninstall_plugin",
        $namespace,
        sub {
            my $redis = $self->LRR_CONF->get_redis_config;

            my ( $success, $error ) = LANraragi::Model::Registry::uninstall_plugin( $namespace, $redis );
            $redis->quit();

            if ($error) {
                render_api_response( $self, "uninstall_plugin", $error );
                return;
            }

            render_api_response( $self, "uninstall_plugin" );
        }
    );
}

sub update_plugin_config {
    my $self        = shift->openapi->valid_input or return;
    my $namespace   = $self->stash('plugin_namespace');
    my $body        = $self->req->json;

    return unless exec_with_lock(
        $self,
        "plugin-write:$namespace",
        "update_plugin_config",
        $namespace,
        sub {
            my $redis   = $self->LRR_CONF->get_redis_config;
            my $namerds = "LRR_PLUGIN_" . uc($namespace);

            if ( exists $body->{hidden} ) {
                $redis->hset( $namerds, "hidden", $body->{hidden} ? "1" : "0" );
            }

            $redis->quit();

            render_api_response( $self, "update_plugin_config" );
        }
    );
}

1;
