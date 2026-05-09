package LANraragi::Model::Plugins;

use v5.36;
use experimental 'try';

use strict;
use warnings;
use utf8;
use feature 'fc';

use Cwd qw(abs_path getcwd);
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
use LANraragi::Utils::Path     qw(create_path unlink_path rename_path package_to_path);
use LANraragi::Utils::Registry qw(
    resolve_git_raw_url
    find_package_conflict
    find_namespace_conflict
    validate_registry_artifact_path
    resolve_local_registry_artifact_path
    resolve_max_version
    is_valid_registry
    MANAGED_TYPE_DIRS
);

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

    # Plugins are returned sorted by priority (lower = runs first)
    my @plugins = LANraragi::Utils::Plugins::get_enabled_plugins("metadata");

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
# TODO(REVIEW) what if the signature of the plugin changes from one version to the next, or across provenance, in a way which is incompatible?
# because uninstall plugin keeps configuration, this will require thought...
sub install_plugin {
    my ( $namespace, $redis, $registry_id, $version ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );

    # registry must exist
    unless ( is_valid_registry( $registry_id, $redis ) ) {
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

    unless ( ref $plugin_root->{versions} eq "HASH" && keys %{ $plugin_root->{versions} } ) {
        return ( 404, undef, "No versions found for plugin '$namespace'." );
    }

    unless ( defined $version ) {
        $version = resolve_max_version($plugin_root);
    }

    unless ( $plugin_root->{versions}{$version} ) {
        return ( 404, undef, "Version '$version' not found for plugin '$namespace'." );
    }

    $logger->info("Installing plugin '$namespace' v$version from registry '$registry_id'");

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
        $currentpath = resolve_installed_path( $redis->hget( $namerds, "installed_path" ) );
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
    my $install_relpath = package_to_path( $validated->{package} );

    make_path($installdir) unless -d $installdir;

    my $op_desc = "install of plugin '$namespace' (version=$version, registry=$registry_id)";
    my @undo;   # all operations to undo in event of failure.
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

    # Backup existing artifact so a same-path upgrade has bytes to restore on rollback.
    my $backup_path;
    if ( -e $installpath ) {
        $backup_path = "$installpath.lrr-rollback";
        unlink_path($backup_path) if -e $backup_path;
        unless ( rename_path( $installpath, $backup_path ) ) {
            my $err = "$!";
            $logger->error("Cannot back up existing artifact at $installpath: $err");
            return ( 500, undef, "Cannot back up existing artifact for transactional install: $err" );
        }
        push @undo, [
            "restore prior artifact from $backup_path",
            sub { rename_path( $backup_path, $installpath ) ? undef : "$!" },
        ];
    }

    eval { Mojo::File->new($installpath)->spew($plugin_content) };
    if ($@) {
        my $err = $@;
        if ( my @resp = $do_rollback->("Cannot write plugin file: $err") ) {
            return @resp;
        }
        return ( 500, undef, "Cannot write plugin file during installation: $err" );
    }
    push @undo, [
        "unlink artifact at $installpath",
        sub {
            return unless -e $installpath;
            unlink_path($installpath) ? undef : "$!";
        },
    ];

    $logger->info("Installed plugin '$namespace' to $installpath");

    my %prior;
    for my $field (qw(installed_path installed_version installed_registry installed_sha256 type)) {
        my $val = $redis->hget( $namerds, $field );
        $prior{$field} = $val if defined $val;
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
            $install_relpath, $plugin_metadata->{version}, $registry_id, $plugin_metadata->{sha256},
            $plugin_metadata->{type}
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
        ( exists $prior{installed_path}
            ? "restore prior provenance for $namerds"
            : "clear provenance for $namerds" ),
        sub {
            my @argv;
            for my $field (qw(installed_path installed_version installed_registry installed_sha256 type)) {
                push @argv, $field, $prior{$field} if exists $prior{$field};
            }
            eval { $redis->eval( $restore_script, 1, $namerds, @argv ) };
            $@ ? "$@" : undef;
        },
    ];

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

    @undo = ();
    if ( $backup_path && -e $backup_path ) {
        unlink_path($backup_path) or $logger->warn("Could not remove rollback backup at $backup_path: $!");
    }

    # If the upgrade landed at a new path (type-change between published versions, in violation
    # of spec invariance), remove the old artifact so scan_plugins doesn't rediscover it.
    if ( defined $currentpath && $currentpath ne $installpath && -e $currentpath ) {
        unlink_path($currentpath) or $logger->warn("Could not remove stale plugin file at $currentpath: $!");
    }

    signal_updated( $namespace, $redis );
    record_load_success($namespace);

    my %installed_meta = (
        name               => $plugin_metadata->{name},
        version            => $plugin_metadata->{version},
        installed_registry => $registry_id,
        installed_sha256   => $plugin_metadata->{sha256},
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

    my $installpath;
    if ( $redis->hexists( $namerds, "installed_path" ) ) {
        $installpath = resolve_installed_path( $redis->hget( $namerds, "installed_path" ) );
    }

    unless ($installpath) {
        return ( 404, undef, "Plugin '$namespace' has no install path recorded." );
    }

    my $source = infer_plugin_source( $namerds, $redis );

    # We don't touch builtin plugins!
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

    unregister_plugin( $redis, $namespace );
    signal_uninstalled( $namespace, $redis );

    return ( 200, 1, undef );
}

# Reconcile discovered plugins with Redis state at startup.
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

        my $type = $info{type};
        unless ($type) {
            $logger->warn("Plugin $class (namespace '$ns') has no type, skipping.");
            next;
        }

        my $filepath = package_to_path($class);

        push @{ $ns_map{$ns} }, { class => $class, file_path => $filepath, type => $type };
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
        my $type     = $entry->{type};
        my $namerds  = "LRR_PLUGIN_" . uc($ns);

        my $current_path = $redis->hget( $namerds, "installed_path" );
        my $current_type = $redis->hget( $namerds, "type" );
        if (   defined $current_path
            && $current_path eq $filepath
            && defined $current_type
            && $current_type eq $type ) {
            next; # skip if database already tracks said path and type
        }

        $logger->debug("Plugin '$ns': setting installed_path to '$filepath' (type=$type).");
        register_plugin( $redis, $ns, $filepath, $type );
    }

    # Clean up orphaned Redis keys (installed_path set, but no matching discovered plugin)
    my @all_keys     = $redis->keys("LRR_PLUGIN_*");
    my %discovereduc = map { uc($_) => 1 } keys %ns_map;
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
                if ( -e resolve_installed_path($path) ) {
                    $logger->warn("Plugin key '$key' (installed_path: $path) not discovered but file exists -- skipping removal.");
                    next;
                }
                $logger->warn("Orphaned plugin key '$key' (installed_path: $path) -- plugin not discovered. Clearing provenance.");
            } else {
                $logger->warn("Orphaned plugin key '$key' -- plugin not discovered. Clearing provenance.");
            }
            unregister_plugin( $redis, $nspart );
            if ( $key =~ /^LRR_PLUGIN_(.+)$/ ) {
                signal_uninstalled( $1, $redis );
            }
        }
    }

    $logger->info("Plugin scan complete.");
}

# Infer plugin source from the recorded install path.
# Returns one of "managed", "sideloaded", or "builtin".
sub infer_plugin_source {
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
# Read-only
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

sub resolve_installed_path {
    my ($installed_path) = @_;
    return getcwd() . "/lib/" . $installed_path;
}

1;
