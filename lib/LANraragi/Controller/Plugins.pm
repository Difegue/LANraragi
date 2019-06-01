package LANraragi::Controller::Plugins;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Encode;
use Mojo::JSON qw(decode_json encode_json);
no warnings 'experimental';
use Cwd;

use LANraragi::Utils::Generic;
use LANraragi::Utils::Archive;
use LANraragi::Utils::Database;
use LANraragi::Utils::Plugins;

use LANraragi::Model::Config;

# This action will render a template
sub index {

    my $self  = shift;
    my $redis = $self->LRR_CONF->get_redis;

    #Plugin list is an array of hashes
    my @pluginlist = ();

    #Build plugin listing
    my @plugins = LANraragi::Utils::Plugins::get_plugins("metadata");
    foreach my $pluginfo (@plugins) {
        my $namespace = $pluginfo->{namespace};
        my @params    = LANraragi::Utils::Plugins::get_plugin_parameters($namespace);

        # Add whether the plugin is enabled to the hash directly
        $pluginfo{enabled} = LANraragi::Utils::Plugins::is_plugin_enabled($namespace);

        #Add the parameter values to the plugin info for the template to parse
        #The "parameters" key containing the arg names and types is still there as a reference.
        $pluginfo{param_values} = \@params;

        push @pluginlist, \%pluginfo;
    }

    $redis->quit();

    $self->render(
        template => "plugins",
        title    => $self->LRR_CONF->get_htmltitle,
        plugins  => \@pluginlist,
        cssdrop   => LANraragi::Utils::Generic::generate_themes_selector,
        csshead   => LANraragi::Utils::Generic::generate_themes_header
    );

}

sub save_config {

    my $self  = shift;
    my $redis = $self->LRR_CONF->get_redis;

    # Update settings for every plugin.
    my @plugins = LANraragi::Model::Plugins::plugins;

    #Plugin list is an array of hashes
    my @pluginlist = ();
    my $success    = 1;
    my $errormess  = "";

    eval {
        foreach my $plugin (@plugins) {

            my %pluginfo  = $plugin->plugin_info();
            my $namespace = $pluginfo{namespace};
            my $namerds   = "LRR_PLUGIN_" . uc($namespace);

            my $enabled = ( scalar $self->req->param($namespace) ? '1' : '0' );

            #Get expected number of custom arguments from the plugin itself
            my $argcount = 0;
            if ( length $pluginfo{parameters} ) {
                $argcount = scalar @{ $pluginfo{parameters} };
            }

            my @customargs = ();

            #Loop through the namespaced request parameters
            #Start at 1 because that's where TT2's loop.count starts
            for ( my $i = 1 ; $i <= $argcount ; $i++ ) {
                push @customargs,
                  ( $self->req->param( $namespace . "_CFG_" . $i ) );
            }

            my $encodedargs = encode_json( \@customargs );

            $redis->hset( $namerds, "enabled",    $enabled );
            $redis->hset( $namerds, "customargs", $encodedargs );

        }
    };

    if ($@) {
        $success   = 0;
        $errormess = $@;
    }

    $self->render(
        json => {
            operation => "plugins",
            success   => $success,
            message   => $errormess
        }
    );
}

sub process_upload {
    my $self = shift;

    #Receive uploaded file.
    my $file     = $self->req->upload('file');
    my $filename = $file->filename;

    my $logger =
      LANraragi::Utils::Generic::get_logger( "Plugin Upload", "lanraragi" );

    #Check if this is a Perl package ("xx.pm")
    if ( $filename =~ /^.+\.(?:pm)$/ ) {

        my $dir = getcwd() . ("/lib/LANraragi/Plugin/");
        my $output_file = $dir . $filename;

        $logger->info("Uploading new plugin $filename to $output_file ...");

        #Delete module if it already exists
        unlink($output_file);

        $file->move_to($output_file);

        #Load the plugin dynamically.
        my $pluginclass = "LANraragi::Plugin::" . substr( $filename, 0, -3 );

        #Per Module::Pluggable rules, the plugin class matches the filename
        eval {
            #@INC is not refreshed mid-execution, so we use the full filepath
            require $output_file;
            $pluginclass->plugin_info();
        };

        if ($@) {
            $logger->error(
                "Could not instantiate plugin at namespace $pluginclass!");
            $logger->error($@);

            unlink($output_file);

            $self->render(
                json => {
                    operation => "upload_plugin",
                    name      => $file->filename,
                    success   => 0,
                    error     => "Could not load namespace $pluginclass! "
                      . "Your Plugin might not be compiling properly. <br/>"
                      . "Here's an error log: $@"
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

    }
    else {

        $self->render(
            json => {
                operation => "upload_plugin",
                name      => $file->filename,
                success   => 0,
                error     => "This file isn't a plugin - "
                  . "Please upload a Perl Module (.pm) file."
            }
        );
    }
}

1;
