package LANraragi::Controller::Api::Registry;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON qw(decode_json);

use LANraragi::Model::Registry;
use LANraragi::Utils::Generic qw(render_api_response);

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
    }

    if ( $type eq "local" ) {
        unless ( $body->{path} ) {
            render_api_response( $self, "set_registry", "Missing required field 'path' for local registry." );
            return;
        }
    }

    my $redis = $self->LRR_CONF->get_redis_config;

    # Clear existing registry config before setting new one
    $redis->del("LRR_REGISTRY");

    $redis->hset( "LRR_REGISTRY", "type", $type );

    if ( $type eq "git" ) {
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

sub delete_registry {
    my $self    = shift->openapi->valid_input or return;
    my $redis   = $self->LRR_CONF->get_redis_config;

    $redis->del("LRR_REGISTRY");
    $redis->del("LRR_REGISTRY_INDEX");
    $redis->quit();

    render_api_response( $self, "delete_registry" );
}

sub refresh_registry {
    my $self    = shift->openapi->valid_input or return;
    my $redis   = $self->LRR_CONF->get_redis_config;

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

sub install_plugin {
    my $self        = shift->openapi->valid_input or return;
    my $body        = $self->req->json;
    my $namespace   = $body->{namespace};

    unless ($namespace) {
        render_api_response( $self, "install_plugin", "Missing required field 'namespace'." );
        return;
    }

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

sub uninstall_plugin {
    my $self        = shift->openapi->valid_input or return;
    my $namespace   = $self->stash('plugin_namespace');
    my $redis       = $self->LRR_CONF->get_redis_config;

    my ( $success, $error ) = LANraragi::Model::Registry::uninstall_plugin( $namespace, $redis );
    $redis->quit();

    if ($error) {
        render_api_response( $self, "uninstall_plugin", $error );
        return;
    }

    render_api_response( $self, "uninstall_plugin" );
}

sub hide_plugin {
    my $self        = shift->openapi->valid_input or return;
    my $namespace   = $self->stash('plugin_namespace');
    my $redis       = $self->LRR_CONF->get_redis_config;
    my $namerds = "LRR_PLUGIN_" . uc($namespace);

    $redis->hset( $namerds, "hidden", "1" );
    $redis->quit();

    render_api_response( $self, "hide_plugin" );
}

sub unhide_plugin {
    my $self        = shift->openapi->valid_input or return;
    my $namespace   = $self->stash('plugin_namespace');
    my $redis       = $self->LRR_CONF->get_redis_config;
    my $namerds     = "LRR_PLUGIN_" . uc($namespace);

    $redis->hset( $namerds, "hidden", "0" );
    $redis->quit();

    render_api_response( $self, "unhide_plugin" );
}

1;
