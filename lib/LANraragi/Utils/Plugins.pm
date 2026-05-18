package LANraragi::Utils::Plugins;

use strict;
use warnings;
use utf8;

use Mojo::JSON                 qw(decode_json);
use LANraragi::Utils::Logging  qw(get_logger);
use LANraragi::Utils::PluginState qw(
    plugin_needs_reload
    record_load_failure
    record_load_success
    should_skip_reload
);
use LANraragi::Utils::Path     qw(path_to_package);
use LANraragi::Utils::Redis    qw(redis_decode);

# Plugin system ahoy - this makes the LANraragi::Utils::Plugins::plugins method available
# Don't call this method directly - Rely on LANraragi::Utils::Plugins::get_plugins instead
use Module::Pluggable require => 1, search_path => ['LANraragi::Plugin'];

# Functions related to the Plugin system.
# This mostly contains the glue for parameters w/ Redis, the meat of Plugin execution is in Model::Plugins.
use Exporter 'import';
our @EXPORT_OK =
  qw(get_plugins get_downloader_for_url get_plugin get_enabled_plugins get_plugin_parameters is_plugin_enabled use_plugin register_plugin unregister_plugin read_registered_plugins);

# Get metadata of all registered plugins with the defined type. Returns an array of hashes.
sub get_plugins {

    my $type    = shift;
    my $redis   = LANraragi::Model::Config->get_redis_config;
    my $logger  = get_logger( "Plugin System", "lanraragi" );
    my %registered = read_registered_plugins($redis);
    my @validplugins;

    # Skip plugins which are not registered by Redis.
    foreach my $ns_uc ( sort keys %registered ) {
        my $installed_path = $registered{$ns_uc};
        my $plugin         = path_to_package($installed_path);

        if ( plugin_needs_reload( $redis, $ns_uc ) && !should_skip_reload( $redis, $ns_uc ) ) {
            delete $INC{$installed_path};
        }

        my $loaded = eval {
            no warnings 'redefine';
            require $installed_path;
            1;
        };
        unless ($loaded) {
            record_load_failure( $redis, $ns_uc );
            $logger->warn("Skipping plugin '$plugin' while listing type '$type': require '$installed_path' failed: $@");
            next;
        }
        record_load_success( $redis, $ns_uc );

        # Check that the metadata sub is there before invoking it
        if ( $plugin->can('plugin_info') ) {
            my %pluginfo;
            eval { %pluginfo = $plugin->plugin_info() };
            if ($@) {
                $logger->warn("Skipping plugin '$plugin' while listing type '$type': plugin_info() failed: $@");
                next;
            }

            if    ( $type eq 'script' )   { next if ( !$plugin->can('run_script') ); }
            elsif ( $type eq 'metadata' ) { next if ( !$plugin->can('get_tags') ); }
            elsif ( $type eq 'download' ) { next if ( !$plugin->can('provide_url') ); }
            elsif ( $type eq 'login' )    { next if ( !$plugin->can('do_login') ); }

            if ( $pluginfo{type} eq $type || $type eq "all" ) { push( @validplugins, \%pluginfo ); }
        } else {
            $logger->warn("Skipping plugin '$plugin' while listing type '$type': class has no plugin_info().");
        }
    }

    $redis->quit();
    return @validplugins;
}

# Get a downloader plugin matching the given URL.
# Returns undef if no plugin matches.
sub get_downloader_for_url {

    my $url     = shift;
    my $logger  = get_logger( "File Upload/Download", "lanraragi" );
    my @plugins = get_plugins("download");

    foreach my $pluginfo (@plugins) {

        my $regex = $pluginfo->{url_regex};

        $logger->debug("Matching $url to /$regex/");

        if ( $url =~ m/$regex/ ) {
            return $pluginfo;
        }
    }
    return;
}

sub get_enabled_plugins {

    my $type    = shift;
    my @plugins = get_plugins($type);
    my @enabled;

    foreach my $pluginfo (@plugins) {

        if ( is_plugin_enabled( $pluginfo->{namespace} ) ) {
            push( @enabled, $pluginfo );
        }
    }
    return @enabled;
}

# Look for (and optionally reloads) a registered plugin by uc-normalized namespace for invokation.
sub get_plugin {

    my $name    = shift;
    my $name_uc = uc($name);
    my $logger  = get_logger( "Plugin System", "lanraragi" );

    # Plugin must have a discovered installed_path to be callable.
    # Uninstall hdels installed_path while preserving user config; gating on
    # key-existence alone would let uninstalled namespaces remain callable.
    my $redis          = LANraragi::Model::Config->get_redis_config;
    my $installed_path = read_registered_plugin_path( $redis, $name );
    unless ($installed_path) {
        $redis->quit();
        return 0;
    }

    # Check if plugin needs (re)loading.
    if ( plugin_needs_reload( $redis, $name_uc ) && !should_skip_reload( $redis, $name_uc ) ) {
        delete $INC{$installed_path};
        my $ok = eval {
            no warnings 'redefine';
            require $installed_path;
            1;
        };
        if ($ok) {
            record_load_success( $redis, $name_uc );
            $logger->info("Reloaded plugin '$name' in worker $$");
        } else {
            record_load_failure( $redis, $name_uc );
            $logger->warn("Failed to reload plugin '$name': $@");
            $redis->quit();
            return 0;
        }
    }

    $redis->quit();
    return path_to_package($installed_path);
}

# Get the parameters for the specified plugin, either default values or input by the user in the settings page.
# Returns an array of values.
sub get_plugin_parameters {

    my $namespace = shift;

    # Get the matching argument JSON in Redis
    my $redis   = LANraragi::Model::Config->get_redis_config;
    my $namerds = "LRR_PLUGIN_" . uc($namespace);

    my $plugin   = get_plugin($namespace);
    my %pluginfo = $plugin->plugin_info();

    my %args;

    if ( ref( $pluginfo{parameters} ) eq 'ARRAY' ) {

        my @args;

        # Fill with default values first
        foreach my $param ( @{ $pluginfo{parameters} } ) {
            push( @args, $param->{default_value} );
        }

        # Replace with saved values if they exist
        if ( $redis->hexists( $namerds, "enabled" ) ) {
            # We don't decode this value in case there's UTF8 characters in plugin config.
            my $saved_config = $redis->hget( $namerds, "customargs" );

            #Decode it to an array for proper use
            if ($saved_config) {
                @args = @{ decode_json($saved_config) };
            }
        }
        $args{customargs} = \@args;

    } elsif ( ref( $pluginfo{parameters} ) eq 'HASH' ) {

        # Fill with default values first
        %args = map { $_ => $pluginfo{parameters}{$_}{default_value} } keys %{ $pluginfo{parameters} };

        my %params = $redis->hgetall($namerds);

        # TODO: param conversion block, remove after deprecation period
        if ( $pluginfo{to_named_params} && exists $params{customargs} ) {
            %params = convert_to_named_params_and_persist( $redis, $namerds, $pluginfo{to_named_params}, %params );
        } elsif ( exists $params{customargs} && !$pluginfo{to_named_params} ) {
            my $logger = get_logger( "Plugin System", "lanraragi" );
            $logger->warn( 'An old configuration for the plugin "'
                  . $pluginfo{name}
                  . '" was detected, but the plugin version you are using does not specify the conversion key "to_named_params"'
                  . ' required for the upgrade. This will cause the old configuration to be lost when saving.' );
            $logger->warn( 'customargs => ' . redis_decode( $redis->hget( $namerds, "customargs" ) ) );
        }

        while ( my ( $key, $value ) = each %params ) {
            $args{$key} = redis_decode($value);
        }

    }

    $redis->quit();
    return %args;
}

# Register a validated plugin into the database.
# A plugin should be registered after any type of discovery or installation,
sub register_plugin {
    my $redis           = shift;
    my $namespace       = shift;
    my $installed_path  = shift;
    my $type            = shift;

    my $namerds = "LRR_PLUGIN_" . uc($namespace);

    $redis->hset( $namerds, "installed_path", $installed_path, "type", $type );

    return $installed_path;
}

# Unregister a registered plugin from the database.
# Should be called during removal of a plugin or when the plugin
# could no longer be found.
sub unregister_plugin {
    my $redis       = shift;
    my $namespace   = shift;
    my $namerds     = "LRR_PLUGIN_" . uc($namespace);

    $redis->hdel(
        $namerds,
        "installed_path",
        "installed_version",
        "installed_registry",
        "installed_sha256",
        "type",
    );
}

# Return a map of namespace -> installed_path of all registered plugins.
sub read_registered_plugins {
    my $redis   = shift;

    my @keys    = $redis->keys("LRR_PLUGIN_*");
    my %registered;
    foreach my $key (@keys) {
        next unless $redis->hexists( $key, "installed_path" );
        my ($namespace_uc) = $key =~ /^LRR_PLUGIN_(.+)$/;
        next unless defined $namespace_uc;
        $registered{$namespace_uc} = $redis->hget( $key, "installed_path" );
    }

    return %registered;
}

# Return the installed_path for a registered plugin.
sub read_registered_plugin_path {
    my $redis       = shift;
    my $namespace   = shift;

    my $namerds = "LRR_PLUGIN_" . uc($namespace);
    return unless $redis->hexists( $namerds, "installed_path" );
    return $redis->hget( $namerds, "installed_path" );
}

sub is_plugin_enabled {

    my $namespace = shift;
    my $redis     = LANraragi::Model::Config->get_redis_config;
    my $namerds   = "LRR_PLUGIN_" . uc($namespace);

    my $enabled = 0;
    if ( $redis->hexists( $namerds, "enabled" ) ) {
        $enabled = $redis->hget( $namerds, "enabled" );
    }

    $redis->quit();
    return $enabled;
}

# Shorthand method to use a plugin by name.
sub use_plugin {

    my ( $plugname, $id, $input ) = @_;

    my $plugin = get_plugin($plugname);
    my %plugin_result;
    my %pluginfo;

    if ( !$plugin ) {
        $plugin_result{error} = "Plugin not found on system.";
    } else {
        %pluginfo = $plugin->plugin_info();

        # Get the plugin settings in Redis
        my %settings = get_plugin_parameters($plugname);
        $settings{oneshot} = $input;

        # Execute the plugin, appending the custom args at the end
        if ( $pluginfo{type} eq "script" ) {
            %plugin_result = LANraragi::Model::Plugins::exec_script_plugin( $plugin, %settings );
        } elsif ( $pluginfo{type} eq "metadata" ) {
            %plugin_result = LANraragi::Model::Plugins::exec_metadata_plugin( $plugin, $id, %settings );
        }

        # Decode the error value if there's one to avoid garbled characters
        if ( exists $plugin_result{error} ) {
            $plugin_result{error} = redis_decode( $plugin_result{error} );
        }
    }

    return ( \%pluginfo, \%plugin_result );
}

sub convert_to_named_params_and_persist {
    my ( $redis, $namerds, $old_params_order, %params ) = @_;
    my $customargs = redis_decode( $params{customargs} );
    my $logger     = get_logger( "Plugin System", "lanraragi" );

    $logger->info("converting $namerds to named parameters ...");

    #Decode it to an array for proper use
    if ($customargs) {
        my @args = @{ decode_json($customargs) };
        while ( my ( $idx, $key ) = each @{$old_params_order} ) {
            $params{$key} = $args[$idx];
            $redis->hset( $namerds, $key, $params{$key} );
        }
        $logger->info("conversion completed: removing 'customargs' value");
        $redis->hdel( $namerds, 'customargs' );
        delete $params{customargs};
    }

    return %params;
}

1;
