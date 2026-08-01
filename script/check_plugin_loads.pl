#!/usr/bin/env perl

# Check that a managed plugin artifact loads and satisfies basic type contracts.
#
# Usage:  perl script/check_plugin_loads.pl <plugin-relpath-under-lib>
#   e.g.  perl script/check_plugin_loads.pl LANraragi/Plugin/Managed/Metadata/Foo.pm
#
# Exit codes:
#   0  artifact loads, implements plugin_info(), and the entry point its type requires
#   1  artifact failed to load, or does not satisfy the plugin contract
#   2  usage / bad argument

use strict;
use warnings;
use utf8;

use FindBin;

BEGIN { unshift @INC, "$FindBin::Bin/../lib"; }

use LANraragi::Utils::Path qw(path_to_package);

my $relpath = shift @ARGV;
unless ( defined $relpath && length $relpath ) {
    print STDERR "usage: check_plugin_loads.pl <plugin-relpath-under-lib>\n";
    exit 2;
}

# Load the artifact like a worker
my $loaded = eval { require $relpath; 1 };
unless ($loaded) {
    print STDOUT "PLUGIN_INVALID\n";
    print STDERR "failed to load '$relpath': " . ( $@ || "unknown error" );
    exit 1;
}

# The plugin must implement plugin_info()
my $package = path_to_package($relpath);
unless ( $package && $package->can('plugin_info') ) {
    print STDOUT "PLUGIN_INVALID\n";
    print STDERR "'$relpath' does not implement plugin_info()\n";
    exit 1;
}
my %info = eval { $package->plugin_info() };
if ($@) {
    print STDOUT "PLUGIN_INVALID\n";
    print STDERR "plugin_info() failed for '$relpath': $@";
    exit 1;
}

# The plugin must have the required method corresponding to its plugin type
my %type_method = (
    metadata => 'get_tags',
    download => 'provide_url',
    login    => 'do_login',
    script   => 'run_script',
);
my $type   = $info{type} // '';
my $method = $type_method{$type};
unless ($method) {
    print STDOUT "PLUGIN_INVALID\n";
    print STDERR "'$relpath' declares unknown plugin type '$type'\n";
    exit 1;
}
unless ( $package->can($method) ) {
    print STDOUT "PLUGIN_INVALID\n";
    print STDERR "'$relpath' (type '$type') does not implement '$method'\n";
    exit 1;
}

exit 0;
