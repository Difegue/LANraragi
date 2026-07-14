package LANraragi::Controller::Api::Registry;
use Mojo::Base 'Mojolicious::Controller';

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

# create a registry, which can be of provider github, gitea, cdn, or local.
# git providers (github/gitea): require url (https) and ref.
# cdn provider: requires url (http or https base URL).
# local provider: requires path (to local registry directory)
sub create_registry {
    my $self        = shift->openapi->valid_input or return;
    my $body        = $self->req->json;
    my $provider    = $body->{provider};
    my $logger      = get_logger( "Registry", "lanraragi" );
    $logger->info("Create registry requested (provider: " . ( defined $provider ? $provider : "<undef>" ) . ").");

    return unless exec_with_lock(
        $self,
        "registry-create",
        "create_registry",
        "registry",
        sub {
            my $redis = $self->LRR_CONF->get_redis_config;
            my %config = ( name => $body->{name}, provider => $provider );

            if ( $provider eq "github" || $provider eq "gitea" ) {
                $config{url} = $body->{url};
                $config{ref} = $body->{ref};
            } elsif ( $provider eq "cdn" ) {
                $config{url} = $body->{url};
            } elsif ( $provider eq "local" ) {
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
                }
            );
        }
    );
}

# Get registry by its registry ID.
sub get_registry {
    my $self        = shift->openapi->valid_input or return;
    my $registry_id = $self->stash('id');
    my $redis       = $self->LRR_CONF->get_redis_config;

    my ( $registry, $status, $error ) = LANraragi::Model::Registry::get_registry( $registry_id, $redis );
    $redis->quit();

    unless ($registry) {
        $self->render(
            openapi => {
                operation => "get_registry",
                error     => $error,
                success   => 0,
            },
            status => $status
        );
        return;
    }

    $self->render(
        openapi => {
            operation => "get_registry",
            success   => 1,
            error     => "",
            registry  => $registry,
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
            my %updated_registry;
            for my $field (qw(name provider url ref path)) {
                $updated_registry{$field} = $body->{$field} if exists $body->{$field};
            }

            unless ( %updated_registry ) {
                render_api_response( $self, "update_registry", "Nothing to update." );
                return;
            }

            my $redis = $self->LRR_CONF->get_redis_config;
            my ( $status, $error ) = LANraragi::Model::Registry::update_registry(
                $registry_id, $redis, %updated_registry
            );
            $logger->info("Update registry result for '$registry_id': status=$status");
            $redis->quit();

            unless ( $status == 200 ) {
                $logger->warn("Update registry failed for '$registry_id': $error");
                $self->render(
                    openapi => { operation => "update_registry", error => $error, success => 0 },
                    status  => $status
                );
                return;
            }

            $self->render(
                openapi => {
                    operation     => "update_registry",
                    success       => 1,
                    error         => "",
                    id            => $registry_id,
                }
            );
        }
    );
}

# Delete registry by its registry ID.
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
            my ( $status, $error ) = LANraragi::Model::Registry::delete_registry(
                $registry_id, $redis
            );
            $redis->quit();

            unless ( $status == 200 ) {
                $logger->warn("Delete registry failed for '$registry_id': $error");
                $self->render(
                    openapi => { operation => "delete_registry", error => $error, success => 0 },
                    status  => $status
                );
                return;
            }

            render_api_response( $self, "delete_registry" );
        }
    );
}

sub get_ougi {
    my $self  = shift->openapi->valid_input or return;
    my $redis = $self->LRR_CONF->get_redis_config;

    my $registry_id = LANraragi::Model::Registry::get_ougi($redis);
    $redis->quit();

    $self->render(
        openapi => {
            operation   => "get_ougi",
            success     => 1,
            id          => $registry_id,
        }
    );
}

sub update_ougi {
    my $self        = shift->openapi->valid_input or return;
    my $registry_id = $self->stash('id');
    my $logger      = get_logger( "Registry", "lanraragi" );
    $logger->info("Update default registry to '$registry_id' requested.");

    my $redis = $self->LRR_CONF->get_redis_config;
    my ( $status, $reg_id, $message ) =
        LANraragi::Model::Registry::update_ougi( $registry_id, $redis );
    $redis->quit();

    unless ( $status == 200 ) {
        return $self->render(
            openapi => {
                operation   => "update_ougi",
                success     => 0,
                error       => $message,
            },
            status => $status,
        );
    }

    return $self->render(
        openapi => {
            operation   => "update_ougi",
            success     => 1,
            id          => $reg_id,
        },
        status => 200,
    );
}

sub remove_ougi {
    my $self   = shift->openapi->valid_input or return;
    my $logger = get_logger( "Registry", "lanraragi" );
    $logger->info("Remove default registry requested.");

    my $redis       = $self->LRR_CONF->get_redis_config;
    my $registry_id = LANraragi::Model::Registry::remove_ougi($redis);
    $redis->quit();

    return $self->render(
        openapi => {
            operation   => "remove_ougi",
            success     => 1,
            id          => $registry_id,
        }
    );
}

# Refresh registry and return registry.json index.
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
