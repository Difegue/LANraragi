package LANraragi::Controller::Api::Registry;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON qw(decode_json true false);

use LANraragi::Model::Registry;
use LANraragi::Utils::Generic  qw(render_api_response exec_with_lock);
use LANraragi::Utils::Logging  qw(get_logger);
use LANraragi::Utils::Registry qw(validate_registry_index);

# TODO(REVIEW) evals should cover SPECIFIC logic known to throw a SPECIFIC die(s), not blanket an entire code block.
# furthermore, evals should not be applied/wrapped over Model-layer subs. Instead, the eval should drop to Model (and Model should handle failures more gracefully) instead.
# logic-specific eval failures should be accompanied with error logging that identifies where the logic failed.
# See Api/Archive.pm. (variants)

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

            # TODO(REVIEW) eval too broad.
            eval {
                my %config = ( name => $body->{name}, type => $type );

                if ( $type eq "git" ) {
                    $config{provider} = $body->{provider};
                    $config{url}      = $body->{url};
                    $config{ref}      = $body->{ref} // "main";
                } elsif ( $type eq "local" ) {
                    $config{path} = $body->{path};
                }

                my ( $registry_id, $error ) = LANraragi::Model::Registry::create_registry( \%config, $redis );

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
            };
            my $err = $@;
            $redis->quit();
            die $err if $err; # TODO(REVIEW): check dev branch consistency on end of controller error handling
            # TODO(REVIEW) reachability + use error logging instead, this is at the end of the logic anyways
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

            # TODO(REVIEW) eval too broad.
            eval {
                my %updated_registry;
                for my $field (qw(name type provider url ref path)) {
                    $updated_registry{$field} = $body->{$field} if exists $body->{$field};
                }

                unless ( %updated_registry ) {
                    render_api_response( $self, "update_registry", "Nothing to update." );
                    return;
                }

                my ( $status, $indexcleared, $message ) = LANraragi::Model::Registry::update_registry(
                    $registry_id, $redis, %updated_registry
                );
                $logger->info("Update registry result for '$registry_id': status=$status, index_cleared=$indexcleared");

                # TODO(REVIEW): check dev branch status check consistency (and all variants)
                unless ( $status == 200 ) {
                    $logger->warn("Update registry failed for '$registry_id': $message");
                    $self->render(
                        openapi => { operation => "update_registry", error => $message, success => 0 },
                        status  => $status
                    );
                    return;
                }

                # TODO(REVIEW): why does registry need to be retrieved, instead of retrieving it from update_registry?
                my %registry = LANraragi::Model::Registry::get_registry( $registry_id, $redis );

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
            };
            my $err = $@;
            $redis->quit();
            die $err if $err; # TODO(REVIEW) ditto
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

            # TODO(REVIEW) eval too broad (and is it necesary i.e. actually can die?) clearly doesn't need render.
            eval {
                # TODO(REVIEW) 'message' is misleading, this is an error?
                my ( $status, $success, $message ) = LANraragi::Model::Registry::delete_registry(
                    $registry_id, $redis
                );

                unless ( $status == 200 ) {
                    $logger->warn("Delete registry failed for '$registry_id': $message");
                    $self->render(
                        openapi => { operation => "delete_registry", error => $message, success => 0 },
                        status  => $status
                    );
                    return;
                }

                render_api_response( $self, "delete_registry" );
            };
            my $err = $@;
            $redis->quit();
            die $err if $err; # TODO(REVIEW) ditto
        }
    );
}

# TODO(REVIEW) most of this logic doesn't belong in controller.
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

            # TODO(REVIEW) eval too broad.
            eval {
                my %config = LANraragi::Model::Registry::get_registry( $registry_id, $redis );

                unless (%config) {
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

                my ( $status, $registry_content, $message ) = LANraragi::Model::Registry::fetch_registry_index(
                    %config
                );

                unless ( $status == 200 ) {
                    $self->render(
                        openapi => { operation => "refresh_registry", error => $message, success => 0 },
                        status  => $status
                    );
                    return;
                }

                my $registry_index = eval { decode_json($registry_content) };
                if ($@) {
                    render_api_response( $self, "refresh_registry", "Invalid registry.json: $@" );
                    return;
                }

                # TODO(REVIEW) this logic does not belong in the Controller.
                my $validation_error = validate_registry_index($registry_index);
                if ($validation_error) {
                    render_api_response( $self, "refresh_registry", $validation_error );
                    return;
                }

                # TODO(REVIEW) this logic does not belong in the Controller.
                # Cache the raw JSON under the paired index key
                my ($suffix) = $registry_id =~ /^REG_(\d{10})$/;
                my $registry_index_key = "REG_INDEX_$suffix";

                # TODO(REVIEW) this logic does not belong in the Controller.
                # Spec-contract checks against the previously cached index, if any.
                # Removed versions and cross-refresh type changes are publisher-contract
                # violations the spec asks LRR to surface where practical.
                my $previous_registry_content = $redis->get($registry_index_key);
                if ( defined $previous_registry_content && $previous_registry_content ne "" ) {
                    my $previous_registry_index = eval { decode_json($previous_registry_content) };
                    if ($@) {
                        $logger->warn("Registry '$registry_id': cached previous registry index could not be decoded: $@");
                    }
                    if ( ref $previous_registry_index eq "HASH" && ref $previous_registry_index->{plugins} eq "HASH" ) {
                        my $previous_plugin_map = $previous_registry_index->{plugins};
                        my $current_plugin_map  = $registry_index->{plugins};
                        foreach my $ns ( sort keys %{$previous_plugin_map} ) {
                            unless ( exists $current_plugin_map->{$ns} ) {
                                $logger->warn("Registry $registry_id: plugin '$ns' removed from registry");
                                next;
                            }
                            if (   defined $previous_plugin_map->{$ns}{type}
                                && defined $current_plugin_map->{$ns}{type}
                                && $previous_plugin_map->{$ns}{type} ne $current_plugin_map->{$ns}{type} ) {
                                $logger->warn(
                                    "Registry $registry_id: plugin '$ns' type changed from '$previous_plugin_map->{$ns}{type}' to '$current_plugin_map->{$ns}{type}' (spec invariant violation)"
                                );
                            }
                            my $previous_plugin_versions = $previous_plugin_map->{$ns}{versions} || {};
                            my $current_plugin_versions  = $current_plugin_map->{$ns}{versions} || {};
                            foreach my $ver ( sort keys %{$previous_plugin_versions} ) {
                                unless ( exists $current_plugin_versions->{$ver} ) {
                                    $logger->warn("Registry $registry_id: plugin '$ns' version '$ver' removed from registry");
                                }
                            }
                        }
                    }
                }

                $redis->set( $registry_index_key, $registry_content );

                $self->render(
                    openapi => {
                        operation => "refresh_registry",
                        success   => 1,
                        index     => $registry_index,
                    }
                );
            };
            my $err = $@;
            $redis->quit();
            die $err if $err; # TODO(REVIEW) ditto
        }
    );
}

1;
