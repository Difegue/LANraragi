package LANraragi::Utils::Plugins;

use strict;
use warnings;
use utf8;

use Mojo::JSON qw(decode_json);
use LANraragi::Utils::Database qw(redis_decode);

# Plugin system ahoy - this makes the LANraragi::Utils::Plugins::plugins method available
# Don't call this method directly - Rely on LANraragi::Utils::Plugins::get_plugins instead
use Module::Pluggable require => 1, search_path => ['LANraragi::Plugin'];

# Functions related to the Plugin system.
# This mostly contains the glue for parameters w/ Redis, the meat of Plugin execution is in Model::Plugins.
use Exporter 'import';
our @EXPORT_OK = qw(get_plugins get_plugin get_enabled_plugins get_plugin_parameters is_plugin_enabled);

# Get metadata of all plugins with the defined type. Returns an array of hashes.
sub get_plugins {

    my $type    = shift;
    my @plugins = plugins;
    my @validplugins;
    foreach my $plugin (@plugins) {

        # Check that the metadata sub is there before invoking it
        if ( $plugin->can('plugin_info') ) {
            my %pluginfo = $plugin->plugin_info();
            if ( $pluginfo{type} eq $type || $type eq "all" ) { push( @validplugins, \%pluginfo ); }
        }
    }

    return @validplugins;
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

#Look for a plugin by namespace.
sub get_plugin {

    my $name = shift;

    #Go through plugins to find one with a matching namespace
    my @plugins = plugins;

    foreach my $plugin (@plugins) {
        my $namespace = "";
        eval {
            my %pluginfo = $plugin->plugin_info();
            $namespace = $pluginfo{namespace};
        };

        if ( $name eq $namespace ) {
            return $plugin;
        }
    }

    return 0;
}

# Get the parameters input by the user for thespecified plugin.
# Returns an array of values.
sub get_plugin_parameters {

    my $namespace = shift;

    #Get the matching argument JSON in Redis
    my $redis   = LANraragi::Model::Config->get_redis;
    my $namerds = "LRR_PLUGIN_" . uc($namespace);
    my @args    = ();

    if ( $redis->hexists( $namerds, "enabled" ) ) {
        my $argsjson = $redis->hget( $namerds, "customargs" );
        $argsjson = redis_decode($argsjson);

        #Decode it to an array for proper use
        if ($argsjson) {
            @args = @{ decode_json($argsjson) };
        }
    }
    $redis->quit();
    return @args;
}

sub is_plugin_enabled {

    my $namespace = shift;
    my $redis     = LANraragi::Model::Config->get_redis;
    my $namerds   = "LRR_PLUGIN_" . uc($namespace);

    if ( $redis->hexists( $namerds, "enabled" ) ) {
        return ( $redis->hget( $namerds, "enabled" ) );
    }

    $redis->quit();
    return 0;
}

1;
