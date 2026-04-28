package LANraragi::Model::Registry;

use strict;
use warnings;
use utf8;

use Cwd qw(abs_path getcwd);
use Digest::SHA qw(sha256_hex);
use File::Path qw(make_path);
use Mojo::File;
use Mojo::JSON qw(decode_json);
use Mojo::UserAgent;

use LANraragi::Utils::Logging  qw(get_logger);
use LANraragi::Utils::Path     qw(unlink_path package_to_path);
use LANraragi::Utils::Plugins  ();
use LANraragi::Utils::Registry qw(
    resolve_git_raw_url
    find_package_conflict
    find_namespace_conflict
    validate_registry_index
    validate_registry_artifact_path
    resolve_local_registry_artifact_path
    MANAGED_TYPE_DIRS
);

# Max file sizes for slurp (files will/should never reach this size anyways but stops OOM)
use constant MAX_REGISTRY_INDEX_SIZE => 100 * 1024 * 1024;      # 100 MB
use constant MAX_PLUGIN_FILE_SIZE    => 100 * 1024 * 1024;      # 100 MB

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
# TODO(REVIEW) requires fields: created_date and updated_date.
sub create_registry {
    my ( $config, $redis ) = @_;
    my %config = %{$config};

    my $logger = get_logger( "Registry", "lanraragi" );
    $logger->info("Creating registry (type: $config{type})");

    # TODO(REVIEW): maybe set default (first) registry to REG_0000000001?
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

    # TODO(REVIEW): check stamps PR for offset consistency.
    # Atomic claim of an unused REG_<ts> hash key: Lua keeps the existence
    # check and the type write atomic so two concurrent callers cannot land
    # on the same id.
    my $claim_script = <<'LUA';
    if redis.call("EXISTS", KEYS[1]) == 1 then
        return 0
    end
    redis.call("HSET", KEYS[1], "type", ARGV[1])
    return 1
LUA

    my $registry_id;
    my $offset = 0;
    until ($registry_id) {
        my $candidate = "REG_" . ( time() + $offset );
        my $claimed   = eval { $redis->eval( $claim_script, 1, $candidate, $config{type} ) };
        if ($@) {
            $logger->error("Redis error during registry id claim: $@");
            return ( undef, "Redis error while creating registry." );
        }
        if ($claimed) {
            $registry_id = $candidate;
        } else {
            $offset++;
        }
    }

    my $registry_type   = $config{type};
    my @valid_fields    = @{ $TYPE_FIELDS{$registry_type} };

    # TODO(REVIEW) how much of this can be merged with update_registry?
    foreach my $field (@valid_fields) {
        next if $field eq "type";
        next unless defined $config{$field};
        $redis->hset( $registry_id, $field, $config{$field} );
    }

    $logger->info("Created registry '$registry_id' (name: $config{name}, type: $registry_type)");

    return ( $registry_id, undef );
}

# Get a registry's config by ID.
sub get_registry {
    my ( $registry_id, $redis ) = @_;

    # TODO(REVIEW): pull out to sub: is_valid_registry(registry_id).
    unless ( $registry_id =~ /^REG_\d{10}$/ && $redis->exists($registry_id) ) {
        get_logger( "Registry", "lanraragi" )->warn("Registry lookup failed for invalid or missing registry id '$registry_id'.");
        return ();
    }

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
# TODO(REVIEW) how much update_registry logic coincides with create-registry?
sub update_registry {
    my ( $registry_id, $redis, %updated_registry ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );
    $logger->info("Updating registry '$registry_id'");

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
            $logger->info("Source field '$field' changed on '$registry_id'; will clear cached index.");
            $indexcleared = 1;
            last;
        }
    }

    # type enum is validated by OpenAPI (enum: [git, local]) on the request body.
    my $updated_registry_type = $updated_registry{type};
    my $current_registry_type = $current_registry{type};
    my $target_registry_type  = defined $updated_registry_type ? $updated_registry_type : $current_registry_type;

    # Partial updates may omit fields already stored; merge before validating.
    my %merged = ( %current_registry, %updated_registry );

    if ( $target_registry_type eq "git" ) {
        unless ( $merged{url} ) {
            return ( 400, undef, "Git registry needs a URL." );
        }
        unless ( $merged{provider} ) {
            return ( 400, undef, "Git registry needs a provider." );
        }
    } elsif ( $target_registry_type eq "local" ) {
        unless ( $merged{path} ) {
            return ( 400, undef, "Local registry needs a path." );
        }
    }

    # If a type change is made, then registry may be left with stale or mixed type states, which we'll need to clean up.
    # TODO(REVIEW) integration test coverage for mixed type registry updates? create git -> update git -> update local -> update local -> update git -> update local -> update git (AABBABAB)
    my @fields_to_remove;
    # type is always set on a valid registry (stored at creation)
    if ( exists $updated_registry{type} && $updated_registry_type ne $current_registry_type ) { # TODO(REVIEW) is existence check required?
        $logger->info("Type change on '$registry_id': '$current_registry_type' -> '$target_registry_type'; removing stale fields.");
        @fields_to_remove = @{ $STALE_FIELDS{$target_registry_type} };
    }

    my @valid_fields = @{ $TYPE_FIELDS{$target_registry_type} };
    my %valid_set    = map { $_ => 1 } @valid_fields;
    my @fields_to_set;
    foreach my $field ( keys %updated_registry ) {
        next unless $valid_set{$field};
        $logger->debug("Setting field '$field' on '$registry_id'");
        push @fields_to_set, $field, $updated_registry{$field};
    }

    my $indexkey = "";
    if ( $indexcleared ) {
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
    if ($@) { # TODO(REVIEW) same error var thing
        $logger->error("Redis error during registry update for '$registry_id': $@");
        return ( 500, undef, "Redis error while updating registry." );
    }

    if ( $indexcleared ) {
        $logger->info("Cleared cached index for '$registry_id' due to source field change.");
    }

    return ( 200, $indexcleared, undef );
}

# Delete a registry and its cached index.
sub delete_registry {
    my ( $registry_id, $redis ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );

    unless ( $registry_id =~ /^REG_\d{10}$/ && $redis->exists($registry_id) ) {
        return ( 404, undef, "This registry doesn't exist." );
    }

    my ($suffix) = $registry_id =~ /^REG_(\d{10})$/;
    my $registry_index_key      = "REG_INDEX_$suffix";

    # Delete registry + index key
    my $script = <<'LUA';
    redis.call("DEL", KEYS[1])
    redis.call("DEL", KEYS[2])
    return 1
LUA

    eval { $redis->eval( $script, 2, $registry_id, $registry_index_key ) };
    if ($@) {
        $logger->error("Redis error during registry delete for '$registry_id': $@");
        return ( 500, undef, "Redis error while deleting registry." );
    }

    $logger->info("Deleted registry '$registry_id'.");

    return ( 200, 1, undef );
}

# Fetch registry.json from a configured registry source.
sub fetch_registry_index {
    my %registry_config = @_;

    my $logger = get_logger( "Registry", "lanraragi" );
    my $registry_type = $registry_config{type};

    if ( $registry_type eq "local" ) {
        my $path = $registry_config{path};

        if ( index( $path, "\0" ) >= 0 || $path =~ /\.\./ ) {
            my $error = "Invalid registry path (null byte or traversal).";
            $logger->error($error);
            return ( 400, undef, $error );
        }

        my $file = "$path/registry.json";

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

        my $content = eval { Mojo::File->new($file)->slurp };
        unless ( defined $content ) {
            my $error = "Cannot read registry file: $@";
            $logger->error($error);
            return ( 403, undef, $error );
        }

        return ( 200, $content, undef );
    }

    if ( $registry_type eq "git" ) {

        # resolve_git_raw_url returns undef when the URL format or provider is unrecognized
        my $rawurl = resolve_git_raw_url(
            $registry_config{provider}, $registry_config{url}, $registry_config{ref}, "registry.json"
        );

        unless ($rawurl) {
            my $error = "Cannot resolve git URL: $registry_config{url}";
            $logger->error($error);
            return ( 400, undef, $error );
        }

        $logger->info("Fetching registry index from $rawurl");

        my $ua = Mojo::UserAgent->new;
        $ua->max_response_size(MAX_REGISTRY_INDEX_SIZE);
        my $res = eval { $ua->get($rawurl)->result };
        unless ( defined $res ) {
            my $error = "Cannot reach registry: $@";
            $logger->error($error);
            return ( 502, undef, $error ); # TODO(REVIEW): should be 500
        }

        unless ( $res->is_success ) {
            my $error = "Failed to fetch registry index: HTTP " . $res->code;
            $logger->error($error);
            return ( 502, undef, $error ); # TODO(REVIEW): should be 500
        }

        return ( 200, $res->body, undef );
    }

    return ( 400, undef, "Unknown registry type: $registry_type" );
}

# Install a plugin from a registry whose index has been refreshed and cached.
# namespace, registry_id, version are required to identify the plugin to install.
# TODO(REVIEW) move to Model/Plugins.pm.
# TODO(REVIEW) what if the signature of the plugin changes from one version to the next, or across provenance, in a way which is incompatible?
# because uninstall plugin keeps configuration, this will require thought...
sub install_plugin {
    my ( $namespace, $redis, $registry_id, $version, $installed_channel ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );
    $logger->info("Installing plugin '$namespace' v$version from registry '$registry_id'");

    # registry must exist
    unless ( $registry_id =~ /^REG_\d{10}$/ && $redis->exists($registry_id) ) {
        return ( 404, undef, "This registry doesn't exist." );
    }

    # registry index must exist, otherwise require a refresh.
    my ($suffix) = $registry_id =~ /^REG_(\d{10})$/;
    my $registry_index_key = "REG_INDEX_$suffix";
    unless ( $redis->exists($registry_index_key) ) {
        return ( 409, undef, "No registry index cached. Run refresh first." );
    }

    my $registry_index_json = $redis->get($registry_index_key);
    my $registry_index      = decode_json($registry_index_json);
    my $registry_plugins    = $registry_index->{plugins};

    unless ( $registry_plugins->{$namespace} ) {
        return ( 404, undef, "Plugin '$namespace' not found in registry." );
    }

    my $plugin_root = $registry_plugins->{$namespace};

    unless ( $plugin_root->{versions} && $plugin_root->{versions}{$version} ) {
        return ( 404, undef, "Version '$version' not found for plugin '$namespace'." );
    }

    if ( defined $installed_channel ) {
        $logger->info("Installing plugin via installed channel: $installed_channel");

        # TODO(REVIEW) check dev branch for consistency (use of raw ref)
        unless ( ref $plugin_root->{channels} eq "HASH" ) {
            return ( 400, undef, "Plugin '$namespace' is missing channel data." );
        }

        # TODO(REVIEW) duplicate code
        # TODO(REVIEW) check dev branch for consistency (key chaining)
        unless ( exists $plugin_root->{channels}{$installed_channel} ) {
            return ( 400, undef, "Channel '$installed_channel' not found for plugin '$namespace'." );
        }

        # TODO(REVIEW) why does version need resolving here?
        unless ( $plugin_root->{channels}{$installed_channel} eq $version ) {
            return (
                400,
                undef,
                "Channel '$installed_channel' resolves to version '$plugin_root->{channels}{$installed_channel}', not '$version'."
            );
        }
    } else {
        $logger->info("Installing plugin without a channel.");
    }

    my $plugin_metadata = $plugin_root->{versions}{$version};
    $plugin_metadata->{type} = $plugin_root->{type};

    # Validate plugin artifact path.
    my $plugpath = $plugin_metadata->{artifact};
    my ( $artifact_valid, $artifact_error ) = validate_registry_artifact_path($plugpath);
    unless ( $artifact_valid ) {
        return ( 400, undef, $artifact_error );
    }

    my %registry_config  = $redis->hgetall($registry_id);
    my $registry_type    = $registry_config{type};

    my $namerds = "LRR_PLUGIN_" . uc($namespace);
    my $currentpath;

    if ( $redis->hexists( $namerds, "installed_path" ) ) {
        # TODO(REVIEW): move to sub `resolve_installed_path`. (variant)
        $currentpath = getcwd() . "/lib/" . $redis->hget( $namerds, "installed_path" );
    }

    my $plugin_content;

    if ( $registry_type eq "local" ) {
        my ( $root_canon, $file_canon, $resolve_error ) =
            resolve_local_registry_artifact_path( $registry_config{path}, $plugpath );
        if ($resolve_error) {
            return ( 400, undef, $resolve_error );
        }

        unless ( -e $file_canon ) {
            return ( 404, undef, "Plugin file not found: $file_canon" );
        }

        unless ( -f $file_canon ) {
            return ( 400, undef, "Plugin artifact is not a regular file: $file_canon" );
        }

        my $filesize = -s $file_canon;
        if ( $filesize > MAX_PLUGIN_FILE_SIZE ) {
            return ( 400, undef, "Plugin file too large: $file_canon ($filesize bytes)" );
        }

        $plugin_content = eval { Mojo::File->new($file_canon)->slurp };
        unless ( defined $plugin_content ) {
            return ( 500, undef, "Cannot read plugin file: $@" );
        }

    } elsif ( $registry_type eq "git" ) {
        my $rawurl = resolve_git_raw_url( $registry_config{provider}, $registry_config{url}, $registry_config{ref}, $plugpath );

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

        $plugin_content = $res->body;
    } else {
        # check against type just in case
        $logger->error("Unknown registry type '$registry_type' while installing plugin '$namespace' from registry '$registry_id'.");
        return ( 400, undef, "Unknown registry type: $registry_type" );
    }

    # Check that plugins are installed under "Plugins/Managed/".
    my ( $validated, $error ) = validate_managed_plugin( $plugin_content, $namespace, $plugin_metadata, $currentpath );
    if ($error) {
        $logger->warn("Managed plugin validation failed for '$namespace' from registry '$registry_id': $error");
        return ( 422, undef, $error );
    }

    my $installdir      = $validated->{install_dir};
    my $installpath     = $validated->{install_path};
    my $incpath         = package_to_path( $validated->{package} );
    my $install_relpath = substr( $installpath, length( getcwd() . "/lib/" ) ); # TODO(REVIEW) Paths compliance?
    my $channel_value   = defined $installed_channel ? $installed_channel : ""; # TODO(REVIEW) confirm channel_value accepts "" fallback

    make_path($installdir) unless -d $installdir;

    eval { Mojo::File->new($installpath)->spew($plugin_content) };
    if ($@) {
        my $error = "Cannot write plugin file during installation: $@";
        $logger->error($error);
        return ( 500, undef, $error );
    }

    $logger->info("Installed plugin '$namespace' to $installpath");

    # Verify registry exists and store updated plugin provenance.
    # TODO(REVIEW) integration coverage for plugin install + metadata confirmation.
    my $script = <<'LUA';
    if redis.call("EXISTS", KEYS[1]) == 0 then
        return 0
    end
    redis.call("HINCRBY", KEYS[2], "installed_generation", 1)
    redis.call("HSET",    KEYS[2], "installed_path",     ARGV[1])
    redis.call("HSET",    KEYS[2], "installed_version",  ARGV[2])
    redis.call("HSET",    KEYS[2], "installed_registry", ARGV[3])
    redis.call("HSET",    KEYS[2], "installed_sha256",   ARGV[4])
    if ARGV[5] ~= "" then
        redis.call("HSET", KEYS[2], "installed_channel", ARGV[5])
    else
        redis.call("HDEL", KEYS[2], "installed_channel")
    end
    return 1
LUA

    my $provenance_written = eval {
        $redis->eval(
            $script, 2, $registry_id, $namerds,
            $install_relpath, $plugin_metadata->{version}, $registry_id, $plugin_metadata->{sha256}, $channel_value
        );
    };
    if ($@) {
        $logger->error("Redis error during provenance write for '$namespace': $@");
        # Clean up the written file since provenance was not recorded
        unlink_path($installpath); # TODO(REVIEW) why remove?
        return ( 500, undef, "Redis error while writing provenance." );
    }
    unless ($provenance_written) {
        # Registry was deleted between our existence check and the Lua script
        unlink_path($installpath); # TODO(REVIEW) why remove?
        return ( 409, undef, "Registry was deleted during install." );
    }

    # If the upgrade landed at a new path (type-change between published versions, in violation
    # of spec invariance), remove the old artifact so scan_plugins doesn't rediscover it.
    if ( defined $currentpath && $currentpath ne $installpath && -e $currentpath ) {
         # TODO(REVIEW) why remove?
        unlink_path($currentpath) or $logger->warn("Could not remove stale plugin file at $currentpath: $!");
    }

    # Reload INC with new plugin/incpath.
    delete $INC{$incpath}; # TODO(REVIEW) is it possible that incpath in INC does not equal incpath in package?
    eval { require $incpath };
    if ($@) {
        $logger->warn("Plugin '$namespace' installed but wouldn't load: $@");
    }

    my %installed_meta = (
        name               => $plugin_metadata->{name},
        version            => $plugin_metadata->{version},
        installed_registry => $registry_id,
        installed_sha256   => $plugin_metadata->{sha256},
        installed_channel  => ( $channel_value ne "" ? $channel_value : undef ), # TODO(REVIEW): why channel either "" or undef at times? Inconsistent.
    );

    return ( 200, \%installed_meta, undef ); # TODO(REVIEW): why ref?
}

# Uninstall a plugin by deleting it from disk and cleaning up Redis.
# Does not remove configuration settings.
# TODO(REVIEW) move to Model/Plugins.pm.
# TODO(REVIEW) sequence of install/uninstall integration tests + metadata verification?
sub uninstall_plugin {
    my ( $namespace, $redis ) = @_;

    my $logger  = get_logger( "Registry", "lanraragi" );
    my $namerds = "LRR_PLUGIN_" . uc($namespace);
    $logger->info("Uninstalling plugin '$namespace'");

    my $installpath;
    if ( $redis->hexists( $namerds, "installed_path" ) ) {
        # TODO(REVIEW) ditto
        $installpath = getcwd() . "/lib/" . $redis->hget( $namerds, "installed_path" );
    }

    unless ($installpath) {
        return ( 404, undef, "Plugin '$namespace' has no install path recorded." );
    }

    my $source = infer_plugin_source( $namerds, $redis );

    # We don't touch builtin plugins!
    # TODO(REVIEW) what if a builtin plugin gets added in the future via an update which coincidentally conflicts with a user's managed plugin?
    # Will have to think about that...
    if ( $source eq "builtin" ) {
        return ( 403, undef, "Cannot uninstall built-in plugin '$namespace'." );
    }

    # Delete the plugin file (only if it's actually inside LRR lib)
    if ( -e $installpath ) {
        my $canonpath = abs_path($installpath);
        my $plugindir = abs_path( getcwd() . "/lib/LANraragi/Plugin" );
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

    # Clear provenance from plugin.
    $redis->hdel(
        $namerds,
        "installed_path",
        "installed_version",
        "installed_registry",
        "installed_sha256",
        "installed_channel",
        "installed_generation"
    );

    return ( 200, 1, undef );
}

# Reconcile discovered plugins with Redis state at startup.
# TODO(REVIEW) move to Model/Plugins.pm.
sub scan_plugins {
    my ($redis) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );
    $logger->info("Scanning plugins...");

    my @discovered = LANraragi::Utils::Plugins::plugins();

    # Build namespace -> [class, file_path] map, detect duplicates
    # TODO(REVIEW): ns_map needs an explanation of derivation process (and when derivation stops) and usage.
    # preferably: ns_map construction stop stage needs to be detailed and when reads are made != when writes are made.
    my %ns_map;

    foreach my $class (@discovered) {
        # Module::Pluggable may discover non-plugin classes; skip those
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

        my $filepath = package_to_path($class);

        push @{ $ns_map{$ns} }, { class => $class, file_path => $filepath };
    }

    $logger->info("Discovered " . scalar( keys %ns_map ) . " plugin namespace(s).");

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

    # Skip duplicates
    foreach my $ns ( keys %ns_map ) {
        next if @{ $ns_map{$ns} } > 1;

        my $entry    = $ns_map{$ns}[0];
        my $filepath = $entry->{file_path};
        my $namerds  = "LRR_PLUGIN_" . uc($ns);

        my $current_path = $redis->hget( $namerds, "installed_path" );
        if ( defined $current_path && $current_path eq $filepath ) {
            next; # skip if database already tracks said path
        }

        # Self-heal stale or missing installed_path: discovery is the source of truth.
        # TODO(REVIEW): when a plugin is discovered and not present in database, wouldn't this be considered a spontaneous "installation"?
        $logger->debug("Plugin '$ns': setting installed_path to '$filepath'.");
        $redis->hset( $namerds, "installed_path", $filepath );
    }

    # Clean up orphaned Redis keys (installed_path set, but no matching discovered plugin)
    my @all_keys     = $redis->keys("LRR_PLUGIN_*");
    my %discovereduc = map { uc($_) => 1 } keys %ns_map;
    my $lib_prefix   = getcwd() . "/lib/";
    $logger->debug("Orphan scan: " . scalar @all_keys . " Redis keys, " . scalar( keys %discovereduc ) . " discovered.");

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
                if ( -e $lib_prefix . $path ) {
                    $logger->warn("Plugin key '$key' (installed_path: $path) not discovered but file exists -- skipping removal.");
                    next;
                }
                $logger->warn("Orphaned plugin key '$key' (installed_path: $path) -- plugin not discovered. Clearing provenance.");
            } else {
                $logger->warn("Orphaned plugin key '$key' -- plugin not discovered. Clearing provenance.");
            }
            $redis->hdel(
                $key,
                "installed_path",
                "installed_version",
                "installed_registry",
                "installed_sha256",
                "installed_channel",
                "installed_generation"
            );
        }
    }

    $logger->info("Plugin scan complete.");
}

# Infer plugin source from Redis provenance or install path.
# source is either "managed", "sideloaded", or "builtin".
sub infer_plugin_source {
    my ( $namerds, $redis ) = @_;

    if ( $redis->hexists( $namerds, "installed_registry" ) ) {
        my $reg = $redis->hget( $namerds, "installed_registry" );
        return "managed" if $reg && $reg ne "";
    }

    if ( $redis->hexists( $namerds, "installed_path" ) ) {
        my $path = $redis->hget( $namerds, "installed_path" );
        return "sideloaded" if $path && $path =~ /Sideloaded/;
        return "managed"    if $path && $path =~ m{Plugin/Managed/};
    }

    # TODO(REVIEW): is builtin guaranteed to be under the expected path pattern?
    return "builtin";
}

# Validate downloaded plugin content against registry metadata and filesystem state.
# Covers managed plugins only (installed via registry into Plugin/Managed/).
# Read-only
# TODO(REVIEW) move to Model/Plugins.pm.
sub validate_managed_plugin {
    my ( $content, $namespace, $plugmeta, $currentpath ) = @_;

    my $plugname          = $plugmeta->{name};
    my $plugver           = $plugmeta->{version};
    my $plugpath          = $plugmeta->{artifact};
    my $plugtype          = $plugmeta->{type};
    my $expected_checksum = $plugmeta->{sha256};

    unless ($plugname) {
        return ( undef, "Plugin '$namespace' is missing required field 'name'." );
    }
    unless ($plugver) {
        return ( undef, "Plugin '$namespace' is missing required field 'version'." );
    }
    unless ($plugpath) {
        return ( undef, "Plugin '$namespace' is missing required field 'artifact'." );
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

    my $installdir  = getcwd() . "/lib/LANraragi/Plugin/Managed/$typedir";
    my $installpath = "$installdir/$filename";

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
