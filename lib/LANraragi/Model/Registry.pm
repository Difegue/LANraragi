package LANraragi::Model::Registry;

use strict;
use warnings;
use utf8;

use Cwd 'abs_path';
use Digest::SHA qw(sha256_hex);
use File::Copy;
use File::Path qw(make_path);
use Mojo::JSON qw(decode_json);
use Mojo::UserAgent;

use LANraragi::Utils::Logging  qw(get_logger);
use LANraragi::Utils::Registry qw(resolve_git_raw_url);

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

        open( my $fh, '<:utf8', $file ) or do {
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

# Install a plugin from the registry.
# Looks up the namespace in the cached index, downloads the .pm file,
# verifies SHA-256 if present, and saves to Plugin/Installed/{Type}/.
# Returns (plugin_info_hash, undef) on success, (undef, error) on failure.
sub install_plugin {
    my ( $namespace, $redis ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );

    # Get cached index
    unless ( $redis->exists("LRR_REGISTRY_INDEX") ) {
        return ( undef, "No registry index cached. Run refresh first." );
    }

    my $index_json  = $redis->get("LRR_REGISTRY_INDEX");
    my $index       = decode_json($index_json);
    my $plugins     = $index->{plugins};

    unless ( $plugins->{$namespace} ) {
        return ( undef, "Plugin '$namespace' not found in registry index." );
    }

    my $plugin_meta     = $plugins->{$namespace};
    my $plugin_path     = $plugin_meta->{path};
    my $plugin_type     = $plugin_meta->{type};
    my $expected_sha    = $plugin_meta->{sha256};

    # Validate path has no traversal
    if ( $plugin_path =~ /\.\./ || $plugin_path =~ m{^/} ) {
        return ( undef, "Invalid plugin path: $plugin_path" );
    }

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

    # Verify SHA-256 if provided
    if ( $expected_sha && $expected_sha ne "" ) {
        my $actual_sha = sha256_hex($content);
        if ( $actual_sha ne $expected_sha ) {
            return ( undef, "SHA-256 mismatch: expected $expected_sha, got $actual_sha" );
        }
    }

    # Extract filename from path
    my ($filename) = $plugin_path =~ m{([^/]+)$};
    unless ($filename) {
        return ( undef, "Cannot extract filename from path: $plugin_path" );
    }

    my $install_dir     = "lib/LANraragi/Plugin/Sideloaded";
    my $install_path    = "$install_dir/$filename";

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
    my $namerds = "LRR_PLUGIN_" . uc($namespace);
    $redis->hset( $namerds, "installed_path", $install_path );
    $redis->hset( $namerds, "installed_version", $plugin_meta->{version} // "" );

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

    # Validate the path is under Plugin/Sideloaded/
    unless ( $install_path =~ m{Plugin/Sideloaded/} ) {
        return ( undef, "Refusing to delete plugin outside of Sideloaded directory: $install_path" );
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
