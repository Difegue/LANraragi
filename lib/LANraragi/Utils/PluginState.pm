package LANraragi::Utils::PluginState;

use strict;
use warnings;
use utf8;

# For handling various cases related to plugin registration and usability states.

# signal_updated( $namespace )
# If a namespace is updated, the updated survivor should synchronize to all workers.
# Workers must update to the new plugin via INC reload.
# Workers which previously failed to load plugin may re-attempt to load the updated plugin.
sub signal_updated {

}

# signal_uninstalled( $namespace )
# If a namespace is uninstalled, synchronize to all workers.
# Workers may no longer load the plugin even if it is present in INC cache.
sub signal_uninstalled {

}

# record_load_failure( $namespace )
# If a plugin failed to load, update local worker cache.
# Future attempts to load plugin will be skipped.
sub record_load_failure {
    
}

# plugin_needs_reload( $namespace )
# Check if a plugin requires a INC-reload.
sub plugin_needs_reload {

}

# should_skip_reload( $namespace )
# Check if a plugin failed to load.
# Failure state is reset on plugin updates.
sub should_skip_reload {

}

1;
