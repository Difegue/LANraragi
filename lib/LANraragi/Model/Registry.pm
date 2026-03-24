package LANraragi::Model::Registry;

use strict;
use warnings;
use utf8;

use Cwd 'abs_path';
use Digest::SHA qw(sha256_hex);
use File::Copy;
use File::Find;
use File::Path qw(make_path);
use Mojo::JSON qw(decode_json);
use Mojo::UserAgent;

use LANraragi::Utils::Logging  qw(get_logger);
use LANraragi::Utils::Registry qw(resolve_git_raw_url MANAGED_TYPE_DIRS);

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

# Check if a package name is already declared by an existing plugin file.
# Scans all .pm files under Plugin/, skipping the file at $skip_path (for upgrades).
# Returns the conflicting file path, or undef if no conflict.
sub _find_package_conflict {
    my ( $package_name, $skip_path ) = @_;

    my $plugin_dir = "lib/LANraragi/Plugin";
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

sub _find_namespace_conflict {
    my ( $namespace, $skip_path ) = @_;

    my $plugin_dir = "lib/LANraragi/Plugin";
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

    my $plugin_path  = $plugin_meta->{path};
    my $plugin_type  = $plugin_meta->{type};
    my $expected_sha = $plugin_meta->{sha256};

    # SHA-256 integrity
    if ( $expected_sha && $expected_sha ne "" ) {
        my $actual_sha = sha256_hex($content);
        if ( $actual_sha ne $expected_sha ) {
            return ( undef, "SHA-256 mismatch: expected $expected_sha, got $actual_sha" );
        }
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

    my $install_dir  = "lib/LANraragi/Plugin/Managed/$type_dir";
    my $install_path = "$install_dir/$filename";

    # Package-path consistency
    my ($stem) = $filename =~ /^(.+)\.pm$/;
    my $expected_pkg = "LANraragi::Plugin::Managed::${type_dir}::${stem}";
    if ( $pkg ne $expected_pkg ) {
        return ( undef, "Package mismatch: declared '$pkg', expected '$expected_pkg' for install to $install_path." );
    }

    # Package conflict (filesystem scan, skips install_path for upgrades)
    my $conflict = _find_package_conflict( $pkg, $install_path );
    if ($conflict) {
        return ( undef, "Package '$pkg' is already declared in $conflict. Cannot install." );
    }

    # Namespace conflict (filesystem scan)
    my $namespace_conflict = _find_namespace_conflict( $namespace, $install_path );
    if ($namespace_conflict) {
        return ( undef, "Namespace '$namespace' is already declared in $namespace_conflict. Cannot install." );
    }

    # Install path occupancy
    if ( -e $install_path && ( !defined $current_install_path || $current_install_path ne $install_path ) ) {
        return ( undef, "Install path '$install_path' is already occupied. Cannot install." );
    }

    return ( { install_path => $install_path, install_dir => $install_dir, package => $pkg }, undef );
}

# Install a plugin from the registry.
# Looks up the namespace in the cached index, downloads the .pm file,
# validates, and saves to Plugin/Managed/{Type}/.
# Returns (plugin_info_hash, undef) on success, (undef, error) on failure.
sub install_plugin {
    my ( $namespace, $redis ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );

    # Get cached index
    unless ( $redis->exists("LRR_REGISTRY_INDEX") ) {
        return ( undef, "No registry index cached. Run refresh first." );
    }

    my $index_json = $redis->get("LRR_REGISTRY_INDEX");
    my $index      = decode_json($index_json);
    my $plugins    = $index->{plugins};

    unless ( $plugins->{$namespace} ) {
        return ( undef, "Plugin '$namespace' not found in registry index." );
    }

    my $plugin_meta = $plugins->{$namespace};
    my $plugin_path = $plugin_meta->{path};

    # Get registry config for download
    unless ( $redis->exists("LRR_REGISTRY") ) {
        return ( undef, "No registry configured." );
    }
    my %config = $redis->hgetall("LRR_REGISTRY");
    my $type   = $config{type};

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
    my $namerds = "LRR_PLUGIN_" . uc($namespace);
    my $current_install_path;

    if ( $redis->hexists( $namerds, "installed_path" ) ) {
        $current_install_path = $redis->hget( $namerds, "installed_path" );
    }

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

    # Store install metadata in Redis
    $redis->hset( $namerds, "installed_path",      $install_path );
    $redis->hset( $namerds, "installed_version",    $plugin_meta->{version} // "" );

    # Load the plugin dynamically
    eval { require $install_path };
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

    # Validate the path is under Plugin/Managed/
    unless ( $install_path =~ m{Plugin/Managed/} ) {
        return ( undef, "Refusing to delete plugin outside of Managed directory: $install_path" );
    }

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

1;
