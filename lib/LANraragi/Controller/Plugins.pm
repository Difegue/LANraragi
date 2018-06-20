package LANraragi::Controller::Plugins;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Encode;
use Module::Load;
no warnings 'experimental';
use Cwd;

use LANraragi::Utils::Generic;
use LANraragi::Utils::Archive;
use LANraragi::Utils::Database;

use LANraragi::Model::Config;
use LANraragi::Model::Plugins;

# This action will render a template
sub index {

    my $self  = shift;
    my $redis = $self->LRR_CONF->get_redis;

    #Build plugin listing
    my @plugins = LANraragi::Model::Plugins::plugins;

    #Plugin list is an array of hashes
    my @pluginlist = ();

    foreach my $plugin (@plugins) {

        my %pluginfo = $plugin->plugin_info();

        my $namespace = $pluginfo{namespace};
        my $namerds   = "LRR_PLUGIN_" . uc($namespace);

        my $checked = $redis->hget( $namerds, "enabled" );
        my $arg     = $redis->hget( $namerds, "customarg" );

        $pluginfo{enabled}   = $checked;
        $pluginfo{customarg} = $arg;

        push @pluginlist, \%pluginfo;

    }

    $redis->quit();

    $self->render(
        template => "plugins",
        title    => $self->LRR_CONF->get_htmltitle,
        plugins  => \@pluginlist,
        cssdrop  => LANraragi::Utils::Generic::generate_themes
    );

}

sub save_config {

    my $self  = shift;
    my $redis = $self->LRR_CONF->get_redis;

#For every existing plugin, check if we received a matching parameter, and update its settings.
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
            my $arg = $self->req->param( $namespace . "_CFG" ) || "";

            $redis->hset( $namerds, "enabled", $enabled );

            $redis->hset( $namerds, "customarg", $arg );

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

     #TODO - refresh @INC so it takes into account the new version of the plugin

        #Load the plugin dynamically.
        my $pluginclass = "LANraragi::Plugin::" . substr( $filename, 0, -3 );

        #Per Module::Pluggable rules, the plugin class matches the filename
        #Module::Load's autoload method is used here.
        eval {
            autoload $pluginclass;
            $pluginclass->plugin_info();
        };

        if ($@) {
            $logger->error(
                "Could not instantiate plugin at namespace $pluginclass!");
            $logger->error($@);

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

        my $redis = $self->LRR_CONF->get_redis();

        my $namespace = $pluginfo{namespace};
        my $namerds   = "LRR_PLUGIN_" . uc($namespace);

        #Set the UGC flag to indicate this plugin is not core and can be deleted
        $redis->hset( $namerds, "ugc", "1" );

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
