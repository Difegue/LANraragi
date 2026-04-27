package LANraragi::Utils::Plugins;

use strict;
use warnings;
use utf8;

use Mojo::JSON                 qw(decode_json);
use LANraragi::Utils::Logging  qw(get_logger);
use LANraragi::Utils::Path     qw(package_to_path);
use LANraragi::Utils::Redis    qw(redis_decode);

# Plugin system ahoy - this makes the LANraragi::Utils::Plugins::plugins method available
# Don't call this method directly - Rely on LANraragi::Utils::Plugins::get_plugins instead
use Module::Pluggable require => 1, search_path => ['LANraragi::Plugin'];

# Per-worker cross-worker coherence state. Each prefork worker maintains its own
# view of which Redis-tracked generation of each plugin namespace it has loaded.
# On upgrade, install_plugin / process_upload bump installed_generation in Redis;
# the next get_plugin call on any worker observes the mismatch and reloads.
# TODO(REVIEW): purpose/explanation of installed_generation
# TODO(REVIEW): purpose/explanation of these constants
# TODO(REVIEW): why are these above Exporter?
my %LOADED_GEN;
my %LOAD_FAILED;

# Functions related to the Plugin system.
# This mostly contains the glue for parameters w/ Redis, the meat of Plugin execution is in Model::Plugins.
use Exporter 'import';
our @EXPORT_OK =
  qw(get_plugins get_downloader_for_url get_plugin get_enabled_plugins get_plugin_parameters is_plugin_enabled is_plugin_hidden get_plugin_priority use_plugin);

# Get metadata of all plugins with the defined type. Returns an array of hashes.
sub get_plugins {

    my $type    = shift;
    my $redis   = LANraragi::Model::Config->get_redis_config;
    my @plugins = plugins;
    my @validplugins;
    my %seen_ns;
    foreach my $plugin (@plugins) {

        # Check that the metadata sub is there before invoking it
        if ( $plugin->can('plugin_info') ) {
            my %pluginfo;
            eval { %pluginfo = $plugin->plugin_info() };
            next if $@; # TODO(REVIEW): silent skipping (variant)

            # Skip plugins which are not registered by Redis.
            my $ns = $pluginfo{namespace};
            unless ( $redis->hexists( "LRR_PLUGIN_" . uc($ns), "installed_path" ) ) {
                # TODO(REVIEW): logging
                next;
            }
            if ( $seen_ns{$ns}++ ) {
                # TODO(REVIEW): logging
                # TODO(REVIEW): can an ns be seen multiple times?
                next;
            }

            if    ( $type eq 'script' )   { next if ( !$plugin->can('run_script') ); }
            elsif ( $type eq 'metadata' ) { next if ( !$plugin->can('get_tags') ); }
            elsif ( $type eq 'download' ) { next if ( !$plugin->can('provide_url') ); }
            elsif ( $type eq 'login' )    { next if ( !$plugin->can('do_login') ); }

            if ( $pluginfo{type} eq $type || $type eq "all" ) { push( @validplugins, \%pluginfo ); }
        } else {
            # TODO(REVIEW): log case where plugin has no plugin_info.
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
    my $redis   = LANraragi::Model::Config->get_redis_config;
    my @enabled;

    foreach my $pluginfo (@plugins) {

        if ( is_plugin_enabled( $pluginfo->{namespace} ) ) {
            $pluginfo->{priority} = get_plugin_priority( $pluginfo->{namespace}, $redis );
            push( @enabled, $pluginfo );
        }
    }

    $redis->quit();

    # Sort by priority (lower = runs first), stable sort preserves discovery order for ties
    @enabled = sort { $a->{priority} <=> $b->{priority} } @enabled;

    return @enabled;
}

#Look for a plugin by uc-normalized namespace.
# TODO(REVIEW): explain how redis is being used.
sub get_plugin {

    my $name = shift;
    my $name_uc = uc($name);

    # Plugin must have a discovered installed_path to be callable.
    # Uninstall hdels installed_path while preserving user config; gating on
    # key-existence alone would let uninstalled namespaces remain callable.
    # TODO(REVIEW): this counts as validation logic; does it belong in get_plugin? Who are the callers
    # it looks more like it should be for plugin invokation?
    my $redis   = LANraragi::Model::Config->get_redis_config;
    my $namerds = "LRR_PLUGIN_" . $name_uc;
    unless ( $redis->hexists( $namerds, "installed_path" ) ) {
        $redis->quit();
        return 0;
    }

    # Cross-worker coherence: managed/sideloaded plugins opt in via installed_generation.
    # Builtins have no generation field and skip the check entirely.
    if ( $redis->hexists( $namerds, "installed_generation" ) ) {
        my $installed_path = $redis->hget( $namerds, "installed_path" );
        my $current_gen    = $redis->hget( $namerds, "installed_generation" );

        if (   $installed_path
            && ( $LOADED_GEN{$name_uc}  // -1 ) != $current_gen
            && ( $LOAD_FAILED{$name_uc} // -1 ) != $current_gen )
        {
            delete $INC{$installed_path};
            my $ok = eval {
                no warnings 'redefine';
                require $installed_path;
                1;
            };
            if ($ok) {
                $LOADED_GEN{$name_uc} = $current_gen;
                delete $LOAD_FAILED{$name_uc};
                get_logger( "Plugin System", "lanraragi" )->info("Reloaded plugin '$name' to generation $current_gen (pid $$)");
            } else {
                # TODO(REVIEW): document when this would trigger
                $LOAD_FAILED{$name_uc} = $current_gen;
                get_logger( "Plugin System", "lanraragi" )->warn("Failed to reload plugin '$name' at generation $current_gen: $@");
            }
        }
    }
    $redis->quit();

    #Go through plugins to find one with a matching namespace
    my @plugins = plugins;

    foreach my $plugin (@plugins) {
        my $namespace = "";
        eval {
            my %pluginfo = $plugin->plugin_info();
            $namespace = $pluginfo{namespace};
        };

        if ( $name_uc eq uc($namespace) ) {
            return $plugin;
        }
    }

    return 0;
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

sub is_plugin_hidden {

    my ( $namespace, $redis ) = @_;
    my $namerds = "LRR_PLUGIN_" . uc($namespace);

    if ( $redis->hexists( $namerds, "hidden" ) ) {
        return $redis->hget( $namerds, "hidden" );
    }

    return 0;
}

sub get_plugin_priority {

    my ( $namespace, $redis ) = @_;
    my $namerds = "LRR_PLUGIN_" . uc($namespace);

    if ( $redis->hexists( $namerds, "priority" ) ) {
        return int( $redis->hget( $namerds, "priority" ) );
    }

    return 0;
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
