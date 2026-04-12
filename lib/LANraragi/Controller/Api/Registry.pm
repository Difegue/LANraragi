package LANraragi::Controller::Api::Registry;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON qw(decode_json true false);

use LANraragi::Model::Registry;
use LANraragi::Utils::Generic qw(render_api_response exec_with_lock);
use LANraragi::Utils::Logging qw(get_logger);

sub list_registries {
    my $self  = shift->openapi->valid_input or return;
    my $redis = $self->LRR_CONF->get_redis_config;

    my @registries = LANraragi::Model::Registry::get_registry_list($redis);
    $redis->quit();

    $self->render(
        openapi => {
            operation  => "list_registries",
            success    => 1,
            registries => \@registries,
        }
    );
}

sub create_registry {
    my $self = shift->openapi->valid_input or return;
    my $body = $self->req->json;
    my $type = $body->{type};

    unless ( $type eq "git" || $type eq "local" ) {
        render_api_response( $self, "create_registry", "Invalid registry type: must be 'git' or 'local'." );
        return;
    }

    unless ( $body->{name} ) {
        render_api_response( $self, "create_registry", "Registry name is required." );
        return;
    }

    if ( $type eq "git" ) {
        unless ( $body->{url} ) {
            render_api_response( $self, "create_registry", "Git registry needs a URL." );
            return;
        }
        unless ( $body->{url} =~ m{^https://} ) {
            render_api_response( $self, "create_registry", "Git registry URL must use HTTPS." );
            return;
        }
        my $provider = $body->{provider};
        unless ( $provider && ( $provider eq "github" || $provider eq "gitlab" || $provider eq "gitea" ) ) {
            render_api_response( $self, "create_registry", "Invalid provider -- must be github, gitlab, or gitea." );
            return;
        }
    }

    if ( $type eq "local" ) {
        unless ( $body->{path} ) {
            render_api_response( $self, "create_registry", "Local registry needs a path." );
            return;
        }
    }

    return unless exec_with_lock(
        $self,
        "registry-create",
        "create_registry",
        "registry",
        sub {
            my $redis = $self->LRR_CONF->get_redis_config;

            my %config = ( name => $body->{name}, type => $type );

            if ( $type eq "git" ) {
                $config{provider} = $body->{provider};
                $config{url}      = $body->{url};
                $config{ref}      = $body->{ref} // "main";
            } elsif ( $type eq "local" ) {
                $config{path} = $body->{path};
            }

            my ( $reg_id, $error ) = LANraragi::Model::Registry::create_registry( $redis, %config );
            $redis->quit();

            if ($error) {
                render_api_response( $self, "create_registry", $error );
                return;
            }

            $self->render(
                openapi => {
                    operation => "create_registry",
                    success   => 1,
                    error     => "",
                    id        => $reg_id,
                    registry  => { id => $reg_id, %config },
                }
            );
        }
    );
}

sub get_registry {
    my $self  = shift->openapi->valid_input or return;
    my $regid = $self->stash('id');
    my $redis = $self->LRR_CONF->get_redis_config;

    my %registry = LANraragi::Model::Registry::get_registry( $regid, $redis );
    $redis->quit();

    unless (%registry) {
        $self->render(
            openapi => {
                operation => "get_registry",
                error     => "This registry doesn't exist.",
                success   => 0,
            },
            status => 404
        );
        return;
    }

    $self->render(
        openapi => {
            operation => "get_registry",
            success   => 1,
            error     => "",
            id        => $regid,
            registry  => \%registry,
        }
    );
}

sub update_registry {
    my $self  = shift->openapi->valid_input or return;
    my $regid = $self->stash('id');
    my $body  = $self->req->json;

    return unless exec_with_lock(
        $self,
        "registry-write:$regid",
        "update_registry",
        $regid,
        sub {
            my $redis = $self->LRR_CONF->get_redis_config;

            my %existing = LANraragi::Model::Registry::get_registry( $regid, $redis );
            unless (%existing) {
                $redis->quit();
                $self->render(
                    openapi => {
                        operation => "update_registry",
                        error     => "This registry doesn't exist.",
                        success   => 0,
                    },
                    status => 404
                );
                return;
            }

            my %updates;
            for my $field (qw(name type provider url ref path)) {
                $updates{$field} = $body->{$field} if exists $body->{$field};
            }

            unless (%updates) {
                $redis->quit();
                render_api_response( $self, "update_registry", "Nothing to update." );
                return;
            }

            # Enforce HTTPS for git registry URLs
            my $mergedtype = $updates{type} // $existing{type};
            my $mergedurl  = $updates{url}  // $existing{url};
            if ( $mergedtype eq "git" && $mergedurl && $mergedurl !~ m{^https://} ) {
                $redis->quit();
                render_api_response( $self, "update_registry", "Git registry URL must use HTTPS." );
                return;
            }

            my ( $indexkey, $error ) = LANraragi::Model::Registry::update_registry( $regid, $redis, %updates );

            if ($error) {
                $redis->quit();
                render_api_response( $self, "update_registry", $error );
                return;
            }

            my %registry = LANraragi::Model::Registry::get_registry( $regid, $redis );
            $redis->quit();

            $self->render(
                openapi => {
                    operation     => "update_registry",
                    success       => 1,
                    error         => "",
                    id            => $regid,
                    registry      => \%registry,
                    index_cleared => $indexkey ? true : false,
                }
            );
        }
    );
}

sub delete_registry {
    my $self  = shift->openapi->valid_input or return;
    my $regid = $self->stash('id');

    return unless exec_with_lock(
        $self,
        "registry-write:$regid",
        "delete_registry",
        $regid,
        sub {
            my $redis = $self->LRR_CONF->get_redis_config;

            my %existing = LANraragi::Model::Registry::get_registry( $regid, $redis );
            unless (%existing) {
                $redis->quit();
                $self->render(
                    openapi => {
                        operation => "delete_registry",
                        error     => "This registry doesn't exist.",
                        success   => 0,
                    },
                    status => 404
                );
                return;
            }

            my ( $success, $error ) = LANraragi::Model::Registry::delete_registry( $regid, $redis );
            $redis->quit();

            if ($error) {
                render_api_response( $self, "delete_registry", $error );
                return;
            }

            render_api_response( $self, "delete_registry" );
        }
    );
}

sub refresh_registry {
    my $self  = shift->openapi->valid_input or return;
    my $regid = $self->stash('id');

    return unless exec_with_lock(
        $self,
        "registry-write:$regid",
        "refresh_registry",
        $regid,
        sub {
            my $redis = $self->LRR_CONF->get_redis_config;

            my %config = LANraragi::Model::Registry::get_registry( $regid, $redis );

            unless (%config) {
                $redis->quit();
                $self->render(
                    openapi => {
                        operation => "refresh_registry",
                        error     => "This registry doesn't exist.",
                        success   => 0,
                    },
                    status => 404
                );
                return;
            }

            my $type = $config{type};
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

            unless ( ref $index->{plugins} eq 'HASH' ) {
                $redis->quit();
                render_api_response( $self, "refresh_registry", "Invalid registry.json: 'plugins' must be an object." );
                return;
            }

            # Cache the raw JSON under the paired index key
            my ($suffix) = $regid =~ /^REG_(\d{10})$/;
            my $indexkey = "REG_INDEX_$suffix";
            $redis->set( $indexkey, $content );
            $redis->quit();

            $self->render(
                openapi => {
                    operation => "refresh_registry",
                    success   => 1,
                    index     => $index,
                }
            );
        }
    );
}

sub install_plugin {
    my $self      = shift->openapi->valid_input or return;
    my $body      = $self->req->json;
    my $namespace = $body->{namespace};
    my $regid     = $body->{registry};
    my $force     = $body->{force} // 0;

    return unless exec_with_lock(
        $self,
        "plugin-write:$namespace",
        "install_plugin",
        $namespace,
        sub {
            my $redis = $self->LRR_CONF->get_redis_config;

            # Check provenance conflict
            my $namerds = "LRR_PLUGIN_" . uc($namespace);
            if ( $redis->hexists( $namerds, "installed_path" ) && !$force ) {
                my $currentreg = $redis->hget( $namerds, "registry" );
                my $currentver = $redis->hget( $namerds, "installed_version" );

                unless ($currentreg) {
                    # No provenance (legacy/sideloaded) -- requires force
                    $redis->quit();
                    render_api_response( $self, "install_plugin",
                        "Plugin '$namespace' already exists without provenance. Use force to overwrite." );
                    return;
                }

                if ( $currentreg ne $regid ) {
                    # Different registry -- requires force
                    $redis->quit();
                    render_api_response( $self, "install_plugin",
                        "Plugin '$namespace' already installed from '$currentreg' (v$currentver). Use force to overwrite." );
                    return;
                }

                # Same registry -- upgrade allowed without force
            }

            my $logger = get_logger( "Registry", "lanraragi" );
            my ( $plugmeta, $error ) = eval {
                LANraragi::Model::Registry::install_plugin( $namespace, $redis, $regid );
            };
            if ($@) {
                $logger->error("install_plugin failed for '$namespace': $@");
                $redis->quit();
                render_api_response( $self, "install_plugin", "Plugin installation failed." );
                return;
            }
            $redis->quit();

            if ($error) {
                render_api_response( $self, "install_plugin", $error );
                return;
            }

            $self->render(
                openapi => {
                    operation => "install_plugin",
                    success   => 1,
                    name      => $plugmeta->{name},
                    namespace => $namespace,
                    version   => $plugmeta->{version},
                    registry  => $regid,
                }
            );
        }
    );
}

sub uninstall_plugin {
    my $self      = shift->openapi->valid_input or return;
    my $namespace = $self->stash('plugin_namespace');

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
    my $self      = shift->openapi->valid_input or return;
    my $namespace = $self->stash('plugin_namespace');
    my $body      = $self->req->json;

    return unless exec_with_lock(
        $self,
        "plugin-write:$namespace",
        "update_plugin_config",
        $namespace,
        sub {
            my $redis   = $self->LRR_CONF->get_redis_config;
            my $namerds = "LRR_PLUGIN_" . uc($namespace);

            unless ( $redis->exists($namerds) ) {
                $redis->quit();
                $self->render(
                    openapi => {
                        operation   => "update_plugin_config",
                        error       => "Plugin '$namespace' doesn't exist on the server.",
                        success     => 0,
                    },
                    status => 404
                );
                return;
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
