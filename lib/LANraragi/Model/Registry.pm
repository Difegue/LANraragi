package LANraragi::Model::Registry;

use strict;
use warnings;
use utf8;

use Cwd qw(abs_path getcwd);
use Digest::SHA qw(sha256_hex);
use File::Path qw(make_path);
use File::Spec;
use Mojo::JSON qw(decode_json);
use Mojo::UserAgent;

use LANraragi::Utils::Logging  qw(get_logger);
use LANraragi::Utils::Path     qw(open_path unlink_path);
use LANraragi::Utils::Plugins  qw();
use LANraragi::Utils::Registry qw(resolve_git_raw_url find_package_conflict find_namespace_conflict MANAGED_TYPE_DIRS);

# Max file sizes for slurp (OOM guard).
use constant MAX_REGISTRY_INDEX_SIZE => 10 * 1024 * 1024;    # 10 MB
use constant MAX_PLUGIN_FILE_SIZE    => 1 * 1024 * 1024;     # 1 MB

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
# Returns ( $registry_id, undef ) or ( undef, $error_message ).
sub create_registry {
    my ( $redis, %config ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );

    # TODO: remove with multi-registry.
    # Single-registry enforcement
    my @existing = $redis->keys("REG_??????????");
    if (@existing) {
        return ( undef, "Only one registry is supported -- remove the existing one first." );
    }

    # Sanitize local registry path
    if ( $config{type} eq "local" && defined $config{path} ) {
        if ( index( $config{path}, "\0" ) >= 0 || $config{path} =~ /\.\./ ) {
            return ( undef, "Invalid registry path." );
        }
    }

    my $registry_id = "REG_" . time();
    my $isnewkey    = 0;
    until ($isnewkey) {
        if ( $redis->exists($registry_id) ) {
            $registry_id = "REG_" . ( time() + 1 );
        } else {
            $isnewkey = 1;
        }
    }

    # Store config fields
    my $type         = $config{type};
    my @valid_fields = @{ $TYPE_FIELDS{$type} };

    foreach my $field (@valid_fields) {
        next unless defined $config{$field};
        $redis->hset( $registry_id, $field, $config{$field} );
    }

    $logger->info("Created registry '$registry_id' (name: $config{name}, type: $type)");

    return ( $registry_id, undef );
}

# Get a registry's config by ID.
sub get_registry {
    my ( $registry_id, $redis ) = @_;

    return () unless $registry_id =~ /^REG_\d{10}$/ && $redis->exists($registry_id);

    my %config = $redis->hgetall($registry_id);
    $config{id} = $registry_id;

    return %config;
}

# List all registries.
sub get_registry_list {
    my ($redis) = @_;

    my @reg_ids = $redis->keys("REG_??????????");

    my @result;

    # Sort by timestamp
    # not used now, but will be when multi-registry hits
    foreach my $key ( sort @reg_ids ) {
        my %config = get_registry( $key, $redis );
        push @result, \%config if %config;    # skip if deleted between keys() and hgetall
    }

    return @result;
}

# Update mutable fields on an existing registry.
sub update_registry {
    my ( $registry_id, $redis, %updated_registry ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );

    unless ( $registry_id =~ /^REG_\d{10}$/ && $redis->exists($registry_id) ) {
        return ( 404, undef, "This registry doesn't exist." );
    }

    # Sanitize local registry path if provided
    if ( defined $updated_registry{path} ) {
        if ( index( $updated_registry{path}, "\0" ) >= 0 || $updated_registry{path} =~ /\.\./ ) {
            return ( 400, undef, "Invalid registry path." );
        }
    }

    my %current_registry = $redis->hgetall($registry_id);

    # Determine if source fields are changing
    my $indexcleared = 0;
    foreach my $field (@SOURCE_FIELDS) {
        next unless exists $updated_registry{$field};
        if ( !defined $current_registry{$field} || $current_registry{$field} ne $updated_registry{$field} ) {
            $indexcleared = 1;
            last;
        }
    }

    # type enum is validated by OpenAPI (enum: [git, local]) on the request body.
    my $type = $updated_registry{type} // $current_registry{type};

    # Partial updates may omit fields already stored; merge before validating.
    my %merged = ( %current_registry, %updated_registry );

    if ( $type eq "git" ) {
        return ( 400, undef, "Git registry needs a URL." )      unless $merged{url};
        return ( 400, undef, "Git registry needs a provider." ) unless $merged{provider};
    } elsif ( $type eq "local" ) {
        return ( 400, undef, "Local registry needs a path." ) unless $merged{path};
    }

    # Atomic update via Lua: stale field removal, field writes, optional index clear.
    my @fields_to_remove;
    # type is always set on a valid registry (stored at creation); no fallback needed
    if ( exists $updated_registry{type} && $updated_registry{type} ne $current_registry{type} ) {
        @fields_to_remove = @{ $STALE_FIELDS{$type} };
    }

    my @valid_fields = @{ $TYPE_FIELDS{$type} };
    my %valid_set    = map { $_ => 1 } @valid_fields;
    my @fields_to_set;
    foreach my $field ( keys %updated_registry ) {
        next unless $valid_set{$field};
        push @fields_to_set, $field, $updated_registry{$field};
    }

    my $indexkey = "";
    if ($indexcleared) {
        my ($suffix) = $registry_id =~ /^REG_(\d{10})$/;
        $indexkey = "REG_INDEX_$suffix";
    }

    my $script = <<'LUA';
    local ndel = tonumber(ARGV[1])
    local idx = 2
    for _ = 1, ndel do
        redis.call("HDEL", KEYS[1], ARGV[idx])
        idx = idx + 1
    end
    while idx + 1 <= #ARGV do
        redis.call("HSET", KEYS[1], ARGV[idx], ARGV[idx + 1])
        idx = idx + 2
    end
    if KEYS[2] ~= "" then
        redis.call("DEL", KEYS[2])
    end
    return 1
LUA

    eval {
        $redis->eval( $script, 2, $registry_id, $indexkey,
            scalar @fields_to_remove, @fields_to_remove, @fields_to_set );
    };
    if ($@) {
        $logger->error("Redis error during registry update for '$registry_id': $@");
        return ( 500, undef, "Redis error while updating registry." );
    }

    if ($indexcleared) {
        $logger->info("Cleared cached index for '$registry_id' due to source field change.");
    }

    return ( 200, $indexcleared, undef );
}

# Delete a registry and its cached index.
sub delete_registry {
    my ( $registry_id, $redis ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );

    unless ( $registry_id =~ /^REG_\d{10}$/ && $redis->exists($registry_id) ) {
        return ( 404, undef, "$registry_id is not a registry ID, doing nothing." );
    }

    my ($suffix) = $registry_id =~ /^REG_(\d{10})$/;
    my $indexkey = "REG_INDEX_$suffix";

    # Atomic delete of registry + index key
    my $script = <<'LUA';
    redis.call("DEL", KEYS[1])
    redis.call("DEL", KEYS[2])
    return 1
LUA

    eval { $redis->eval( $script, 2, $registry_id, $indexkey ) };
    if ($@) {
        $logger->error("Redis error during registry delete for '$registry_id': $@");
        return ( 500, undef, "Redis error while deleting registry." );
    }

    $logger->info("Deleted registry '$registry_id'.");

    return ( 200, 1, undef );
}

# Fetch registry.json from a configured registry source.
sub fetch_registry_index {
    my ( $type, %config ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );

    if ( $type eq "local" ) {
        my $path = $config{path};

        if ( index( $path, "\0" ) >= 0 || $path =~ /\.\./ ) {
            my $error = "Invalid registry path (null byte or traversal).";
            $logger->error($error);
            return ( 400, undef, $error );
        }

        my $file = File::Spec->catfile( $path, "registry.json" );

        unless ( -e $file ) {
            my $error = "Registry file not found: $file";
            $logger->error($error);
            return ( 404, undef, $error );
        }

        my $filesize = -s $file;
        if ( $filesize == 0 ) {
            my $error = "Registry file is empty: $file";
            $logger->error($error);
            return ( 400, undef, $error );
        }
        if ( $filesize > MAX_REGISTRY_INDEX_SIZE ) {
            my $error = "Registry file too large: $file ($filesize bytes, max " . MAX_REGISTRY_INDEX_SIZE . ")";
            $logger->error($error);
            return ( 400, undef, $error );
        }

        open_path( my $fh, '<:raw', $file ) or do {
            my $error = "Cannot read registry file: $!";
            $logger->error($error);
            return ( 403, undef, $error );
        };
        my $content = do { local $/; <$fh> };
        close $fh;

        return ( 200, $content, undef );
    }

    if ( $type eq "git" ) {

        # resolve_git_raw_url returns undef when the URL format or provider is unrecognized
        my $rawurl = resolve_git_raw_url( $config{provider}, $config{url}, $config{ref} );

        unless ($rawurl) {
            my $error = "Cannot resolve git URL: $config{url}";
            $logger->error($error);
            return ( 400, undef, $error );
        }

        $logger->info("Fetching registry index from $rawurl");

        my $ua = Mojo::UserAgent->new;
        $ua->max_response_size(MAX_REGISTRY_INDEX_SIZE);
        my $res = $ua->get($rawurl)->result;

        unless ( $res->is_success ) {
            my $error = "Failed to fetch registry index: HTTP " . $res->code;
            $logger->error($error);
            return ( 502, undef, $error );
        }

        return ( 200, $res->body, undef );
    }

    return ( 400, undef, "Unknown registry type: $type" );
}

# Install a plugin from a registry.
sub install_plugin {
    my ( $namespace, $redis, $registry_id ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );

    unless ( $registry_id =~ /^REG_\d{10}$/ && $redis->exists($registry_id) ) {
        return ( 404, undef, "This registry doesn't exist." );
    }

    my ($suffix) = $registry_id =~ /^REG_(\d{10})$/;
    my $indexkey = "REG_INDEX_$suffix";

    unless ( $redis->exists($indexkey) ) {
        return ( 409, undef, "No registry index cached. Run refresh first." );
    }

    my $indexjson = $redis->get($indexkey);
    my $index    = decode_json($indexjson);
    my $plugins  = $index->{plugins};

    unless ( $plugins->{$namespace} ) {
        return ( 404, undef, "Plugin '$namespace' not found in registry." );
    }

    my $plugmeta = $plugins->{$namespace};
    my $plugpath = $plugmeta->{path};

    # Validate plugin path before any file or network access
    unless ($plugpath) {
        return ( 400, undef, "Plugin '$namespace' is missing required field 'path'." );
    }
    if ( index( $plugpath, "\0" ) >= 0 ) {
        return ( 400, undef, "Invalid plugin path (null byte)." );
    }
    if ( $plugpath =~ /\.\./ || $plugpath =~ m{^/} ) {
        return ( 400, undef, "Invalid plugin path: $plugpath" );
    }

    my %config = $redis->hgetall($registry_id);
    my $type   = $config{type};

    my $namerds = "LRR_PLUGIN_" . uc($namespace);
    my $currentpath;

    if ( $redis->hexists( $namerds, "installed_path" ) ) {
        $currentpath = $redis->hget( $namerds, "installed_path" );
    }

    my $content;

    if ( $type eq "local" ) {
        my $file = File::Spec->catfile( $config{path}, $plugpath );

        unless ( -e $file ) {
            return ( 404, undef, "Plugin file not found: $file" );
        }

        my $filesize = -s $file;
        if ( $filesize > MAX_PLUGIN_FILE_SIZE ) {
            return ( 400, undef, "Plugin file too large: $file ($filesize bytes)" );
        }

        open_path( my $fh, '<:raw', $file ) or do {
            return ( 500, undef, "Cannot read plugin file: $!" );
        };
        $content = do { local $/; <$fh> };
        close $fh;

    } elsif ( $type eq "git" ) {
        my $rawurl = resolve_git_raw_url( $config{provider}, $config{url}, $config{ref}, $plugpath );

        unless ($rawurl) {
            return ( 400, undef, "Can't resolve download URL for $plugpath" );
        }

        $logger->info("Downloading plugin from $rawurl");

        my $ua = Mojo::UserAgent->new;
        $ua->max_response_size(MAX_PLUGIN_FILE_SIZE);
        my $res = $ua->get($rawurl)->result;

        unless ( $res->is_success ) {
            my $error = "Download failed: HTTP " . $res->code;
            $logger->error($error);
            return ( 502, undef, $error );
        }

        $content = $res->body;
    } else {
        # check against type just in case
        return ( 400, undef, "Unknown registry type: $type" );
    }

    my ( $validated, $error ) = validate_managed_plugin( $content, $namespace, $plugmeta, $currentpath );
    if ($error) {
        return ( 422, undef, $error );
    }

    my $installdir  = $validated->{install_dir};
    my $installpath = $validated->{install_path};

    make_path($installdir) unless -d $installdir;

    open_path( my $fh, '>:raw', $installpath ) or do {
        my $error = "Cannot write plugin file: $!";
        $logger->error($error);
        return ( 500, undef, $error );
    };
    print $fh $content;
    close $fh;

    $logger->info("Installed plugin '$namespace' to $installpath");

    # Atomically verify registry still exists and store provenance.
    my $script = <<'LUA';
    if redis.call("EXISTS", KEYS[1]) == 0 then
        return 0
    end
    redis.call("HSET", KEYS[2], "installed_path",    ARGV[1])
    redis.call("HSET", KEYS[2], "installed_version", ARGV[2])
    redis.call("HSET", KEYS[2], "registry",          ARGV[3])
    return 1
LUA

    my $provenance_written = eval {
        $redis->eval( $script, 2, $registry_id, $namerds,
            $installpath, $plugmeta->{version}, $registry_id );
    };
    if ($@) {
        $logger->error("Redis error during provenance write for '$namespace': $@");
        # Clean up the written file since provenance was not recorded
        unlink_path($installpath);
        return ( 500, undef, "Redis error while writing provenance." );
    }
    unless ($provenance_written) {
        # Registry was deleted between our existence check and the Lua script
        unlink_path($installpath);
        return ( 409, undef, "Registry was deleted during install." );
    }

    # Use relative inc path so %INC key matches Module::Pluggable expectations.
    my $incpath = $validated->{package};
    $incpath =~ s/::/\//g;
    $incpath .= ".pm";
    eval { require $incpath };
    if ($@) {
        $logger->warn("Plugin '$namespace' installed but wouldn't load: $@");
    }

    return ( 200, $plugmeta, undef );
}

# Uninstall a plugin by deleting it from disk and cleaning up Redis.
sub uninstall_plugin {
    my ( $namespace, $redis ) = @_;

    my $logger  = get_logger( "Registry", "lanraragi" );
    my $namerds = "LRR_PLUGIN_" . uc($namespace);

    my $installpath;
    if ( $redis->hexists( $namerds, "installed_path" ) ) {
        $installpath = $redis->hget( $namerds, "installed_path" );
    }

    unless ($installpath) {
        return ( 404, undef, "Plugin '$namespace' has no install path recorded." );
    }

    if ( -e $installpath ) {
        my $canonpath = abs_path($installpath);
        my $plugindir = abs_path( File::Spec->catdir( getcwd(), "lib", "LANraragi", "Plugin" ) );
        unless ( $canonpath && $plugindir && index( $canonpath, "$plugindir/" ) == 0 ) {
            return ( 403, undef, "Can't delete plugin outside Plugin/ directory: $installpath" );
        }

        unlink_path($canonpath) or do {
            return ( 500, undef, "Couldn't delete plugin file: $!" );
        };
        $logger->info("Deleted plugin file: $canonpath");
    } else {
        $logger->warn("Plugin '$namespace' file not found at $installpath -- cleaning up Redis only.");
    }

    # Clear provenance only; preserve user config (enabled, customargs, hidden, priority, named params)
    $redis->hdel( $namerds, "installed_path", "installed_version", "registry" );

    return ( 200, 1, undef );
}

# Reconcile discovered plugins with Redis state at startup.
sub scan_plugins {
    my ($redis) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );
    $logger->info("Scanning plugins...");

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

        my $filepath = $class;
        $filepath =~ s/::/\//g;
        $filepath = File::Spec->catfile( getcwd(), "lib", "$filepath.pm" );

        push @{ $ns_map{$ns} }, { class => $class, file_path => $filepath };
    }

    # Warn on namespace duplicates
    foreach my $ns ( keys %ns_map ) {
        if ( @{ $ns_map{$ns} } > 1 ) {
            my $paths = join( ", ", map { $_->{file_path} } @{ $ns_map{$ns} } );
            $logger->warn("Duplicate namespace '$ns' found in: $paths");
        }
    }

    # Warn on case collisions (Redis keys are case-insensitive by convention)
    my %uc_map;
    foreach my $ns ( keys %ns_map ) {
        push @{ $uc_map{ uc($ns) } }, $ns;
    }
    foreach my $uc_key ( keys %uc_map ) {
        if ( @{ $uc_map{$uc_key} } > 1 ) {
            my $namespaces = join( ", ", @{ $uc_map{$uc_key} } );
            $logger->warn("Namespace case collision (shared Redis key LRR_PLUGIN_$uc_key): $namespaces");
        }
    }

    foreach my $ns ( keys %ns_map ) {
        next if @{ $ns_map{$ns} } > 1;    # skip duplicates

        my $entry    = $ns_map{$ns}[0];
        my $filepath = $entry->{file_path};
        my $namerds  = "LRR_PLUGIN_" . uc($ns);

        if ( $redis->exists($namerds) ) {

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

            $logger->info("Registering discovered plugin '$ns' at $filepath");
            $redis->hset( $namerds, "installed_path", $filepath );
        }
    }

    # Clean up orphaned Redis keys (installed_path set, but no matching discovered plugin)
    my @all_keys     = $redis->keys("LRR_PLUGIN_*");
    my %discovereduc = map { uc($_) => 1 } keys %ns_map;

    foreach my $key (@all_keys) {
        my ($nspart) = $key =~ /^LRR_PLUGIN_(.+)$/;
        # keys("LRR_PLUGIN_*") guarantees at least one char after prefix; warn if violated
        unless ($nspart) {
            $logger->warn("Unexpected Redis key format: '$key', skipping.");
            next;
        }

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

# Validate downloaded plugin content against registry metadata and filesystem state.
# Covers managed plugins only (installed via registry into Plugin/Managed/).
# Read-only
sub validate_managed_plugin {
    my ( $content, $namespace, $plugmeta, $currentpath ) = @_;

    my $plugname          = $plugmeta->{name};
    my $plugver           = $plugmeta->{version};
    my $plugpath          = $plugmeta->{path};
    my $plugtype          = $plugmeta->{type};
    my $expected_checksum = $plugmeta->{sha256};

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

    unless ( defined $expected_checksum && $expected_checksum ne "" ) {
        return ( undef, "Plugin '$namespace' is missing required field 'sha256'." );
    }
    my $actual_checksum = sha256_hex($content);
    if ( $actual_checksum ne $expected_checksum ) {
        return ( undef, "SHA-256 mismatch: expected $expected_checksum, got $actual_checksum" );
    }

    # A valid package name does not guarantee valid syntax;
    # post-install require (in install_plugin) catches that at load time.
    my ($pkg) = $content =~ /^package\s+(LANraragi::Plugin::\S+)\s*;/m;
    unless ($pkg) {
        return ( undef, "Plugin file doesn't declare a LANraragi::Plugin:: package." );
    }

    # Path safety: reject null bytes, traversal, and absolute paths.
    if ( index( $plugpath, "\0" ) >= 0 ) {
        return ( undef, "Invalid plugin path (null byte)." );
    }
    if ( $plugpath =~ /\.\./ || $plugpath =~ m{^/} ) {
        return ( undef, "Invalid plugin path: $plugpath" );
    }

    my $typedir = MANAGED_TYPE_DIRS->{$plugtype};
    unless ($typedir) {
        return ( undef, "Unknown plugin type '$plugtype'." );
    }

    # Extract filename (basename via regex; File::Basename not imported here).
    my ($filename) = $plugpath =~ m{([^/]+)$};
    unless ($filename) {
        return ( undef, "Can't extract filename from path: $plugpath" );
    }
    unless ( $filename =~ /^[A-Za-z0-9_-]+\.pm$/ ) {
        return ( undef, "Invalid plugin filename: $filename" );
    }

    my $installdir  = File::Spec->catdir( getcwd(), "lib", "LANraragi", "Plugin", "Managed", $typedir );
    my $installpath = File::Spec->catfile( $installdir, $filename );

    my ($stem) = $filename =~ /^(.+)\.pm$/;
    my $expectedpkg = "LANraragi::Plugin::Managed::${typedir}::${stem}";
    if ( $pkg ne $expectedpkg ) {
        return ( undef, "Package mismatch -- declared '$pkg' but expected '$expectedpkg'." );
    }

    # Skip install_path itself so upgrades don't self-conflict.
    my $conflict = find_package_conflict( $pkg, $installpath );
    if ($conflict) {
        return ( undef, "Package '$pkg' already exists in $conflict." );
    }

    my $nsconflict = find_namespace_conflict( $namespace, $installpath );
    if ($nsconflict) {
        return ( undef, "Namespace '$namespace' already exists in $nsconflict." );
    }

    if ( -e $installpath && ( !defined $currentpath || $currentpath ne $installpath ) ) {
        return ( undef, "Install path is already occupied: $installpath" );
    }

    return ( { install_path => $installpath, install_dir => $installdir, package => $pkg }, undef );
}

1;
