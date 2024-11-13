package LANraragi::Controller::Plugins;
use Mojo::Base 'Mojolicious::Controller';

use v5.36;
use experimental 'try';

use Redis;
use Encode;
use Mojo::JSON qw(encode_json);
use Cwd;

use LANraragi::Utils::Generic qw(generate_themes_header);
use LANraragi::Utils::Plugins qw(get_plugins get_plugin_parameters is_plugin_enabled);
use LANraragi::Utils::Logging qw(get_logger);

# This action will render a template
sub index {

    my $self = shift;

    # Build plugin lists, array of hashes
    my @metaplugins     = get_plugins("metadata");
    my @loginplugins    = get_plugins("login");
    my @scriptplugins   = get_plugins("script");
    my @downloadplugins = get_plugins("download");

    $self->render(
        template      => "plugins",
        title         => $self->LRR_CONF->get_htmltitle,
        descstr       => $self->LRR_DESC,
        replacetitles => $self->LRR_CONF->can_replacetitles,
        metadata      => craft_plugin_array(@metaplugins),
        downloaders   => craft_plugin_array(@downloadplugins),
        logins        => craft_plugin_array(@loginplugins),
        scripts       => craft_plugin_array(@scriptplugins),
        csshead       => generate_themes_header($self),
        version       => $self->LRR_VERSION
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
        my $counter     = 0;

        # For backwards compatibility, we can return either an array or a hash for plugin parameters
        if ( ref( $pluginfo->{parameters} ) eq 'ARRAY' ) {
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

                # TODO: remove this line (and the ARRAY check above) 
                # after plugins with array parameters are deprecated
                $redis->del($namerds);

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
    my $filename = $file->filename;

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

        my $dir = getcwd() . ("/lib/LANraragi/Plugin/Sideloaded/");
        unless ( -e $dir ) {
            mkdir $dir;
        }

        my $output_file = $dir . $filename;

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
        my %pluginfo = $pluginclass->plugin_info();

        $self->render(
            json => {
                operation => "upload_plugin",
                name      => $pluginfo{name},
                success   => 1
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

1;
