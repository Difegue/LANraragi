package LANraragi::Controller::Plugins;
use Mojo::Base 'Mojolicious::Controller';

use v5.36;
use experimental 'try';

use Redis;
use Encode;
use Mojo::JSON qw(encode_json);
use Cwd;

use File::Basename;
use LANraragi::Utils::Generic qw(generate_themes_header exec_with_lock);
use LANraragi::Utils::Plugins qw(get_plugins get_plugin_parameters is_plugin_enabled get_plugin_priority);
use LANraragi::Utils::Logging  qw(get_logger);
use LANraragi::Utils::Registry qw(find_package_conflict find_namespace_conflict);
use LANraragi::Model::Registry;

# This action will render a template
sub index {

    my $self = shift;

    # Build plugin lists, array of hashes
    my @metaplugins     = get_plugins("metadata");
    my @loginplugins    = get_plugins("login");
    my @scriptplugins   = get_plugins("script");
    my @downloadplugins = get_plugins("download");

    # Enrich all plugins with source and metadata plugins with priority
    my $redis = $self->LRR_CONF->get_redis_config;

    my $meta_all    = craft_plugin_array(@metaplugins);
    my $downloaders = craft_plugin_array(@downloadplugins);
    my $logins      = craft_plugin_array(@loginplugins);
    my $scripts     = craft_plugin_array(@scriptplugins);

    # Add source and priority to all plugins
    for my $list ( $meta_all, $downloaders, $logins, $scripts ) {
        for my $plugin (@$list) {
            $plugin->{source} = _infer_source( $plugin->{namespace}, $redis );
        }
    }

    # Split metadata into enabled (sorted by priority) and disabled
    my @meta_enabled;
    my @meta_disabled;
    for my $plugin (@$meta_all) {
        $plugin->{priority} = get_plugin_priority( $plugin->{namespace}, $redis );
        if ( $plugin->{enabled} ) {
            push @meta_enabled, $plugin;
        } else {
            push @meta_disabled, $plugin;
        }
    }
    @meta_enabled = sort { $a->{priority} <=> $b->{priority} } @meta_enabled;

    $redis->quit();

    $self->render(
        template        => "plugins",
        title           => $self->LRR_CONF->get_htmltitle,
        descstr         => $self->LRR_DESC,
        replacetitles   => $self->LRR_CONF->can_replacetitles,
        meta_enabled    => \@meta_enabled,
        meta_disabled   => \@meta_disabled,
        downloaders     => $downloaders,
        logins          => $logins,
        scripts         => $scripts,
        csshead         => generate_themes_header($self),
        version         => $self->LRR_VERSION
    );

}

sub craft_plugin_array {

    my @pluginarray = ();
    foreach my $pluginfo (@_) {
        my $namespace  = $pluginfo->{namespace};
        my %paramsconf = get_plugin_parameters($namespace);

        if ( $pluginfo->{type} ne "login" ) {

            # Add whether the plugin is enabled to the hash directly
            $pluginfo->{enabled} = is_plugin_enabled($namespace);
        }

        # Add redis values to the members of the parameters array
        my @paramhashes = ();

        # For backwards compatibility, we can return either an array or a hash for plugin parameters
        if ( ref( $pluginfo->{parameters} ) eq 'ARRAY' ) {
            my $counter     = 0;
            my @redisparams = @{ $paramsconf{'customargs'} };
            foreach my $param ( @{ $pluginfo->{parameters} } ) {
                $param->{value} = $redisparams[$counter];
                push @paramhashes, $param;
                $counter++;
            }
        } elsif ( ref( $pluginfo->{parameters} ) eq 'HASH' ) {
            foreach my $key ( sort keys %{ $pluginfo->{parameters} } ) {
                my $param = $pluginfo->{parameters}{$key};
                $param->{name}  = $key;
                $param->{value} = $paramsconf{$key};
                push @paramhashes, $param;
            }
        }

        #Add the parameter hashes to the plugin info for the template to parse
        $pluginfo->{parameters} = \@paramhashes;

        push @pluginarray, $pluginfo;
    }

    return \@pluginarray;
}

sub save_config {

    my $self     = shift;
    my $redis    = $self->LRR_CONF->get_redis_config;
    my %response = ( operation => 'plugins', success => 1, message => '' );

    # Update settings for every plugin.
    my @plugins = get_plugins("all");

    #Plugin list is an array of hashes
    my @pluginlist = ();

    no warnings 'experimental::try';
    try {

        # Save title preference first
        my $replacetitles = ( scalar $self->req->param('replacetitles') ? '1' : '0' );
        $redis->hset( "LRR_CONFIG", "replacetitles", $replacetitles );

        # Save each plugin's settings
        foreach my $pluginfo (@plugins) {
            my $namespace = $pluginfo->{namespace};
            my $namerds   = "LRR_PLUGIN_" . uc($namespace);

            # Get whether the plugin is enabled for auto-plugin or not
            my $enabled = ( scalar $self->req->param($namespace) ? '1' : '0' );

            if ( ref( $pluginfo->{parameters} ) eq 'ARRAY' ) {

                #Get expected number of custom arguments from the plugin itself
                my $argcount = scalar @{ $pluginfo->{parameters} };

                my @customargs = ();

                #Loop through the namespaced request parameters
                #Start at 1 because that's where TT2's loop.count starts
                for ( my $i = 1; $i <= $argcount; $i++ ) {
                    my $param = $namespace . "_CFG_" . $i;

                    my $value = $self->req->param($param);

                    # Check if the parameter exists in the request
                    if ($value) {
                        push( @customargs, $value );
                    } else {

                        # Checkboxes don't exist in the parameter list if they're not checked.
                        push( @customargs, "" );
                    }

                }

                my $encodedargs = encode_json( \@customargs );

                $redis->hset( $namerds, "enabled",    $enabled );
                $redis->hset( $namerds, "customargs", $encodedargs );

            } elsif ( ref( $pluginfo->{parameters} ) eq 'HASH' ) {

                # # TODO: remove this line (and the ARRAY check above)
                # # after plugins with array parameters are deprecated
                # $redis->del($namerds);

                #Loop through the namespaced request parameters
                foreach my $key ( keys %{ $pluginfo->{parameters} } ) {

                    my $value = $self->req->param("${namespace}_CFG_${key}");

                    # Checkboxes don't exist in the parameter list if they're not checked.
                    $redis->hset( $namerds, $key, ( ($value) ? $value : "" ) );
                }

                $redis->hset( $namerds, "enabled", $enabled );

            }

        }
    } catch ($e) {
        $response{success} = 0;
        $response{message} = $e;
    }

    $redis->quit();
    $self->render( json => \%response );
}

sub process_upload {
    my $self = shift;

    #Receive uploaded file.
    my $file     = $self->req->upload('file');
    my $filename = basename( $file->filename ); # TODO(REVIEW) why basename over filename?

    my $logger = get_logger( "Plugin Upload", "lanraragi" );

    #Check if this is a Perl package ("xx.pm")
    if ( $filename =~ /^.+\.(?:pm)$/ ) {

        #Check plugin type
        my $filetext   = $file->slurp;
        my $plugintype = "";

        if ( $filetext =~ /package LANraragi::Plugin::(Login|Metadata|Scripts|Download)::/ ) {
            $plugintype = $1;
        } else {
            my $errormess = "Could not find a valid plugin package type in the plugin \"$filename\"!";
            $logger->error($errormess);

            $self->render(
                json => {
                    operation => "upload_plugin",
                    name      => $file->filename,
                    success   => 0,
                    error     => $errormess
                }
            );

            return;
        }

        # Extract package name for conflict checks
        # TODO(REVIEW) why wrapped in ()
        # TODO(REVIEW) path compliance?
        my ($pkg) = $filetext =~ /^package\s+(LANraragi::Plugin::\S+)\s*;/m;
        my ($ns)  = $filetext =~ /namespace\s*=>\s*['"]([^'"]+)['"]/;

        # TODO(REVIEW) path compliance?
        my $dir = getcwd() . ("/lib/LANraragi/Plugin/Sideloaded/");
        unless ( -e $dir ) {
            mkdir $dir;
        }

        my $output_file = $dir . $filename;

        if ($pkg) {
            my $conflict = find_package_conflict($pkg, $output_file);
            if ($conflict) {
                $self->render(
                    json => {
                        operation => "upload_plugin",
                        name      => $file->filename,
                        success   => 0,
                        error     => "Package '$pkg' conflicts with existing plugin at $conflict."
                    }
                );
                return;
            }
        }

        if ($ns) {
            my $conflict = find_namespace_conflict($ns, $output_file);
            if ($conflict) {
                $self->render(
                    json => {
                        operation => "upload_plugin",
                        name      => $file->filename,
                        success   => 0,
                        error     => "Namespace '$ns' conflicts with existing plugin at $conflict."
                    }
                );
                return;
            }
        }

        $logger->info("Uploading new plugin $filename to $output_file ...");

        #Delete module if it already exists
        if ( -e $output_file ) {
            unlink($output_file);

            # Remove the existing file from @INC to avoid the require call below croaking
            delete( $INC{$output_file} );
        }

        $file->move_to($output_file);

        #Load the plugin dynamically.
        my $pluginclass = "LANraragi::Plugin::${plugintype}::" . substr( $filename, 0, -3 );

        #Per Module::Pluggable rules, the plugin class matches the filename
        eval {
            #@INC is not refreshed mid-execution, so we use the full filepath
            require $output_file;
            $pluginclass->plugin_info();
        };

        if ($@) {
            $logger->error("Could not instantiate plugin at namespace $pluginclass!");
            $logger->error($@);

            # Cleanup this shameful attempt
            unlink($output_file);
            delete( $INC{$output_file} );

            $self->render(
                json => {
                    operation => "upload_plugin",
                    name      => $file->filename,
                    success   => 0,
                    error     => "Could not load namespace $pluginclass! "
                      . "Your Plugin might not be compiling properly. <br/>"
                      . "Here's an error log: <pre>$@</pre>"
                }
            );

            return;
        }

        #We can now try to query it for metadata.
        my %pluginfo  = $pluginclass->plugin_info();
        my $namespace = $pluginfo{namespace};
        my $namerds   = "LRR_PLUGIN_" . uc($namespace);

        # Register installed_path so _infer_source works before next scan_plugins.
        # Serialize against managed install/uninstall on the same namespace.
        return unless exec_with_lock(
            $self,
            "plugin-write:$namespace",
            "upload_plugin",
            $namespace,
            sub {
                my $redis = $self->LRR_CONF->get_redis_config;
                $redis->hset( $namerds, "installed_path", $output_file );
                $redis->quit();

                $self->render(
                    json => {
                        operation => "upload_plugin",
                        name      => $pluginfo{name},
                        success   => 1
                    }
                );
            }
        );

    } else {

        $self->render(
            json => {
                operation => "upload_plugin",
                name      => $file->filename,
                success   => 0,
                error     => "This file isn't a plugin - " . "Please upload a Perl Module (.pm) file."
            }
        );
    }
}

# TODO(REVIEW) why at the controller level?
# Infer plugin source from Redis provenance or install path.
sub _infer_source {
    my ( $namespace, $redis ) = @_;
    my $namerds = "LRR_PLUGIN_" . uc($namespace);

    if ( $redis->hexists( $namerds, "registry" ) ) {
        my $reg = $redis->hget( $namerds, "registry" );
        return "managed" if $reg && $reg ne "";
    }

    if ( $redis->hexists( $namerds, "installed_path" ) ) {
        my $path = $redis->hget( $namerds, "installed_path" );
        return "sideloaded" if $path && $path =~ /Sideloaded/;
    }

    return "builtin";
}

1;
