package LANraragi::Controller::Api::Registry;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON qw(true false);

use LANraragi::Model::Registry;
use LANraragi::Utils::Generic  qw(render_api_response exec_with_lock);
use LANraragi::Utils::Logging  qw(get_logger);

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

# create a registry, which can be of type either git or local.
# git type: requires provider, url, ref (default "main").
# local type: requires path (to local registry.json)
sub create_registry {
    my $self    = shift->openapi->valid_input or return;
    my $body    = $self->req->json;
    my $type    = $body->{type};
    my $logger  = get_logger( "Registry", "lanraragi" );
    $logger->info("Create registry requested (type: " . ( defined $type ? $type : "<undef>" ) . ").");

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

            my ( $registry_id, $error ) = LANraragi::Model::Registry::create_registry( \%config, $redis );
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

# Update a registry by its ID.
# The registry must exist (otherwise, use create_registry)
sub update_registry {
    my $self        = shift->openapi->valid_input or return;
    my $registry_id = $self->stash('id');
    my $body        = $self->req->json;
    my $logger      = get_logger( "Registry", "lanraragi" );
    $logger->info("Update registry requested for '$registry_id'.");

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

            unless ( %updated_registry ) {
                $redis->quit();
                render_api_response( $self, "update_registry", "Nothing to update." );
                return;
            }

            my ( $status, $indexcleared, $message ) = LANraragi::Model::Registry::update_registry(
                $registry_id, $redis, %updated_registry
            );
            $logger->info("Update registry result for '$registry_id': status=$status, index_cleared=$indexcleared");

            # TODO(REVIEW): check dev branch status check consistency (and all variants)
            unless ( $status == 200 ) {
                $redis->quit();
                $logger->warn("Update registry failed for '$registry_id': $message");
                $self->render(
                    openapi => { operation => "update_registry", error => $message, success => 0 },
                    status  => $status
                );
                return;
            }

            # TODO(REVIEW): why does registry need to be retrieved, instead of retrieving it from update_registry?
            my %registry = LANraragi::Model::Registry::get_registry( $registry_id, $redis );
            $redis->quit();

            $self->render(
                openapi => {
                    operation     => "update_registry",
                    success       => 1,
                    error         => "",
                    id            => $registry_id,
                    registry      => \%registry,                    # TODO(REVIEW): why ref here
                    index_cleared => $indexcleared ? true : false,  # TODO(REVIEW): why fallback (variants)
                }
            );
        }
    );
}

sub delete_registry {
    my $self        = shift->openapi->valid_input or return;
    my $registry_id = $self->stash('id');
    my $logger      = get_logger( "Registry", "lanraragi" );
    $logger->info("Delete registry requested for '$registry_id'.");

    return unless exec_with_lock(
        $self,
        "registry-write:$registry_id",
        "delete_registry",
        $registry_id,
        sub {
            my $redis = $self->LRR_CONF->get_redis_config;
            # TODO(REVIEW) 'message' is misleading, this is an error?
            my ( $status, $success, $message ) = LANraragi::Model::Registry::delete_registry(
                $registry_id, $redis
            );
            $redis->quit();

            unless ( $status == 200 ) {
                $logger->warn("Delete registry failed for '$registry_id': $message");
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

sub get_default_registry {
    my $self  = shift->openapi->valid_input or return;
    my $redis = $self->LRR_CONF->get_redis_config;

    my $registry_id = LANraragi::Model::Registry::get_default_registry($redis);
    $redis->quit();

    $self->render(
        openapi => {
            operation   => "get_default_registry",
            success     => 1,
            registry_id => $registry_id,
        }
    );
}

sub update_default_registry {
    my $self        = shift->openapi->valid_input or return;
    my $registry_id = $self->stash('id');
    my $logger      = get_logger( "Registry", "lanraragi" );
    $logger->info("Update default registry to '$registry_id' requested.");

    return unless exec_with_lock(
        $self,
        "registry-default-write",
        "update_default_registry",
        "default_registry",
        sub {
            my $redis = $self->LRR_CONF->get_redis_config;
            my ( $status, $reg_id, $message ) =
                LANraragi::Model::Registry::update_default_registry( $registry_id, $redis );
            $redis->quit();

            unless ( $status == 200 ) {
                $self->render(
                    openapi => {
                        operation   => "update_default_registry",
                        success     => 0,
                        registry_id => $reg_id,
                        error       => $message,
                    },
                    status => $status,
                );
                return;
            }

            $self->render(
                openapi => {
                    operation   => "update_default_registry",
                    success     => 1,
                    registry_id => $reg_id,
                },
                status => 200,
            );
        }
    );
}

sub remove_default_registry {
    my $self   = shift->openapi->valid_input or return;
    my $logger = get_logger( "Registry", "lanraragi" );
    $logger->info("Remove default registry requested.");

    return unless exec_with_lock(
        $self,
        "registry-default-write",
        "remove_default_registry",
        "default_registry",
        sub {
            my $redis       = $self->LRR_CONF->get_redis_config;
            my $registry_id = LANraragi::Model::Registry::remove_default_registry($redis);
            $redis->quit();

            $self->render(
                openapi => {
                    operation   => "remove_default_registry",
                    success     => 1,
                    registry_id => $registry_id,
                }
            );
        }
    );
}

sub refresh_registry {
    my $self        = shift->openapi->valid_input or return;
    my $registry_id = $self->stash('id');
    my $logger      = get_logger( "Registry", "lanraragi" );
    $logger->info("Refresh registry requested for '$registry_id'.");

    return unless exec_with_lock(
        $self,
        "registry-write:$registry_id",
        "refresh_registry",
        $registry_id,
        sub {
            my $redis = $self->LRR_CONF->get_redis_config;
            my ( $status, $registry_index, $message ) = LANraragi::Model::Registry::refresh_registry(
                $registry_id, $redis
            );
            $redis->quit();

            unless ( $status == 200 ) {
                $self->render(
                    openapi => { operation => "refresh_registry", error => $message, success => 0 },
                    status  => $status
                );
                return;
            }

            $self->render(
                openapi => {
                    operation => "refresh_registry",
                    success   => 1,
                    index     => $registry_index,
                }
            );
        }
    );
}

1;
