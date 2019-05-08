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

        my $checked        = 0;
        my @globalargnames = ();

        #Check if the plugin does have global args before trying to get them
        if ( length $pluginfo{global_args} ) {

            #The global_args array is inside the pluginfo hash, dereference it
            @globalargnames = @{ $pluginfo{global_args} };
        }

        my @globalargvalues = ();
        my @globalargs      = ();

        if ( $redis->hexists( $namerds, "enabled" ) ) {
            $checked = $redis->hget( $namerds, "enabled" );
            my $argsjson = $redis->hget( $namerds, "customargs" );

            ( $_ = LANraragi::Utils::Database::redis_decode($_) )
              for ( $checked, $argsjson );

            #Mojo::JSON works with array references by default,
            #so we need to dereference here as well
            if ($argsjson) {
                @globalargvalues = @{ decode_json($argsjson) };
            }
        }

        #Build array of pairs with the global arg names and values
        for ( my $i = 0 ; $i < scalar @globalargnames ; $i++ ) {
            my %arghash = (
                name  => $globalargnames[$i],
                value => $globalargvalues[$i] || ""
            );
            push @globalargs, \%arghash;
        }

        $pluginfo{enabled} = $checked;

        #We add our array of pairs to the plugin info for the template to parse
        #global_args containing the arg names is still there as a reference.
        $pluginfo{custom_args} = \@globalargs;

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

            #Get expected number of custom arguments from the plugin itself
            my $argcount = 0;
            if ( length $pluginfo{global_args} ) {
                $argcount = scalar @{ $pluginfo{global_args} };
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
