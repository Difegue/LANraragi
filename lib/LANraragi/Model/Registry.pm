package LANraragi::Model::Registry;

use strict;
use warnings;
use utf8;

use Cwd qw(abs_path getcwd);
use Digest::SHA qw(sha256_hex);
use File::Copy;
use File::Path qw(make_path);
use Mojo::JSON qw(decode_json);
use Mojo::UserAgent;

use LANraragi::Utils::Logging  qw(get_logger);
use LANraragi::Utils::Plugins  qw();
use LANraragi::Utils::Registry qw(resolve_git_raw_url find_package_conflict find_namespace_conflict MANAGED_TYPE_DIRS);

# Source fields that, when changed, invalidate the cached index.
my @SOURCE_FIELDS = qw(type provider url ref path);

# Fields valid per registry type.
my %TYPE_FIELDS = (
    git   => [qw(name type provider url ref)],
    local => [qw(name type path)],
);

# Fields that must be removed when switching types.
my %STALE_FIELDS = (
    git   => [qw(path)],
    local => [qw(provider url ref)],
);

# Create a registry entry with a generated REG_{timestamp} ID.
# Returns ( $regid, undef ) or ( undef, $error_message ).
sub create_registry {
    my ( $redis, %config ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );

    # TODO: remove with multi-registry.
    # Single-registry enforcement
    my @existing = $redis->keys("REG_??????????");
    if (@existing) {
        return ( undef, "Only one registry is supported -- remove the existing one first." );
    }

    my $regid = "REG_" . time();
    my $isnewkey = 0;
    until ($isnewkey) {

        # Check if the registry ID exists, move timestamp further if it does
        if ( $redis->exists($regid) ) {
            $regid = "REG_" . ( time() + 1 );
        } else {
            $isnewkey = 1;
        }
    }

    # Store config fields
    my $type = $config{type};
    my @valid_fields = @{ $TYPE_FIELDS{$type} };

    foreach my $field (@valid_fields) {
        next unless defined $config{$field};
        $redis->hset( $regid, $field, $config{$field} );
    }

    $logger->info("Created registry '$regid' (name: $config{name}, type: $type)");

    return ( $regid, undef );
}

# Get a registry's config by ID.
sub get_registry {
    my ( $regid, $redis ) = @_;

    return () unless $regid =~ /^REG_\d{10}$/ && $redis->exists($regid);

    my %config = $redis->hgetall($regid);
    $config{id} = $regid;

    return %config;
}

# List all registries.
sub get_registry_list {
    my ($redis) = @_;

    my @keys = $redis->keys("REG_??????????");
    my @result;

    foreach my $key ( sort @keys ) {
        my %config = get_registry( $key, $redis );
        push @result, \%config if %config;
    }

    return @result;
}

# Update mutable fields on an existing registry.
sub update_registry {
    my ( $regid, $redis, %updates ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );

    unless ( $regid =~ /^REG_\d{10}$/ && $redis->exists($regid) ) {
        return ( undef, "This registry doesn't exist." );
    }

    my %current = $redis->hgetall($regid);

    # Determine if source fields are changing
    my $indexcleared = 0;
    foreach my $field (@SOURCE_FIELDS) {
        next unless exists $updates{$field};
        if ( !defined $current{$field} || $current{$field} ne $updates{$field} ) {
            $indexcleared = 1;
            last;
        }
    }

    # Validate type enum if changing
    my $type = $updates{type} // $current{type};
    unless ( $type eq "git" || $type eq "local" ) {
        return ( undef, "Invalid type '$type' -- must be git or local." );
    }

    # Validate resulting config has required fields for the target type
    my %merged = ( %current, %updates );

    if ( $type eq "git" ) {
        return ( undef, "Git registry needs a URL." )      unless $merged{url};
        return ( undef, "Git registry needs a provider." ) unless $merged{provider};
    } elsif ( $type eq "local" ) {
        return ( undef, "Local registry needs a path." ) unless $merged{path};
    }

    # Handle type change: remove stale fields (after validation passes)
    if ( exists $updates{type} && $updates{type} ne ( $current{type} // "" ) ) {
        my @to_remove = @{ $STALE_FIELDS{$type} };
        foreach my $field (@to_remove) {
            $redis->hdel( $regid, $field );
        }
    }

    # Apply updates
    my @valid_fields = @{ $TYPE_FIELDS{$type} };
    my %valid_set    = map { $_ => 1 } @valid_fields;

    foreach my $field ( keys %updates ) {
        next unless $valid_set{$field};
        $redis->hset( $regid, $field, $updates{$field} );
    }

    # Clear cached index if source changed
    if ($indexcleared) {
        my ($suffix) = $regid =~ /^REG_(\d{10})$/;
        my $indexkey = "REG_INDEX_$suffix";
        $redis->del($indexkey);
        $logger->info("Cleared cached index for '$regid' due to source field change.");
    }

    return ( $indexcleared, undef );
}

# Delete a registry and its cached index.
sub delete_registry {
    my ( $regid, $redis ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );

    unless ( $regid =~ /^REG_\d{10}$/ && $redis->exists($regid) ) {
        return ( undef, "This registry doesn't exist." );
    }

    my ($suffix) = $regid =~ /^REG_(\d{10})$/;
    my $indexkey = "REG_INDEX_$suffix";

    $redis->del($regid);
    $redis->del($indexkey);

    $logger->info("Deleted registry '$regid'.");

    return ( 1, undef );
}

# Fetch registry.json from a configured registry source.
sub fetch_registry_index {
    my ( $type, %config ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );

    if ( $type eq "local" ) {
        my $path = $config{path};
        my $file = "$path/registry.json";

        unless ( -e $file ) {
            my $error = "Registry file not found: $file";
            $logger->error($error);
            return ( undef, $error );
        }

        open( my $fh, '<:raw', $file ) or do {
            my $error = "Cannot read registry file: $!";
            $logger->error($error);
            return ( undef, $error );
        };
        my $content = do { local $/; <$fh> };
        close $fh;

        return ( $content, undef );
    }

    if ( $type eq "git" ) {
        my $rawurl = resolve_git_raw_url( $config{provider}, $config{url}, $config{ref} );

        unless ($rawurl) {
            my $error = "Cannot resolve git URL: $config{url}";
            $logger->error($error);
            return ( undef, $error );
        }

        $logger->info("Fetching registry index from $rawurl");

        my $ua  = Mojo::UserAgent->new;
        my $res = $ua->get($rawurl)->result;

        unless ( $res->is_success ) {
            my $error = "Failed to fetch registry index: HTTP " . $res->code;
            $logger->error($error);
            return ( undef, $error );
        }

        return ( $res->body, undef );
    }

    return ( undef, "Unknown registry type: $type" );
}

#
# Plugin Validation
#

# Validate downloaded plugin content against registry metadata and filesystem state.
sub validate_plugin {
    my ( $content, $namespace, $plugmeta, $currentpath ) = @_;

    my $plugname  = $plugmeta->{name};
    my $plugver   = $plugmeta->{version};
    my $plugpath  = $plugmeta->{path};
    my $plugtype  = $plugmeta->{type};
    my $expectedsha  = $plugmeta->{sha256};

    # Required metadata
    unless ($plugname) {
        return ( undef, "Plugin '$namespace' is missing required field 'name'." );
    }
    unless ($plugver) {
        return ( undef, "Plugin '$namespace' is missing required field 'version'." );
    }
    unless ($plugpath) {
        return ( undef, "Plugin '$namespace' is missing required field 'path'." );
    }
    unless ($plugtype) {
        return ( undef, "Plugin '$namespace' is missing required field 'type'." );
    }

    # SHA-256 integrity
    unless ( defined $expectedsha && $expectedsha ne "" ) {
        return ( undef, "Plugin '$namespace' is missing required field 'sha256'." );
    }
    my $actual_sha = sha256_hex($content);
    if ( $actual_sha ne $expectedsha ) {
        return ( undef, "SHA-256 mismatch: expected $expectedsha, got $actual_sha" );
    }

    # Extract package declaration
    my ($pkg) = $content =~ /^package\s+(LANraragi::Plugin::\S+)\s*;/m;
    unless ($pkg) {
        return ( undef, "Plugin file doesn't declare a LANraragi::Plugin:: package." );
    }

    # Registry path safety: null bytes, traversal, absolute paths
    if ( index( $plugpath, "\0" ) >= 0 ) {
        return ( undef, "Invalid plugin path (null byte)." );
    }
    if ( $plugpath =~ /\.\./ || $plugpath =~ m{^/} ) {
        return ( undef, "Invalid plugin path: $plugpath" );
    }

    # Type mapping
    my $typedir = MANAGED_TYPE_DIRS->{$plugtype};
    unless ($typedir) {
        return ( undef, "Unknown plugin type '$plugtype'." );
    }

    # Extract filename and validate format
    my ($filename) = $plugpath =~ m{([^/]+)$};
    unless ($filename) {
        return ( undef, "Can't extract filename from path: $plugpath" );
    }
    unless ( $filename =~ /^[A-Za-z0-9_-]+\.pm$/ ) {
        return ( undef, "Invalid plugin filename: $filename" );
    }

    my $installdir  = getcwd() . "/lib/LANraragi/Plugin/Managed/$typedir";
    my $installpath = "$installdir/$filename";

    # Package-path consistency
    my ($stem) = $filename =~ /^(.+)\.pm$/;
    my $expectedpkg = "LANraragi::Plugin::Managed::${typedir}::${stem}";
    if ( $pkg ne $expectedpkg ) {
        return ( undef, "Package mismatch -- declared '$pkg' but expected '$expectedpkg'." );
    }

    # Package conflict (filesystem scan, skips install_path for upgrades)
    my $conflict = find_package_conflict( $pkg, $installpath );
    if ($conflict) {
        return ( undef, "Package '$pkg' already exists in $conflict." );
    }

    # Namespace conflict (filesystem scan)
    my $nsconflict = find_namespace_conflict( $namespace, $installpath );
    if ($nsconflict) {
        return ( undef, "Namespace '$namespace' already exists in $nsconflict." );
    }

    # Install path occupancy
    if ( -e $installpath && ( !defined $currentpath || $currentpath ne $installpath ) ) {
        return ( undef, "Install path is already occupied: $installpath" );
    }

    return ( { install_path => $installpath, install_dir => $installdir, package => $pkg }, undef );
}

# Install a plugin from a registry.
sub install_plugin {
    my ( $namespace, $redis, $regid ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );

    # Validate registry exists
    unless ( $regid =~ /^REG_\d{10}$/ && $redis->exists($regid) ) {
        return ( undef, "This registry doesn't exist." );
    }

    # Get cached index
    my ($suffix) = $regid =~ /^REG_(\d{10})$/;
    my $indexkey = "REG_INDEX_$suffix";

    unless ( $redis->exists($indexkey) ) {
        return ( undef, "No registry index cached. Run refresh first." );
    }

    my $indexjson = $redis->get($indexkey);
    my $index    = decode_json($indexjson);
    my $plugins  = $index->{plugins};

    unless ( $plugins->{$namespace} ) {
        return ( undef, "Plugin '$namespace' not found in registry." );
    }

    my $plugmeta = $plugins->{$namespace};
    my $plugpath = $plugmeta->{path};

    # Validate plugin path before any file or network access
    unless ($plugpath) {
        return ( undef, "Plugin '$namespace' is missing required field 'path'." );
    }
    if ( index( $plugpath, "\0" ) >= 0 ) {
        return ( undef, "Invalid plugin path (null byte)." );
    }
    if ( $plugpath =~ /\.\./ || $plugpath =~ m{^/} ) {
        return ( undef, "Invalid plugin path: $plugpath" );
    }

    # Get registry config for download
    my %config = $redis->hgetall($regid);
    my $type   = $config{type};

    my $namerds = "LRR_PLUGIN_" . uc($namespace);
    my $currentpath;

    if ( $redis->hexists( $namerds, "installed_path" ) ) {
        $currentpath = $redis->hget( $namerds, "installed_path" );
    }

    # Fetch the plugin file
    my $content;

    if ( $type eq "local" ) {
        my $file = "$config{path}/$plugpath";

        unless ( -e $file ) {
            return ( undef, "Plugin file not found: $file" );
        }

        open( my $fh, '<:raw', $file ) or do {
            return ( undef, "Cannot read plugin file: $!" );
        };
        $content = do { local $/; <$fh> };
        close $fh;

    } elsif ( $type eq "git" ) {
        my $rawurl = resolve_git_raw_url( $config{provider}, $config{url}, $config{ref}, $plugpath );

        unless ($rawurl) {
            return ( undef, "Can't resolve download URL for $plugpath" );
        }

        $logger->info("Downloading plugin from $rawurl");

        my $ua  = Mojo::UserAgent->new;
        my $res = $ua->get($rawurl)->result;

        unless ( $res->is_success ) {
            my $error = "Download failed: HTTP " . $res->code;
            $logger->error($error);
            return ( undef, $error );
        }

        $content = $res->body;
    } else {
        return ( undef, "Unknown registry type: $type" );
    }

    # Validate downloaded content
    my ( $validated, $error ) = validate_plugin( $content, $namespace, $plugmeta, $currentpath );
    if ($error) {
        return ( undef, $error );
    }

    my $installdir  = $validated->{install_dir};
    my $installpath = $validated->{install_path};

    # Create directory if needed
    make_path($installdir) unless -d $installdir;

    # Write the plugin file
    open( my $fh, '>:raw', $installpath ) or do {
        my $error = "Cannot write plugin file: $!";
        $logger->error($error);
        return ( undef, $error );
    };
    print $fh $content;
    close $fh;

    $logger->info("Installed plugin '$namespace' to $installpath");

    # Atomically verify registry still exists and store provenance.
    my $provenancelua = q{
        if redis.call("EXISTS", KEYS[1]) == 0 then
            return 0
        end
        redis.call("HSET", KEYS[2], "installed_path",    ARGV[1])
        redis.call("HSET", KEYS[2], "installed_version", ARGV[2])
        redis.call("HSET", KEYS[2], "registry",          ARGV[3])
        return 1
    };
    my $ok = eval {
        $redis->eval( $provenancelua, 2, $regid, $namerds,
            $installpath, $plugmeta->{version}, $regid );
    };
    if ($@) {
        $logger->error("Redis error during provenance write for '$namespace': $@");
        return ( undef, "Redis error while writing provenance." );
    }
    unless ($ok) {
        return ( undef, "Registry was deleted during install." );
    }

    # Load the plugin dynamically.
    # Use the relative inc path so %INC key matches what Module::Pluggable
    # and the stale-cache check in Utils::Plugins::get_plugins expect.
    my $incpath = $validated->{package};
    $incpath =~ s/::/\//g;
    $incpath .= ".pm";
    eval { require $incpath };
    if ($@) {
        $logger->warn("Plugin '$namespace' installed but wouldn't load: $@");
    }

    return ( $plugmeta, undef );
}

# Uninstall a plugin by deleting it from disk and cleaning up Redis.
sub uninstall_plugin {
    my ( $namespace, $redis ) = @_;

    my $logger  = get_logger( "Registry", "lanraragi" );
    my $namerds = "LRR_PLUGIN_" . uc($namespace);

    # Check if plugin has an installed path
    my $installpath;
    if ( $redis->hexists( $namerds, "installed_path" ) ) {
        $installpath = $redis->hget( $namerds, "installed_path" );
    }

    unless ($installpath) {
        return ( undef, "Plugin '$namespace' has no install path recorded." );
    }

    # Delete the file if it exists and is under Plugin/
    if ( -e $installpath ) {
        my $canonpath = abs_path($installpath);
        my $plugindir = abs_path( getcwd() . "/lib/LANraragi/Plugin" );
        unless ( $canonpath && $plugindir && index( $canonpath, "$plugindir/" ) == 0 ) {
            return ( undef, "Can't delete plugin outside Plugin/ directory: $installpath" );
        }

        unlink($canonpath) or do {
            return ( undef, "Couldn't delete plugin file: $!" );
        };
        $logger->info("Deleted plugin file: $canonpath");
    } else {
        $logger->warn("Plugin '$namespace' file not found at $installpath -- cleaning up Redis only.");
    }

    # Clear provenance only; preserve user config (enabled, customargs, hidden, priority, named params)
    $redis->hdel( $namerds, "installed_path", "installed_version", "registry" );

    return ( 1, undef );
}

# Reconcile discovered plugins with Redis state at startup.
sub scan_plugins {
    my ($redis) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );
    $logger->info("Scanning plugins...");

    # Get all M::P discovered classes
    my @discovered = LANraragi::Utils::Plugins::plugins();

    # Build namespace -> [class, file_path] map, detect duplicates
    my %ns_map;

    foreach my $class (@discovered) {
        next unless $class->can('plugin_info');

        my %info;
        eval { %info = $class->plugin_info() };
        if ($@) {
            $logger->warn("Plugin $class failed plugin_info(): $@");
            next;
        }

        my $ns = $info{namespace};
        unless ($ns) {
            $logger->warn("Plugin $class has no namespace, skipping.");
            next;
        }

        # Derive absolute file path from class name
        my $filepath = $class;
        $filepath =~ s/::/\//g;
        $filepath = getcwd() . "/lib/$filepath.pm";

        push @{ $ns_map{$ns} }, { class => $class, file_path => $filepath };
    }

    # Warn on namespace duplicates
    foreach my $ns ( keys %ns_map ) {
        if ( @{ $ns_map{$ns} } > 1 ) {
            my $paths = join( ", ", map { $_->{file_path} } @{ $ns_map{$ns} } );
            $logger->warn("Duplicate namespace '$ns' found in: $paths");
        }
    }

    # Warn on uc() collisions
    my %uc_map;
    foreach my $ns ( keys %ns_map ) {
        push @{ $uc_map{ uc($ns) } }, $ns;
    }
    foreach my $uc_key ( keys %uc_map ) {
        if ( @{ $uc_map{$uc_key} } > 1 ) {
            my $nses = join( ", ", @{ $uc_map{$uc_key} } );
            $logger->warn("Namespace case collision (shared Redis key LRR_PLUGIN_$uc_key): $nses");
        }
    }

    # Reconcile each unique namespace with Redis
    foreach my $ns ( keys %ns_map ) {
        next if @{ $ns_map{$ns} } > 1;    # skip duplicates

        my $entry    = $ns_map{$ns}[0];
        my $filepath = $entry->{file_path};
        my $namerds  = "LRR_PLUGIN_" . uc($ns);

        if ( $redis->exists($namerds) ) {

            # Redis key exists -- reconcile installed_path
            if ( $redis->hexists( $namerds, "installed_path" ) ) {
                my $recorded = $redis->hget( $namerds, "installed_path" );
                if ( $recorded ne $filepath ) {
                    $logger->warn("Plugin '$ns': installed_path '$recorded' differs from discovered '$filepath', updating.");
                    $redis->hset( $namerds, "installed_path", $filepath );
                }
            } else {
                $redis->hset( $namerds, "installed_path", $filepath );
            }
        } else {

            # No Redis key -- register discovered plugin
            $logger->info("Registering discovered plugin '$ns' at $filepath");
            $redis->hset( $namerds, "installed_path", $filepath );
        }
    }

    # Clean up orphaned Redis keys (installed_path set, but no matching discovered plugin)
    my @all_keys     = $redis->keys("LRR_PLUGIN_*");
    my %discovereduc = map { uc($_) => 1 } keys %ns_map;

    foreach my $key (@all_keys) {
        my ($nspart) = $key =~ /^LRR_PLUGIN_(.+)$/;
        next unless $nspart;

        unless ( $discovereduc{$nspart} ) {
            if ( $redis->hexists( $key, "installed_path" ) ) {
                my $path = $redis->hget( $key, "installed_path" );
                if ( -e $path ) {
                    $logger->warn("Plugin key '$key' (installed_path: $path) not discovered but file exists -- skipping removal.");
                    next;
                }
                $logger->warn("Orphaned plugin key '$key' (installed_path: $path) -- plugin not discovered. Clearing provenance.");
            } else {
                $logger->warn("Orphaned plugin key '$key' -- plugin not discovered. Clearing provenance.");
            }
            $redis->hdel( $key, "installed_path", "installed_version", "registry" );
        }
    }

    $logger->info("Plugin scan complete.");
}

1;
