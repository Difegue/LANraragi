package LANraragi::Controller::Api::Registry;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON qw(decode_json true false);

use LANraragi::Model::Registry;
use LANraragi::Utils::Generic  qw(render_api_response exec_with_lock);
use LANraragi::Utils::Logging  qw(get_logger);
use LANraragi::Utils::Registry qw(validate_registry_index);

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

            my ( $registry_id, $error ) = LANraragi::Model::Registry::create_registry( $redis, %config );
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
                    id        => $registry_id,
                    registry  => { id => $registry_id, %config },
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

            my %updated_registry;
            for my $field (qw(name type provider url ref path)) {
                $updated_registry{$field} = $body->{$field} if exists $body->{$field};
            }

            unless (%updated_registry) {
                $redis->quit();
                render_api_response( $self, "update_registry", "Nothing to update." );
                return;
            }

            my ( $status, $indexcleared, $message ) = LANraragi::Model::Registry::update_registry(
                $registry_id, $redis, %updated_registry
            );

            unless ( $status == 200 ) {
                $redis->quit();
                $self->render(
                    openapi => { operation => "update_registry", error => $message, success => 0 },
                    status  => $status
                );
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
                    index_cleared => $indexcleared ? true : false,
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

            my ( $status, $success, $message ) = LANraragi::Model::Registry::delete_registry(
                $registry_id, $redis
            );
            $redis->quit();

            unless ( $status == 200 ) {
                $self->render(
                    openapi => { operation => "delete_registry", error => $message, success => 0 },
                    status  => $status
                );
                return;
            }

            render_api_response( $self, "delete_registry" );
        }
    );
}

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
            my ( $status, $content, $message ) = LANraragi::Model::Registry::fetch_registry_index(
                $type, %config
            );

            unless ( $status == 200 ) {
                $redis->quit();
                $self->render(
                    openapi => { operation => "refresh_registry", error => $message, success => 0 },
                    status  => $status
                );
                return;
            }

            my $index = eval { decode_json($content) };
            if ($@) {
                $redis->quit();
                render_api_response( $self, "refresh_registry", "Invalid registry.json: $@" );
                return;
            }

            my $validation_error = validate_registry_index($index);
            if ($validation_error) {
                $redis->quit();
                render_api_response( $self, "refresh_registry", $validation_error );
                return;
            }

            # Cache the raw JSON under the paired index key
            my ($suffix) = $registry_id =~ /^REG_(\d{10})$/;
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
    my $self                    = shift->openapi->valid_input or return;
    my $body                    = $self->req->json;
    my $namespace               = $body->{namespace};
    my $registry_id             = $body->{registry};
    my $version                 = $body->{version};
    my $installed_channel       = $body->{installed_channel};
    my $force                   = $body->{force} // 0;

    return unless exec_with_lock(
        $self,
        "plugin-write:" . uc($namespace),
        "install_plugin",
        $namespace,
        sub {
            my $redis = $self->LRR_CONF->get_redis_config;

            my $namerds = "LRR_PLUGIN_" . uc($namespace);
            if ( $redis->hexists( $namerds, "installed_path" ) ) {
                my $source     = LANraragi::Model::Registry::infer_plugin_source( $namespace, $redis );
                my $currentreg = $redis->hget( $namerds, "installed_registry" );
                my $currentver = $redis->hget( $namerds, "installed_version" );

                if ( $source ne "managed" ) {
                    # Sideloaded or default plugin: force cannot bypass; user must remove it first.
                    $redis->quit();
                    render_api_response( $self, "install_plugin",
                        "Plugin '$namespace' already exists as a $source plugin. Remove it first before installing from a registry." );
                    return;
                }

                if ( !$force && $currentreg && $currentreg ne $registry_id ) {
                    $redis->quit();
                    render_api_response( $self, "install_plugin",
                        "Plugin '$namespace' already installed from '$currentreg' (v$currentver). Use force to overwrite." );
                    return;
                }
            }

            my $logger = get_logger( "Registry", "lanraragi" );
            my ( $status, $plugmeta, $message ) = eval {
                LANraragi::Model::Registry::install_plugin(
                    $namespace, $registry_id, $version, $installed_channel, $redis
                );
            };
            if ($@) {
                $logger->error("install_plugin failed for '$namespace': $@");
                $redis->quit();
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
                    installed_channel  => $plugmeta->{installed_channel},
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
        "plugin-write:" . uc($namespace),
        "uninstall_plugin",
        $namespace,
        sub {
            my $redis = $self->LRR_CONF->get_redis_config;

            my ( $status, $success, $message ) = LANraragi::Model::Registry::uninstall_plugin(
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
