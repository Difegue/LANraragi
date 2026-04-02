package LANraragi::Model::Registry;

use strict;
use warnings;
use utf8;

use Cwd qw(abs_path getcwd);
use Digest::SHA qw(sha256_hex);
use File::Copy;
use File::Find;
use File::Path qw(make_path);
use Mojo::JSON qw(decode_json);
use Mojo::UserAgent;

use LANraragi::Utils::Logging  qw(get_logger);
use LANraragi::Utils::Plugins  qw();
use LANraragi::Utils::Registry qw(resolve_git_raw_url MANAGED_TYPE_DIRS);

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

#
# Registry CRUD
#

# Create a registry entry with a generated REG_{timestamp} ID.
# Returns ($registry_id, undef) on success, (undef, $error) on failure.
sub create_registry {
    my ( $redis, %config ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );

    # Single-registry enforcement (temporary — remove when multi-registry ships)
    my @existing = $redis->keys("REG_??????????");
    if (@existing) {
        return ( undef, "Only one registry is supported. Remove the existing registry first." );
    }

    # Generate ID following SET_/TANK_ pattern
    my $id_ts  = time();
    my $reg_id = "REG_" . $id_ts;
    while ( $redis->exists($reg_id) ) {
        $id_ts++;
        $reg_id = "REG_" . $id_ts;
    }

    # Store config fields
    my $type = $config{type};
    my @valid_fields = @{ $TYPE_FIELDS{$type} };

    for my $field (@valid_fields) {
        next unless defined $config{$field};
        $redis->hset( $reg_id, $field, $config{$field} );
    }

    $logger->info("Created registry '$reg_id' (name: $config{name}, type: $type)");

    return ( $reg_id, undef );
}

# Get a registry's config by ID.
# Returns (%config) with 'id' included, or empty hash if not found.
sub get_registry {
    my ( $registry_id, $redis ) = @_;

    return () unless $registry_id =~ /^REG_\d{10}$/ && $redis->exists($registry_id);

    my %config = $redis->hgetall($registry_id);
    $config{id} = $registry_id;

    return %config;
}

# List all registries.
# Returns @registries (array of hashrefs with {id, name, type, ...}).
sub get_registry_list {
    my ($redis) = @_;

    my @keys = $redis->keys("REG_??????????");
    my @result;

    for my $key ( sort @keys ) {
        my %config = get_registry( $key, $redis );
        push @result, \%config if %config;
    }

    return @result;
}

# Update mutable fields on an existing registry.
# Clears cached index if source fields change. Removes stale fields on type change.
# Returns ($index_cleared, undef) on success, (undef, $error) on failure.
sub update_registry {
    my ( $registry_id, $redis, %updates ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );

    unless ( $registry_id =~ /^REG_\d{10}$/ && $redis->exists($registry_id) ) {
        return ( undef, "Registry does not exist." );
    }

    my %current = $redis->hgetall($registry_id);

    # Determine if source fields are changing
    my $index_cleared = 0;
    for my $field (@SOURCE_FIELDS) {
        next unless exists $updates{$field};
        if ( !defined $current{$field} || $current{$field} ne $updates{$field} ) {
            $index_cleared = 1;
            last;
        }
    }

    # Validate type enum if changing
    my $type = $updates{type} // $current{type};
    unless ( $type eq "git" || $type eq "local" ) {
        return ( undef, "Invalid registry type '$type'. Must be 'git' or 'local'." );
    }

    # Validate resulting config has required fields for the target type
    my %merged = ( %current, %updates );

    if ( $type eq "git" ) {
        return ( undef, "Git registry requires 'url' field." )      unless $merged{url};
        return ( undef, "Git registry requires 'provider' field." ) unless $merged{provider};
    } elsif ( $type eq "local" ) {
        return ( undef, "Local registry requires 'path' field." ) unless $merged{path};
    }

    # Handle type change: remove stale fields (after validation passes)
    if ( exists $updates{type} && $updates{type} ne ( $current{type} // "" ) ) {
        my @to_remove = @{ $STALE_FIELDS{$type} };
        for my $field (@to_remove) {
            $redis->hdel( $registry_id, $field );
        }
    }

    # Apply updates
    my @valid_fields = @{ $TYPE_FIELDS{$type} };
    my %valid_set    = map { $_ => 1 } @valid_fields;

    for my $field ( keys %updates ) {
        next unless $valid_set{$field};
        $redis->hset( $registry_id, $field, $updates{$field} );
    }

    # Clear cached index if source changed
    if ($index_cleared) {
        my ($suffix) = $registry_id =~ /^REG_(\d{10})$/;
        my $index_key = "REG_INDEX_$suffix";
        $redis->del($index_key);
        $logger->info("Cleared cached index for '$registry_id' due to source field change.");
    }

    return ( $index_cleared, undef );
}

# Delete a registry and its cached index.
# Returns (1, undef) on success, (undef, $error) on failure.
sub delete_registry {
    my ( $registry_id, $redis ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );

    unless ( $registry_id =~ /^REG_\d{10}$/ && $redis->exists($registry_id) ) {
        return ( undef, "Registry does not exist." );
    }

    my ($suffix) = $registry_id =~ /^REG_(\d{10})$/;
    my $index_key = "REG_INDEX_$suffix";

    $redis->del($registry_id);
    $redis->del($index_key);

    $logger->info("Deleted registry '$registry_id'.");

    return ( 1, undef );
}

#
# Registry Index
#

# Fetch registry.json from a configured registry source.
# Returns (content, undef) on success, (undef, error) on failure.
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
        my $raw_url = resolve_git_raw_url( $config{provider}, $config{url}, $config{ref} );

        unless ($raw_url) {
            my $error = "Cannot resolve git URL: $config{url}";
            $logger->error($error);
            return ( undef, $error );
        }

        $logger->info("Fetching registry index from $raw_url");

        my $ua  = Mojo::UserAgent->new;
        my $res = $ua->get($raw_url)->result;

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

# Check if a package name is already declared by an existing plugin file.
# Scans all .pm files under Plugin/, skipping the file at $skip_path (for upgrades).
# Returns the conflicting file path, or undef if no conflict.
sub find_package_conflict {
    my ( $package_name, $skip_path ) = @_;

    my $plugin_dir = getcwd() . "/lib/LANraragi/Plugin";
    my $conflict;

    return unless -d $plugin_dir;

    find(
        {
            no_chdir => 1,
            wanted   => sub {
                return if $conflict;
                return unless /\.pm$/;

                my $filepath = $File::Find::name;
                return if $skip_path && $filepath eq $skip_path;

                open( my $fh, '<', $filepath ) or return;
                while ( my $line = <$fh> ) {
                    if ( $line =~ /^package\s+\Q$package_name\E\s*;/ ) {
                        $conflict = $filepath;
                        last;
                    }
                }
                close $fh;
            },
        },
        $plugin_dir
    );

    return $conflict;
}

sub find_namespace_conflict {
    my ( $namespace, $skip_path ) = @_;

    my $plugin_dir = getcwd() . "/lib/LANraragi/Plugin";
    my $conflict;

    return unless -d $plugin_dir;

    find(
        {
            no_chdir => 1,
            wanted   => sub {
                return if $conflict;
                return unless /\.pm$/;

                my $filepath = $File::Find::name;
                return if $skip_path && $filepath eq $skip_path;

                open( my $fh, '<', $filepath ) or return;
                my $content = do { local $/; <$fh> };
                close $fh;

                if ( $content =~ /namespace\s*=>\s*['"]\Q$namespace\E['"]/ ) {
                    $conflict = $filepath;
                }
            },
        },
        $plugin_dir
    );

    return $conflict;
}

# Validate downloaded plugin content against registry metadata and filesystem state.
# Pure validation — no writes to disk or Redis.
# Returns ({install_path, install_dir, package}, undef) on success, (undef, error) on failure.
sub validate_plugin {
    my ( $content, $namespace, $plugin_meta, $current_install_path ) = @_;

    my $plugin_name  = $plugin_meta->{name};
    my $plugin_ver   = $plugin_meta->{version};
    my $plugin_path  = $plugin_meta->{path};
    my $plugin_type  = $plugin_meta->{type};
    my $expected_sha = $plugin_meta->{sha256};

    # Required metadata
    unless ( defined $plugin_name && $plugin_name ne "" ) {
        return ( undef, "Plugin '$namespace' is missing required field 'name'." );
    }
    unless ( defined $plugin_ver && $plugin_ver ne "" ) {
        return ( undef, "Plugin '$namespace' is missing required field 'version'." );
    }

    # SHA-256 integrity
    if ( $expected_sha && $expected_sha ne "" ) {
        my $actual_sha = sha256_hex($content);
        if ( $actual_sha ne $expected_sha ) {
            return ( undef, "SHA-256 mismatch: expected $expected_sha, got $actual_sha" );
        }
    } else {
        my $logger = get_logger( "Registry", "lanraragi" );
        $logger->warn("Plugin '$namespace' has no SHA-256 checksum in registry — integrity not verified.");
    }

    # Extract package declaration
    my ($pkg) = $content =~ /^package\s+(LANraragi::Plugin::\S+)\s*;/m;
    unless ($pkg) {
        return ( undef, "Plugin file does not declare a LANraragi::Plugin:: package." );
    }

    # Registry path traversal
    if ( $plugin_path =~ /\.\./ || $plugin_path =~ m{^/} ) {
        return ( undef, "Invalid plugin path: $plugin_path" );
    }

    # Type mapping
    my $type_dir = MANAGED_TYPE_DIRS->{$plugin_type};
    unless ($type_dir) {
        return ( undef, "Unknown plugin type '$plugin_type'." );
    }

    # Extract filename and compute install path
    my ($filename) = $plugin_path =~ m{([^/]+)$};
    unless ($filename) {
        return ( undef, "Cannot extract filename from path: $plugin_path" );
    }

    my $install_dir  = getcwd() . "/lib/LANraragi/Plugin/Managed/$type_dir";
    my $install_path = "$install_dir/$filename";

    # Package-path consistency
    my ($stem) = $filename =~ /^(.+)\.pm$/;
    my $expected_pkg = "LANraragi::Plugin::Managed::${type_dir}::${stem}";
    if ( $pkg ne $expected_pkg ) {
        return ( undef, "Package mismatch: declared '$pkg', expected '$expected_pkg' for install to $install_path." );
    }

    # Package conflict (filesystem scan, skips install_path for upgrades)
    my $conflict = find_package_conflict( $pkg, $install_path );
    if ($conflict) {
        return ( undef, "Package '$pkg' is already declared in $conflict. Cannot install." );
    }

    # Namespace conflict (filesystem scan)
    my $namespace_conflict = find_namespace_conflict( $namespace, $install_path );
    if ($namespace_conflict) {
        return ( undef, "Namespace '$namespace' is already declared in $namespace_conflict. Cannot install." );
    }

    # Install path occupancy
    if ( -e $install_path && ( !defined $current_install_path || $current_install_path ne $install_path ) ) {
        return ( undef, "Install path '$install_path' is already occupied. Cannot install." );
    }

    return ( { install_path => $install_path, install_dir => $install_dir, package => $pkg }, undef );
}

#
# Plugin Install/Uninstall
#

# Install a plugin from a registry.
# Looks up the namespace in the registry's cached index, downloads the .pm file,
# validates, and saves to Plugin/Managed/{Type}/.
# Returns (plugin_info_hash, undef) on success, (undef, error) on failure.
sub install_plugin {
    my ( $namespace, $redis, $registry_id ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );

    # Validate registry exists
    unless ( $registry_id =~ /^REG_\d{10}$/ && $redis->exists($registry_id) ) {
        return ( undef, "Registry does not exist." );
    }

    # Get cached index
    my ($suffix) = $registry_id =~ /^REG_(\d{10})$/;
    my $index_key = "REG_INDEX_$suffix";

    unless ( $redis->exists($index_key) ) {
        return ( undef, "No registry index cached. Run refresh first." );
    }

    my $index_json = $redis->get($index_key);
    my $index      = decode_json($index_json);
    my $plugins    = $index->{plugins};

    unless ( $plugins->{$namespace} ) {
        return ( undef, "Plugin '$namespace' not found in registry index." );
    }

    my $plugin_meta = $plugins->{$namespace};
    my $plugin_path = $plugin_meta->{path};

    # Get registry config for download
    my %config = $redis->hgetall($registry_id);
    my $type   = $config{type};

    my $namerds = "LRR_PLUGIN_" . uc($namespace);
    my $current_install_path;

    if ( $redis->hexists( $namerds, "installed_path" ) ) {
        $current_install_path = $redis->hget( $namerds, "installed_path" );
    }

    # Fetch the plugin file
    my $content;

    if ( $type eq "local" ) {
        my $file = "$config{path}/$plugin_path";

        unless ( -e $file ) {
            return ( undef, "Plugin file not found: $file" );
        }

        open( my $fh, '<:raw', $file ) or do {
            return ( undef, "Cannot read plugin file: $!" );
        };
        $content = do { local $/; <$fh> };
        close $fh;

    } elsif ( $type eq "git" ) {
        my $raw_url = resolve_git_raw_url( $config{provider}, $config{url}, $config{ref}, $plugin_path );

        unless ($raw_url) {
            return ( undef, "Cannot resolve download URL for $plugin_path" );
        }

        $logger->info("Downloading plugin from $raw_url");

        my $ua  = Mojo::UserAgent->new;
        my $res = $ua->get($raw_url)->result;

        unless ( $res->is_success ) {
            my $error = "Failed to download plugin: HTTP " . $res->code;
            $logger->error($error);
            return ( undef, $error );
        }

        $content = $res->body;
    } else {
        return ( undef, "Unknown registry type: $type" );
    }

    # Validate downloaded content
    my ( $validated, $error ) = validate_plugin( $content, $namespace, $plugin_meta, $current_install_path );
    if ($error) {
        return ( undef, $error );
    }

    my $install_dir  = $validated->{install_dir};
    my $install_path = $validated->{install_path};

    # Create directory if needed
    make_path($install_dir) unless -d $install_dir;

    # Write the plugin file
    open( my $fh, '>:raw', $install_path ) or do {
        my $error = "Cannot write plugin file: $!";
        $logger->error($error);
        return ( undef, $error );
    };
    print $fh $content;
    close $fh;

    $logger->info("Installed plugin '$namespace' to $install_path");

    # Atomically verify registry still exists and store provenance.
    my $provenance_lua = q{
        if redis.call("EXISTS", KEYS[1]) == 0 then
            return 0
        end
        redis.call("HSET", KEYS[2], "installed_path",    ARGV[1])
        redis.call("HSET", KEYS[2], "installed_version", ARGV[2])
        redis.call("HSET", KEYS[2], "registry",          ARGV[3])
        return 1
    };
    my $ok = $redis->eval( $provenance_lua, 2, $registry_id, $namerds,
        $install_path, $plugin_meta->{version}, $registry_id );
    unless ($ok) {
        unlink($install_path);
        return ( undef, "Registry '$registry_id' was deleted during install." );
    }

    # Load the plugin dynamically.
    # Use the relative inc path so %INC key matches what Module::Pluggable
    # and the stale-cache check in Utils::Plugins::get_plugins expect.
    my $inc_path = $validated->{package};
    $inc_path =~ s/::/\//g;
    $inc_path .= ".pm";
    eval { require $inc_path };
    if ($@) {
        $logger->warn("Plugin '$namespace' installed but failed to load: $@");
    }

    return ( $plugin_meta, undef );
}

# Uninstall a plugin by deleting it from disk and cleaning up Redis.
# Returns (1, undef) on success, (undef, error) on failure.
sub uninstall_plugin {
    my ( $namespace, $redis ) = @_;

    my $logger  = get_logger( "Registry", "lanraragi" );
    my $namerds = "LRR_PLUGIN_" . uc($namespace);

    # Check if plugin has an installed path
    my $install_path;
    if ( $redis->hexists( $namerds, "installed_path" ) ) {
        $install_path = $redis->hget( $namerds, "installed_path" );
    }

    unless ($install_path) {
        return ( undef, "Plugin '$namespace' has no recorded install path." );
    }

    # Canonicalize and validate the path is under Plugin/
    my $canon_path = abs_path($install_path) // $install_path;
    my $plugin_dir = getcwd() . "/lib/LANraragi/Plugin/";
    unless ( index( $canon_path, $plugin_dir ) == 0 ) {
        return ( undef, "Refusing to delete plugin outside of Plugin directory: $install_path" );
    }
    $install_path = $canon_path;

    # Delete the file
    if ( -e $install_path ) {
        unlink($install_path) or do {
            return ( undef, "Failed to delete plugin file: $!" );
        };
        $logger->info("Deleted plugin file: $install_path");
    }

    # Clean up Redis
    $redis->del($namerds);

    return ( 1, undef );
}

# Reconcile discovered plugins with Redis state at startup.
# Ensures every discovered plugin has a Redis key, and cleans up orphaned keys.
sub scan_plugins {
    my ($redis) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );
    $logger->info("Scanning plugins...");

    # Get all M::P discovered classes
    my @discovered = LANraragi::Utils::Plugins::plugins();

    # Build namespace -> [class, file_path] map, detect duplicates
    my %ns_map;

    for my $class (@discovered) {
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
        my $file_path = $class;
        $file_path =~ s/::/\//g;
        $file_path = getcwd() . "/lib/$file_path.pm";

        push @{ $ns_map{$ns} }, { class => $class, file_path => $file_path };
    }

    # Warn on namespace duplicates
    for my $ns ( keys %ns_map ) {
        if ( @{ $ns_map{$ns} } > 1 ) {
            my $paths = join( ", ", map { $_->{file_path} } @{ $ns_map{$ns} } );
            $logger->warn("Duplicate namespace '$ns' found in: $paths");
        }
    }

    # Warn on uc() collisions
    my %uc_map;
    for my $ns ( keys %ns_map ) {
        push @{ $uc_map{ uc($ns) } }, $ns;
    }
    for my $uc_key ( keys %uc_map ) {
        if ( @{ $uc_map{$uc_key} } > 1 ) {
            my $nses = join( ", ", @{ $uc_map{$uc_key} } );
            $logger->warn("Namespace case collision (shared Redis key LRR_PLUGIN_$uc_key): $nses");
        }
    }

    # Reconcile each unique namespace with Redis
    for my $ns ( keys %ns_map ) {
        next if @{ $ns_map{$ns} } > 1;    # skip duplicates

        my $entry     = $ns_map{$ns}[0];
        my $file_path = $entry->{file_path};
        my $namerds   = "LRR_PLUGIN_" . uc($ns);

        if ( $redis->exists($namerds) ) {

            # Redis key exists — reconcile installed_path
            if ( $redis->hexists( $namerds, "installed_path" ) ) {
                my $recorded = $redis->hget( $namerds, "installed_path" );
                if ( $recorded ne $file_path ) {
                    $logger->warn("Plugin '$ns': installed_path '$recorded' differs from discovered '$file_path', updating.");
                    $redis->hset( $namerds, "installed_path", $file_path );
                }
            } else {
                $redis->hset( $namerds, "installed_path", $file_path );
            }
        } else {

            # No Redis key — register discovered plugin
            $logger->info("Registering discovered plugin '$ns' at $file_path");
            $redis->hset( $namerds, "installed_path", $file_path );
        }
    }

    # Clean up orphaned Redis keys (installed_path set, but no matching discovered plugin)
    my @all_keys     = $redis->keys("LRR_PLUGIN_*");
    my %discovered_uc = map { uc($_) => 1 } keys %ns_map;

    for my $key (@all_keys) {
        my ($ns_part) = $key =~ /^LRR_PLUGIN_(.+)$/;
        next unless $ns_part;

        unless ( $discovered_uc{$ns_part} ) {
            if ( $redis->hexists( $key, "installed_path" ) ) {
                my $path = $redis->hget( $key, "installed_path" );
                if ( -e $path ) {
                    $logger->warn("Plugin key '$key' (installed_path: $path) not discovered but file exists — skipping removal.");
                    next;
                }
                $logger->warn("Orphaned plugin key '$key' (installed_path: $path) — plugin not discovered. Removing.");
            } else {
                $logger->warn("Orphaned plugin key '$key' — plugin not discovered. Removing.");
            }
            $redis->del($key);
        }
    }

    $logger->info("Plugin scan complete.");
}

1;
