package LANraragi::Utils::PluginState;

use strict;
use warnings;
use utf8;

use Exporter 'import';

use LANraragi::Model::Config ();

our @EXPORT_OK = qw(
    signal_updated
    signal_uninstalled
    record_load_success
    record_load_failure
    plugin_needs_reload
    should_skip_reload
);

# For handling various cases related to plugin registration and usability states.

my %LOADED_GEN;
my %LOAD_FAILED;

sub _registered_generation {
    my ($namespace_uc) = @_;

    my $redis   = LANraragi::Model::Config->get_redis_config;
    my $namerds = "LRR_PLUGIN_" . $namespace_uc;

    unless ( $redis->hexists( $namerds, "installed_generation" ) ) {
        $redis->quit();
        return;
    }

    my $generation = $redis->hget( $namerds, "installed_generation" );
    $redis->quit();
    return $generation;
}

# signal_updated( $namespace, $redis )
# If a namespace is updated, the updated survivor should synchronize to all workers.
# Workers must update to the new plugin via INC reload.
# Workers which previously failed to load plugin may re-attempt to load the updated plugin.
sub signal_updated {
    my ( $namespace, $redis ) = @_;
    my $namespace_uc = uc($namespace);
    my $namerds      = "LRR_PLUGIN_" . $namespace_uc;

    $redis->hincrby( $namerds, "installed_generation", 1 );

    delete $LOADED_GEN{$namespace_uc};
    delete $LOAD_FAILED{$namespace_uc};
}

# signal_uninstalled( $namespace, $redis )
# If a namespace is uninstalled, synchronize to all workers.
# Workers may no longer load the plugin even if it is present in INC cache.
sub signal_uninstalled {
    my ( $namespace, $redis ) = @_;
    my $namespace_uc = uc($namespace);
    my $namerds      = "LRR_PLUGIN_" . $namespace_uc;

    $redis->hdel( $namerds, "installed_generation" );

    delete $LOADED_GEN{$namespace_uc};
    delete $LOAD_FAILED{$namespace_uc};
}

# record_load_success( $namespace )
# If a plugin loaded successfully, update local worker cache.
# Future reload attempts for the current registered plugin will be skipped.
sub record_load_success {
    my ($namespace) = @_;
    my $namespace_uc = uc($namespace);
    my $generation   = _registered_generation($namespace_uc);

    return unless defined $generation;

    $LOADED_GEN{$namespace_uc} = $generation;
    delete $LOAD_FAILED{$namespace_uc};
}

# record_load_failure( $namespace )
# If a plugin failed to load, update local worker cache.
# Future attempts to load plugin will be skipped.
sub record_load_failure {
    my ($namespace) = @_;
    my $namespace_uc = uc($namespace);
    my $generation   = _registered_generation($namespace_uc);

    return unless defined $generation;

    $LOAD_FAILED{$namespace_uc} = $generation;
}

# plugin_needs_reload( $namespace )
# Check if a plugin requires a INC-reload.
sub plugin_needs_reload {
    my ($namespace) = @_;
    my $namespace_uc = uc($namespace);
    my $generation   = _registered_generation($namespace_uc);

    return 0 unless defined $generation;

    return ( $LOADED_GEN{$namespace_uc} // -1 ) != $generation;
}

# should_skip_reload( $namespace )
# Check if a plugin failed to load.
# Failure state is reset on plugin updates.
sub should_skip_reload {
    my ($namespace) = @_;
    my $namespace_uc = uc($namespace);
    my $generation   = _registered_generation($namespace_uc);

    return 0 unless defined $generation;

    return ( $LOAD_FAILED{$namespace_uc} // -1 ) == $generation;
}

1;
