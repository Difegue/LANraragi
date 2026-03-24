package LANraragi::Model::Plugins;

use v5.36;
use experimental 'try';

use strict;
use warnings;
use utf8;
use feature 'fc';

use Cwd qw(getcwd);
use Digest::SHA qw(sha256_hex);
use File::Path qw(make_path);
use Redis;
use Encode;
use Mojo::File;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::UserAgent;
use Data::Dumper;

use LANraragi::Utils::String   qw(trim);
use LANraragi::Utils::Database qw(set_tags set_title set_summary);
use LANraragi::Utils::Generic  qw(exec_with_lock_pure);
use LANraragi::Utils::Archive  qw(extract_thumbnail);
use LANraragi::Utils::Logging  qw(get_logger);
use LANraragi::Utils::Tags     qw(rewrite_tags split_tags_to_array);
use LANraragi::Utils::Plugins  qw(get_plugin_parameters get_plugin register_plugin unregister_plugin);
use LANraragi::Utils::PluginState qw(record_load_success signal_uninstalled signal_updated);
use LANraragi::Utils::Redis    qw(redis_decode);
use LANraragi::Utils::Path     qw(create_path package_to_path);
use LANraragi::Utils::Registry qw(
    fetch_registry_resource
    find_package_conflict
    find_namespace_conflict
    validate_registry_artifact_path
    resolve_max_version
    MANAGED_TYPE_DIRS
);
use LANraragi::Model::Registry;

# Max plugin file size for slurp (files will/should never reach this size anyways but stops OOM)
use constant MAX_PLUGIN_FILE_SIZE => 100 * 1024 * 1024;      # 100 MB

# Sub used by Auto-Plugin.
sub exec_enabled_plugins_on_file ($id) {

    my $logger = get_logger( "Auto-Plugin", "lanraragi" );

    $logger->info("Executing enabled metadata plugins on archive with id $id.");

    my $successes = 0;
    my $failures  = 0;
    my $addedtags = 0;
    my $newtitle  = "";

    my @plugins = LANraragi::Utils::Plugins::get_enabled_plugins("metadata");

    # If the regex plugin is in the list, make sure it's ran first.
    # TODO: Make plugin exec order configurable
    foreach my $plugin (@plugins) {
        if ( $plugin->{namespace} eq "regexplugin" ) {
            my $regex_plugin = $plugin;

            # Remove element from array
            @plugins = grep { $_->{namespace} ne "regexplugin" } @plugins;
            unshift @plugins, $regex_plugin;
            last;
        }
    }

    foreach my $pluginfo (@plugins) {
        my $name   = $pluginfo->{namespace};
        my %args   = get_plugin_parameters($name);
        my $plugin = get_plugin($name);
        my %plugin_result;

        my %pluginfo = $plugin->plugin_info();

        %plugin_result = exec_metadata_plugin( $plugin, $id, %args );

        if ( exists $plugin_result{error} ) {
            $failures++;
            $logger->error( $plugin_result{error} );
            next;
        }

        # update metadata on lock
        my ($acquired, undef) = exec_with_lock_pure([ "archive-write:$id" ], sub {
            $successes++;

            #If the plugin exec returned metadata, add it
            set_tags( $id, $plugin_result{new_tags}, 1 );

            # Sum up all the added tags for later reporting.
            # This doesn't take into account tags that are added twice
            # (e.g by different plugins), but since this is more meant to show
            # if the plugins added any data at all it's fine.
            my @added_tags = split( ',', $plugin_result{new_tags} );
            $addedtags += @added_tags;

            if ( exists $plugin_result{title} ) {
                set_title( $id, $plugin_result{title} );

                $newtitle = $plugin_result{title};
                $logger->debug("Changing title to $newtitle. (Will do nothing if title is blank)");
            }

            if ( exists $plugin_result{summary} ) {
                set_summary( $id, $plugin_result{summary} );
                $logger->debug("Summary has been changed.");    # don't put the new summary in logs, it can be huge
            }
        });
        unless ( $acquired ) {
            $logger->error("Write lock already acquired for archive $id.");
            $failures++;
        }
    }

    return ( $successes, $failures, $addedtags, $newtitle );
}

# Unlike the two other methods, exec_login_plugin takes a plugin name and does the Redis lookup itself.
# Might be worth consolidating this later.
sub exec_login_plugin ($plugname) {

    my $ua     = Mojo::UserAgent->new;
    my $logger = get_logger( "Plugin System", "lanraragi" );

    if ($plugname) {
        $logger->debug("Calling matching login plugin $plugname.");
        my $loginplugin = get_plugin($plugname);
        my %loginargs   = get_plugin_parameters($plugname);

        my $loggedinua;
        if ( has_old_style_params(%loginargs) ) {
            $loggedinua = $loginplugin->do_login( @{ $loginargs{customargs} } );
        } else {
            $loggedinua = $loginplugin->do_login( \%loginargs );
        }

        if ( ref($loggedinua) eq "Mojo::UserAgent" ) {
            return $loggedinua;
        } else {
            $logger->error("Plugin did not return a Mojo::UserAgent object!");
        }

    } else {
        $logger->debug("No login plugin specified, returning empty UserAgent.");
    }

    return $ua;
}

sub exec_script_plugin ( $plugin, %settings ) {

    no warnings 'experimental::try';

    try {
        my %pluginfo = $plugin->plugin_info();
        my $ua       = exec_login_plugin( $pluginfo{login_from} );

        # Bundle all the potentially interesting info in a hash
        my %infohash = (
            user_agent    => $ua,
            oneshot_param => $settings{'oneshot'}    # for old style plugins compatibility
        );

        # Scripts don't have any predefined metadata in their spec so they're just ran as-is.
        # They can return whatever the heck they want in their hash as well, they'll just be shown as-is in the API output.
        if ( has_old_style_params(%settings) ) {
            return $plugin->run_script( \%infohash, @{ $settings{customargs} } );
        } else {
            return $plugin->run_script( \%infohash, \%settings );
        }
    } catch ($e) {
        return ( error => $e );
    }
}

sub exec_download_plugin ( $plugin, $input, $tempdir, @settings ) {

    my $logger = get_logger( "Plugin System", "lanraragi" );

    my %pluginfo = $plugin->plugin_info();
    my $ua       = exec_login_plugin( $pluginfo{login_from} );

    # Bundle all the potentially interesting info in a hash
    my %infohash = (
        user_agent       => $ua,
        url              => $input,
        tempdir          => $tempdir
    );

    # Downloader plugins take an URL, and return...another URL, which we can download through the user-agent.
    # OR they can directly return a file path to a file they've already downloaded.
    my %result = $plugin->provide_url( \%infohash, @settings );

    if ( exists $result{error} ) {
        $logger->info( "Downloader plugin failed to provide an URL, aborting now. Error: " . $result{error} );
        return \%result;
    }

    if ( exists $result{download_url} ) {
        # Add the result URL to the infohash and return that.
        $infohash{download_url} = $result{download_url};
        return \%infohash;
    } elsif ( exists $result{file_path} ) {
        # Plugin has already downloaded the file to a path
        $logger->info( "Downloader plugin directly provided file at: " . $result{file_path} );
        # Add the file path to the infohash and return that
        $infohash{file_path} = $result{file_path};
        return \%infohash;
    }

    return ( error => "Plugin ran to completion but didn't provide a final URL or file path for us to use." );
}

# Execute a specified plugin on a file, described through its Redis ID.
sub exec_metadata_plugin ( $plugin, $id, %args ) {

    no warnings 'experimental::try';

    my $logger = get_logger( "Plugin System", "lanraragi" );

    if ( !$id ) {
        return ( error => "Tried to call a metadata plugin without providing an id." );
    }

    my $redis = LANraragi::Model::Config->get_redis;
    my %hash  = $redis->hgetall($id);

    my ( $name, $title, $tags, $file, $thumbhash ) = @hash{qw(name title tags file thumbhash)};

    ( $_ = redis_decode($_) ) for ( $name, $title, $tags );

    # If the thumbnail hash is empty or undefined, we'll generate it here.
    unless ( length $thumbhash ) {
        $logger->info("Thumbnail hash invalid, regenerating.");
        my $thumbdir = LANraragi::Model::Config->get_thumbdir;
        $thumbhash = "";

        try {
            extract_thumbnail( $thumbdir, $id, 1, 1, 1 );
            $thumbhash = $redis->hget( $id, "thumbhash" );
            $thumbhash = redis_decode($thumbhash);
        } catch ($e) {
            $logger->warn("Error building thumbnail: $e");
        }
    }
    $redis->quit();

    my %returnhash;
    try {
        # Hand it off to the plugin here.
        # If the plugin requires a login, execute that first to get a UserAgent
        my %pluginfo = $plugin->plugin_info();
        my $ua       = exec_login_plugin( $pluginfo{login_from} );

        # Bundle all the potentially interesting info in a hash
        my %infohash = (
            archive_id     => $id,
            archive_title  => $title,
            existing_tags  => $tags,
            thumbnail_hash => $thumbhash,
            file_path      => create_path( $file ),
            user_agent     => $ua,
            oneshot_param  => $args{'oneshot'}    # for old style plugins compatibility
        );

        my %newmetadata;

        if ( has_old_style_params(%args) ) {
            %newmetadata = $plugin->get_tags( \%infohash, @{ $args{customargs} } );
        } else {
            %newmetadata = $plugin->get_tags( \%infohash, \%args );
        }

        # TODO: remove this block after changing all the metadata plugins
        #Error checking
        if ( exists $newmetadata{error} ) {

            #Return the hash as-is.
            #It already has an "error" key, which will be read by the client.
            #No need for more processing.
            return %newmetadata;
        }

        my @tagarray = split_tags_to_array( $newmetadata{tags} );
        my $newtags  = "";

        # Process new metadata.
        if ( LANraragi::Model::Config->enable_tagrules ) {
            $logger->info("Applying tag rules...");
            my @rules = LANraragi::Utils::Database::get_computed_tagrules();
            @tagarray = rewrite_tags( \@tagarray, \@rules );
        }

        foreach my $tagtoadd (@tagarray) {

            # Only proceed if the tag isn't already in redis
            unless ( index( uc($tags), uc($tagtoadd) ) != -1 ) {
                $newtags .= " $tagtoadd,";
            }
        }

        # Strip last comma and return processed tags in a hash
        chop($newtags);
        %returnhash = ( new_tags => $newtags );

        # Indicate a title change, if the plugin reports one
        if ( exists $newmetadata{title} && LANraragi::Model::Config->can_replacetitles ) {
            my $newtitle = $newmetadata{title};
            $newtitle = trim($newtitle);
            $returnhash{title} = $newtitle;
        }

        # Include updated summary data in response
        if ( exists $newmetadata{summary} ) {
            $returnhash{summary} = $newmetadata{summary};
        }

    } catch ($e) {
        return ( error => $e );
    }

    return %returnhash;
}

# TODO: remove after the deprecation period
sub has_old_style_params (%params) {
    return ( exists $params{'customargs'} );
}

# Install a plugin from a registry whose index has been refreshed and cached.
# namespace, registry_id, version are required to identify the plugin to install.
# LRR assumes managed plugins are hash-style, and doesn't handle signature 
# changes from one plugin version to another.
sub install_plugin {
    my ( $namespace, $redis, $registry_id, $version ) = @_;
    my $logger  = get_logger( "Registry", "lanraragi" );
    my $namerds = "LRR_PLUGIN_" . uc($namespace);

    # registry validation
    # check that registry exists, and that registry index exists.
    my ( $registry, $lookup_status, $lookup_error ) =
        LANraragi::Model::Registry::get_registry( $registry_id, $redis );
    return ( $lookup_status, undef, $lookup_error ) unless $registry;
    my ($registry_timestamp) = $registry_id =~ /^REG_(\d{10})$/;
    my $registry_index_key = "REG_INDEX_$registry_timestamp";
    unless ( $redis->exists($registry_index_key) ) {
        return ( 409, undef, "No registry index cached. Run refresh first." );
    }

    # Plugin installable validation
    my $registry_index_json = $redis->get($registry_index_key);
    my $registry_index      = decode_json($registry_index_json);
    my $registry_plugins    = $registry_index->{plugins};
    unless ( $registry_plugins->{$namespace} ) {
        return ( 404, undef, "Plugin '$namespace' not found in registry." );
    }
    my $plugin_record = $registry_plugins->{$namespace};
    unless ( ref $plugin_record->{versions} eq "HASH" && keys %{ $plugin_record->{versions} } ) {
        return ( 404, undef, "No versions found for plugin '$namespace'." );
    }
    $version = resolve_max_version($plugin_record) unless defined $version;
    unless ( $plugin_record->{versions}{$version} ) {
        return ( 404, undef, "Version '$version' not found for plugin '$namespace'." );
    }

    # Get the plugin metadata by version and validate artifact path
    my $plugin_metadata     = $plugin_record->{versions}{$version};
    my $artifact_path       = $plugin_metadata->{artifact};
    my ( $artifact_valid, $artifact_error ) = validate_registry_artifact_path($artifact_path);
    unless ( $artifact_valid ) {
        return ( 400, undef, $artifact_error );
    }

    my $abs_installed_path;
    if ( $redis->hexists( $namerds, "installed_path" ) ) {
        $abs_installed_path = resolve_installed_path( $redis->hget( $namerds, "installed_path" ) );
    }

    # Retrieve get the plugin contents
    my ( $fetch_status, $plugin_content, $fetch_error ) =
        fetch_registry_resource( $registry, $artifact_path, MAX_PLUGIN_FILE_SIZE );
    unless ( $fetch_status == 200 ) {
        $logger->warn(
            "Failed to fetch plugin artifact '$artifact_path' for '$namespace' from registry '$registry_id': $fetch_error"
        );
        return ( $fetch_status, undef, $fetch_error );
    }

    # Post-retrieval validation and extract installation data
    my $plugin_type             = $plugin_record->{type};
    my ( $validated, $error )   = validate_managed_plugin( $plugin_content, $namespace, $plugin_metadata, $plugin_type, $abs_installed_path );
    if ($error) {
        $logger->warn("Managed plugin validation failed for '$namespace' from registry '$registry_id': $error");
        return ( 422, undef, $error );
    }
    my $install_dir     = $validated->{install_dir};
    my $install_path    = $validated->{install_path};
    my $install_relpath = package_to_path( $validated->{package} );

    # Begin installation with rollback
    $logger->info("Installing plugin '$namespace' v$version from registry '$registry_id'");
    make_path($install_dir) unless -d $install_dir;
    my $op_desc = "install of plugin '$namespace' (version=$version, registry=$registry_id)";
    my @undo;
    my $do_rollback = sub {
        my ($reason) = @_;
        $logger->error("$op_desc failed: $reason; attempting rollback");
        while ( my $entry = pop @undo ) {
            my ( $stage, $undo_sub ) = @$entry;
            my $undo_err = $undo_sub->();
            if ( defined $undo_err ) {
                $logger->error("rollback of $op_desc failed during $stage: $undo_err");
                return ( 500, undef,
                    "Plugin '$namespace' failed and rollback was incomplete; manual cleanup may be required." );
            }
        }
        return;
    };

    my $backup_path;
    my $require_attempted = 0;
    if ( -e $install_path ) {
        # stage: create backup of plugin
        # rollback: restore from backup; if require was attempted, reload old plugin
        $backup_path = "$install_path.rollback";
        unlink $backup_path if -e $backup_path;
        unless ( rename $install_path, $backup_path ) {
            my $err = "$!";
            $logger->error("Cannot back up existing artifact at $install_path: $err");
            return ( 500, undef, "Cannot back up existing artifact: $err" );
        }
        push @undo, [
            "restore old_plugin_metadata artifact from $backup_path",
            sub {
                return "$!"     unless rename( $backup_path, $install_path );
                return          unless $require_attempted;
                delete $INC{$install_relpath};
                my $ok = eval { no warnings 'redefine'; require $install_relpath; 1 };
                $ok ? undef : "$@";
            },
        ];
    }

    # stage: ensure new plugin is written to install_path
    # rollback: remove install_path file
    eval { Mojo::File->new($install_path)->spew($plugin_content) };
    if ($@) {
        my $err = $@;
        if ( my @resp = $do_rollback->("Cannot write plugin file: $err") ) {
            return @resp;
        }
        return ( 500, undef, "Cannot write plugin file during installation: $err" );
    }
    push @undo, [
        "unlink artifact at $install_path",
        sub {
            return unless -e $install_path;
            unlink($install_path) ? undef : "$!";
        },
    ];

    # At this point, the file operation part of installation is complete!
    $logger->info("Installed plugin '$namespace' to $install_path");

    # stage: update database with new plugin provenance
    # rollback: restore old plugin provenance
    my %old_plugin_metadata;
    for my $field (qw(installed_path installed_version installed_registry installed_sha256 type)) {
        my $val = $redis->hget( $namerds, $field );
        $old_plugin_metadata{$field} = $val if defined $val;
    }
    my $provenance_script = <<~'LUA';
        if redis.call("EXISTS", KEYS[1]) == 0 then
            return 0
        end
        redis.call("HSET", KEYS[2], "installed_path",     ARGV[1])
        redis.call("HSET", KEYS[2], "installed_version",  ARGV[2])
        redis.call("HSET", KEYS[2], "installed_registry", ARGV[3])
        redis.call("HSET", KEYS[2], "installed_sha256",   ARGV[4])
        redis.call("HSET", KEYS[2], "type",               ARGV[5])
        return 1
        LUA
    my $restore_script = <<~'LUA';
        redis.call("HDEL", KEYS[1], "installed_path", "installed_version", "installed_registry", "installed_sha256", "type")
        for i = 1, #ARGV, 2 do
            redis.call("HSET", KEYS[1], ARGV[i], ARGV[i + 1])
        end
        return 1
        LUA
    my $provenance_written = eval {
        $redis->eval(
            $provenance_script, 2, $registry_id, $namerds,
            $install_relpath,
            $plugin_metadata->{version},
            $registry_id,
            $plugin_metadata->{sha256},
            $plugin_type
        );
    };
    if ($@) {
        my $err = $@;
        if ( my @resp = $do_rollback->("Redis error during provenance write: $err") ) {
            return @resp;
        }
        return ( 500, undef, "Redis error while writing provenance." );
    }
    unless ($provenance_written) {
        if ( my @resp = $do_rollback->("Registry was deleted during install") ) {
            return @resp;
        }
        return ( 409, undef, "Registry was deleted during install." );
    }
    push @undo, [
        ( exists $old_plugin_metadata{installed_path}
            ? "restore old_plugin_metadata provenance for $namerds"
            : "clear provenance for $namerds" ),
        sub {
            my @argv;
            for my $field (qw(installed_path installed_version installed_registry installed_sha256 type)) {
                push @argv, $field, $old_plugin_metadata{$field} if exists $old_plugin_metadata{$field};
            }
            eval { $redis->eval( $restore_script, 1, $namerds, @argv ) };
            $@ ? "$@" : undef;
        },
    ];

    # stage: reload plugin module
    $require_attempted = 1;
    delete $INC{$install_relpath};
    eval { require $install_relpath };
    my $require_error = $@;
    if ($require_error) {
        delete $INC{$install_relpath}; # clear out undef resulting from require failure
        if ( my @resp = $do_rollback->("Plugin '$namespace' failed to load: $require_error") ) {
            return @resp;
        }
        return ( 422, undef, "Plugin '$namespace' failed to load: $require_error" );
    }

    if ( $backup_path && -e $backup_path ) {
        unlink $backup_path or $logger->warn("Could not remove rollback backup at $backup_path: $!");
    }

    # post-install signalling
    signal_updated( $redis, $namespace );
    record_load_success( $redis, $namespace );
    $logger->debug("Plugin registered for '$namespace'");

    my %installed_meta = (
        name               => $plugin_metadata->{name},
        version            => $plugin_metadata->{version},
        registry           => $registry_id,
        sha256             => $plugin_metadata->{sha256},
    );
    return ( 200, \%installed_meta, undef );
}

# Uninstall a plugin by deleting it from disk and cleaning up Redis.
# Does not remove configuration settings.
sub uninstall_plugin {
    my ( $namespace, $redis ) = @_;

    my $logger  = get_logger( "Registry", "lanraragi" );
    my $namerds = "LRR_PLUGIN_" . uc($namespace);
    $logger->info("Uninstalling plugin '$namespace'");

    # Ensure an existing install path for uninstall
    my $abs_installed_path;
    if ( $redis->hexists( $namerds, "installed_path" ) ) {
        $abs_installed_path = resolve_installed_path( $redis->hget( $namerds, "installed_path" ) );
    }
    unless ($abs_installed_path) {
        return ( 404, "Plugin '$namespace' has no install path recorded." );
    }

    # We don't touch builtin plugins!
    my $plugin_origin = infer_plugin_origin( $namerds, $redis );
    if ( $plugin_origin eq "builtin" ) {
        return ( 403, "Cannot uninstall built-in plugin '$namespace'." );
    }

    if ( -e $abs_installed_path ) {
        unlink $abs_installed_path or do {
            return ( 500, "Couldn't delete plugin file: $!" );
        };
        $logger->info("Deleted plugin file: $abs_installed_path");
    } else {
        $logger->warn("Plugin '$namespace' file not found at $abs_installed_path -- cleaning up Redis only.");
    }

    unregister_plugin( $redis, $namespace );
    signal_uninstalled( $redis, $namespace );
    $logger->info("Uninstalled plugin: '$namespace'");

    return ( 200, undef );
}

# Reconcile discovered plugins with Redis registration state.
sub scan_plugins {
    my ($redis) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );
    $logger->info("Scanning plugins...");

    # Build a hash of discovered namespace -> arrayref of class/file_path hashrefs,
    # skip on validation/general failures
    my %discovered_ns_map;
    my @discovered_plugins = LANraragi::Utils::Plugins::plugins();
    foreach my $class (@discovered_plugins) {
        # Module::Pluggable may discover non-plugin classes; skip those
        unless ( $class->can('plugin_info') ) {
            $logger->warn("Non-plugin class detected; skipping.");
            next;
        }
        my %plugin_info;
        eval { %plugin_info = $class->plugin_info() };
        if ($@) {
            $logger->warn("Plugin $class failed plugin_info(): $@");
            next;
        }
        my $namespace = $plugin_info{namespace};
        unless ($namespace) {
            $logger->warn("Plugin $class has no namespace, skipping.");
            next;
        }
        my $plugin_type = $plugin_info{type};
        unless ($plugin_type) {
            $logger->warn("Plugin $class (namespace '$namespace') has no type, skipping.");
            next;
        }
        my $filepath = package_to_path($class);
        push @{ $discovered_ns_map{$namespace} }, { class => $class, file_path => $filepath, type => $plugin_type };
    }
    $logger->debug("Discovered " . scalar( keys %discovered_ns_map ) . " plugin namespace(s).");

    # Warn on filepath duplicates per namespace
    foreach my $namespace ( keys %discovered_ns_map ) {
        if ( @{ $discovered_ns_map{$namespace} } > 1 ) {
            my $duplicate_paths = join( ", ", map { $_->{file_path} } @{ $discovered_ns_map{$namespace} } );
            $logger->warn("Duplicate namespace '$namespace' found in: $duplicate_paths");
        }
    }

    # Warn on case collisions (Redis keys are case-insensitive by convention)
    my %uc_map;
    foreach my $namespace ( keys %discovered_ns_map ) {
        push @{ $uc_map{ uc($namespace) } }, $namespace;
    }
    foreach my $uc_key ( keys %uc_map ) {
        if ( @{ $uc_map{$uc_key} } > 1 ) {
            my $namespaces = join( ", ", @{ $uc_map{$uc_key} } );
            $logger->warn("Namespace case collision (shared Redis key LRR_PLUGIN_$uc_key): $namespaces");
        }
    }

    # Register first plugin of every discovered namespace
    foreach my $namespace ( keys %discovered_ns_map ) {
        next if @{ $discovered_ns_map{$namespace} } > 1;

        my $first_entry     = $discovered_ns_map{$namespace}[0];
        my $plugin_path     = $first_entry->{file_path};
        my $plugin_type     = $first_entry->{type};
        my $namerds         = "LRR_PLUGIN_" . uc($namespace);
        my $recorded_path   = $redis->hget( $namerds, "installed_path" );
        my $recorded_type   = $redis->hget( $namerds, "type" );

        if ( defined $recorded_path
            && $recorded_path eq $plugin_path
            && defined $recorded_type
            && $recorded_type eq $plugin_type ) {
            $logger->debug("Plugin already registered and consistent, skipping: $namespace");
            next; # skip if database already tracks said path and type
        }

        $logger->debug("Plugin '$namespace': setting installed_path to '$plugin_path' (type=$plugin_type).");
        register_plugin( $redis, $namespace, $plugin_path, $plugin_type );
    }

    # Clean up orphaned Redis keys (installed_path set, but no matching discovered plugin)
    my @all_plugin_keys = $redis->keys("LRR_PLUGIN_*");
    my %discovereduc    = map { uc($_) => 1 } keys %discovered_ns_map;
    $logger->debug("Orphan scan: " . scalar @all_plugin_keys . " Redis keys, " . scalar( keys %discovereduc ) . " discovered.");

    foreach my $plugin_key (@all_plugin_keys) {

        # extract the namespace from redis key
        my ($nspart) = $plugin_key =~ /^LRR_PLUGIN_(.+)$/;
        unless ($nspart) {
            $logger->warn("Unexpected Redis key format: '$plugin_key', skipping.");
            next;
        }

        # if plugin in redis is not discovered on disk, remove provenance from redis.
        my $discovered = $discovereduc{$nspart};
        unless ( $discovered ) {
            if ( $redis->hexists( $plugin_key, "installed_path" ) ) {
                my $installed_path = $redis->hget( $plugin_key, "installed_path" );
                if ( -e resolve_installed_path($installed_path) ) {
                    $logger->warn("Plugin key '$plugin_key' (installed_path: $installed_path) not discovered but file exists -- skipping removal.");
                    next;
                }
                $logger->warn("Orphaned plugin key '$plugin_key' (installed_path: $installed_path) -- plugin not discovered. Clearing provenance.");
            } else {
                $logger->warn("Orphaned plugin key '$plugin_key' -- plugin not discovered. Clearing provenance.");
            }
            unregister_plugin( $redis, $nspart );
            signal_uninstalled( $redis, $nspart );
        }
    }

    $logger->info("Plugin scan complete.");
}

# Infer plugin origin from the recorded install path.
# Returns one of "managed", "sideloaded", or "builtin".
sub infer_plugin_origin {
    my ( $namerds, $redis ) = @_;

    if ( $redis->hexists( $namerds, "installed_path" ) ) {
        my $path = $redis->hget( $namerds, "installed_path" );
        if ( $path ) {
            return "managed"    if $path =~ m{Plugin/Managed/};
            return "sideloaded" if $path =~ m{Plugin/Sideloaded/};
        }
    }

    return "builtin";
}

# Validate downloaded plugin content against registry metadata and filesystem state.
# Covers managed plugins only (installed via registry into Plugin/Managed/).
sub validate_managed_plugin {
    my ( $content, $namespace, $plugmeta, $plugin_type, $abs_installed_path ) = @_;

    my $plugname            = $plugmeta->{name};
    my $plugver             = $plugmeta->{version};
    my $artifact_path       = $plugmeta->{artifact};
    my $expected_checksum   = $plugmeta->{sha256};

    return ( undef, "Plugin '$namespace' is missing required field 'name'." )       unless $plugname;
    return ( undef, "Plugin '$namespace' is missing required field 'version'." )    unless $plugver;
    return ( undef, "Plugin '$namespace' is missing required field 'artifact'." )   unless $artifact_path;
    return ( undef, "Plugin '$namespace' is missing required field 'type'." )       unless $plugin_type;
    return ( undef, "Plugin '$namespace' is missing required field 'sha256'." )     unless defined $expected_checksum && $expected_checksum ne "";

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

    my $typedir = MANAGED_TYPE_DIRS->{$plugin_type};
    unless ($typedir) {
        return ( undef, "Unknown plugin type '$plugin_type'." );
    }

    # Extract filename (basename via regex; File::Basename not imported here).
    my ($filename) = $artifact_path =~ m{([^/]+)$};
    unless ($filename) {
        return ( undef, "Can't extract filename from path: $artifact_path" );
    }
    unless ( $filename =~ /^[A-Za-z0-9_-]+\.pm$/ ) {
        return ( undef, "Invalid plugin filename: $filename" );
    }

    my $install_dir     = getcwd() . "/lib/LANraragi/Plugin/Managed/$typedir";
    my $install_path    = "$install_dir/$filename";

    if ( defined $abs_installed_path && $abs_installed_path ne $install_path ) {
        return ( undef,
            "Plugin '$namespace' changed type between installed and registry versions; registry violates type invariance." );
    }

    my ($stem) = $filename =~ /^(.+)\.pm$/;
    my $expectedpkg = "LANraragi::Plugin::Managed::${typedir}::${stem}";
    if ( $pkg ne $expectedpkg ) {
        return ( undef, "Package mismatch -- declared '$pkg' but expected '$expectedpkg'." );
    }

    # Skip install_path itself so upgrades don't self-conflict.
    my $conflict = find_package_conflict( $pkg, $install_path );
    if ($conflict) {
        return ( undef, "Package '$pkg' already exists in $conflict." );
    }

    my $nsconflict = find_namespace_conflict( $namespace, $install_path );
    if ($nsconflict) {
        return ( undef, "Namespace '$namespace' already exists in $nsconflict." );
    }

    if ( -e $install_path && ( !defined $abs_installed_path || $abs_installed_path ne $install_path ) ) {
        return ( undef, "Install path is already occupied: $install_path" );
    }

    return ( { install_path => $install_path, install_dir => $install_dir, package => $pkg }, undef );
}

# Get absolute path from an installed_path
sub resolve_installed_path {
    my ($installed_path) = @_;
    return getcwd() . "/lib/" . $installed_path;
}

1;
