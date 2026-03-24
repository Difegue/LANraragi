package LANraragi::Utils::PluginState;

use strict;
use warnings;
use utf8;

use Exporter 'import';

our @EXPORT_OK = qw(
    signal_updated
    signal_uninstalled
    record_load_success
    record_load_failure
    plugin_needs_reload
    should_skip_reload
);

# Utilities for handling various cases related to plugin registration and usability states.
# When a plugin is added/removed from LRR, its status must be synchronized across workers.

my %LOADED_GEN;
my %LOAD_FAILED;

# signal_updated( $redis, $namespace )
# If a namespace is updated, the updated survivor should synchronize to all workers.
# Workers must update to the new plugin via INC reload.
# Workers which previously failed to load plugin may re-attempt to load the updated plugin.
sub signal_updated {
    my ( $redis, $namespace ) = @_;
    my $namespace_uc    = uc($namespace);
    my $namerds         = "LRR_PLUGIN_" . $namespace_uc;

    $redis->hincrby( $namerds, "installed_generation", 1 );

    delete $LOADED_GEN{$namespace_uc};
    delete $LOAD_FAILED{$namespace_uc};
}

# signal_uninstalled( $redis, $namespace )
# If a namespace is uninstalled, synchronize to all workers.
# Workers may no longer load the plugin even if it is present in INC cache, and are expected to drop the plugin from cache.
sub signal_uninstalled {
    my ( $redis, $namespace ) = @_;
    my $namespace_uc    = uc($namespace);
    my $namerds         = "LRR_PLUGIN_" . $namespace_uc;

    $redis->hdel( $namerds, "installed_generation" );

    delete $LOADED_GEN{$namespace_uc};
    delete $LOAD_FAILED{$namespace_uc};
}

# record_load_success( $redis, $namespace )
# If a plugin loaded successfully, update local worker cache.
# Future reload attempts for the current registered plugin will be skipped.
sub record_load_success {
    my ( $redis, $namespace ) = @_;
    my $namespace_uc = uc($namespace);
    my $generation   = _registered_generation( $namespace_uc, $redis );

    return unless defined $generation;

    $LOADED_GEN{$namespace_uc} = $generation;
    delete $LOAD_FAILED{$namespace_uc};
}

# record_load_failure( $redis, $namespace )
# If a plugin failed to load, update local worker cache.
# Future attempts to load plugin will be skipped.
sub record_load_failure {
    my ( $redis, $namespace ) = @_;
    my $namespace_uc = uc($namespace);
    my $generation   = _registered_generation( $namespace_uc, $redis );

    return unless defined $generation;

    $LOAD_FAILED{$namespace_uc} = $generation;
}

# plugin_needs_reload( $redis, $namespace )
# Check if a plugin requires a INC-reload.
sub plugin_needs_reload {
    my ( $redis, $namespace ) = @_;
    my $namespace_uc = uc($namespace);
    my $generation   = _registered_generation( $namespace_uc, $redis );

    return 0 unless defined $generation;

    return ( $LOADED_GEN{$namespace_uc} // -1 ) != $generation;
}

# should_skip_reload( $redis, $namespace )
# Check if a plugin failed to load.
# Failure state is reset on plugin updates.
sub should_skip_reload {
    my ( $redis, $namespace ) = @_;
    my $namespace_uc = uc($namespace);
    my $generation   = _registered_generation( $namespace_uc, $redis );

    return 0 unless defined $generation;

    return ( $LOAD_FAILED{$namespace_uc} // -1 ) == $generation;
}

sub _registered_generation {
    my ( $namespace_uc, $redis ) = @_;

    my $namerds = "LRR_PLUGIN_" . $namespace_uc;

    return unless $redis->hexists( $namerds, "installed_generation" );
    return $redis->hget( $namerds, "installed_generation" );
}

1;
