package LANraragi::Controller::Api::Registry;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON qw(decode_json true false);

use LANraragi::Model::Registry;
use LANraragi::Utils::Generic qw(render_api_response exec_with_lock);
use LANraragi::Utils::Logging qw(get_logger);

#
# Registry CRUD
#

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
        render_api_response( $self, "create_registry", "Missing required field 'name'." );
        return;
    }

    if ( $type eq "git" ) {
        unless ( $body->{url} ) {
            render_api_response( $self, "create_registry", "Missing required field 'url' for git registry." );
            return;
        }
        my $provider = $body->{provider};
        unless ( $provider && ( $provider eq "github" || $provider eq "gitlab" || $provider eq "gitea" ) ) {
            render_api_response( $self, "create_registry", "Missing or invalid 'provider': must be 'github', 'gitlab', or 'gitea'." );
            return;
        }
    }

    if ( $type eq "local" ) {
        unless ( $body->{path} ) {
            render_api_response( $self, "create_registry", "Missing required field 'path' for local registry." );
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
    my $self        = shift->openapi->valid_input or return;
    my $registry_id = $self->stash('id');
    my $redis       = $self->LRR_CONF->get_redis_config;

    my %registry = LANraragi::Model::Registry::get_registry( $registry_id, $redis );
    $redis->quit();

    unless (%registry) {
        render_api_response( $self, "get_registry", "Registry does not exist." );
        return;
    }

    $self->render(
        openapi => {
            operation => "get_registry",
            success   => 1,
            error     => "",
            id        => $registry_id,
            registry  => \%registry,
        }
    );
}

sub update_registry {
    my $self        = shift->openapi->valid_input or return;
    my $registry_id = $self->stash('id');
    my $body        = $self->req->json;

    return unless exec_with_lock(
        $self,
        "registry-write:$registry_id",
        "update_registry",
        $registry_id,
        sub {
            my $redis = $self->LRR_CONF->get_redis_config;

            my %updates;
            for my $field (qw(name type provider url ref path)) {
                $updates{$field} = $body->{$field} if exists $body->{$field};
            }

            unless (%updates) {
                $redis->quit();
                render_api_response( $self, "update_registry", "No recognized fields to update." );
                return;
            }

            my ( $index_cleared, $error ) = LANraragi::Model::Registry::update_registry( $registry_id, $redis, %updates );

            if ($error) {
                $redis->quit();
                render_api_response( $self, "update_registry", $error );
                return;
            }

            my %registry = LANraragi::Model::Registry::get_registry( $registry_id, $redis );
            $redis->quit();

            $self->render(
                openapi => {
                    operation     => "update_registry",
                    success       => 1,
                    error         => "",
                    id            => $registry_id,
                    registry      => \%registry,
                    index_cleared => $index_cleared ? true : false,
                }
            );
        }
    );
}

sub delete_registry {
    my $self        = shift->openapi->valid_input or return;
    my $registry_id = $self->stash('id');

    return unless exec_with_lock(
        $self,
        "registry-write:$registry_id",
        "delete_registry",
        $registry_id,
        sub {
            my $redis = $self->LRR_CONF->get_redis_config;

            my ( $success, $error ) = LANraragi::Model::Registry::delete_registry( $registry_id, $redis );
            $redis->quit();

            if ($error) {
                render_api_response( $self, "delete_registry", $error );
                return;
            }

            render_api_response( $self, "delete_registry" );
        }
    );
}

#
# Registry Index
#

sub refresh_registry {
    my $self        = shift->openapi->valid_input or return;
    my $registry_id = $self->stash('id');

    return unless exec_with_lock(
        $self,
        "registry-write:$registry_id",
        "refresh_registry",
        $registry_id,
        sub {
            my $redis = $self->LRR_CONF->get_redis_config;

            my %config = LANraragi::Model::Registry::get_registry( $registry_id, $redis );

            unless (%config) {
                $redis->quit();
                render_api_response( $self, "refresh_registry", "Registry does not exist." );
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

            # Cache the raw JSON under the paired index key
            my ($suffix) = $registry_id =~ /^REG_(\d{10})$/;
            my $index_key = "REG_INDEX_$suffix";
            $redis->set( $index_key, $content );
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

#
# Plugin Operations
#

sub install_plugin {
    my $self      = shift->openapi->valid_input or return;
    my $body      = $self->req->json;
    my $namespace = $body->{namespace};

    unless ($namespace) {
        render_api_response( $self, "install_plugin", "Missing required field 'namespace'." );
        return;
    }

    my $registry_id = $body->{registry};
    my $force       = $body->{force} // 0;

    unless ($registry_id) {
        render_api_response( $self, "install_plugin", "Missing required field 'registry'." );
        return;
    }

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
                my $current_registry = $redis->hget( $namerds, "registry" ) // "";
                my $current_version  = $redis->hget( $namerds, "installed_version" ) // "";

                if ( $current_registry eq "" ) {
                    # No provenance (legacy/sideloaded) — requires force
                    $redis->quit();
                    render_api_response( $self, "install_plugin",
                        "Plugin '$namespace' is already installed (no provenance). Use force to replace." );
                    return;
                }

                if ( $current_registry ne $registry_id ) {
                    # Different registry — requires force
                    $redis->quit();
                    render_api_response( $self, "install_plugin",
                        "Plugin '$namespace' is already installed from registry '$current_registry' (v$current_version). Use force to replace." );
                    return;
                }

                # Same registry — upgrade allowed without force
            }

            my ( $plugin_meta, $error ) = eval {
                LANraragi::Model::Registry::install_plugin( $namespace, $redis, $registry_id );
            };
            if ($@) {
                my $logger = get_logger( "Registry", "lanraragi" );
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
                    name      => $plugin_meta->{name},
                    namespace => $namespace,
                    version   => $plugin_meta->{version},
                    registry  => $registry_id,
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

            if ( exists $body->{hidden} ) {
                $redis->hset( $namerds, "hidden", $body->{hidden} ? "1" : "0" );
            }

            $redis->quit();

            render_api_response( $self, "update_plugin_config" );
        }
    );
}

1;
