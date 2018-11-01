package LANraragi::Controller::Api;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Encode;
use Mojo::JSON qw(decode_json encode_json from_json);
use File::Find::utf8;
use File::Path qw(remove_tree);

use LANraragi::Utils::Generic;
use LANraragi::Utils::Archive;
use LANraragi::Utils::Database;

use LANraragi::Model::Config;
use LANraragi::Model::Plugins;
use LANraragi::Model::Reader;

sub serve_archivelist {

    my $self  = shift;
    my $redis = $self->LRR_CONF->get_redis();

    if ( $redis->hexists( "LRR_JSONCACHE", "archive_list" ) ) {

        #Get cached JSON from Redis
        my $archivejson =
          decode_utf8( $redis->hget( "LRR_JSONCACHE", "archive_list" ) );

        #Decode the json back to an array so we can use the built-in mojo json render
        $self->render( json => from_json ($archivejson) );
    } else {
        $self->render( json => () );
    }
}

sub extract_archive {

    my $self  = shift;
    my $id    = $self->req->param('id') || "0";

    if ($id eq "0") {
        #High-level API documentation!
        $self->render(json => {
            error => "API usage: extract?id=YOUR_ID"
            });
        return;
    }

    #Basically just API glue to the existing reader method.
    my $readerjson;
    
    eval { 
        $readerjson = LANraragi::Model::Reader::build_reader_JSON($self,$id,"0","0");
    };
    my $err = $@;

    if ($err) {
        $self->render(json => {
            pages => (),
            error => $err
            }
        );
    } else {
        $self->render( json => decode_json ($readerjson) );
    }
}

#use RenderFile to get the file of the provided id to the client.
sub serve_file {

    my $self  = shift;
    my $id    = $self->req->param('id');
    my $redis = $self->LRR_CONF->get_redis();

    if ($id eq "0") {
        #High-level API documentation!
        $self->render(json => {
            error => "API usage: servefile?id=YOUR_ID"
            });
        return;
    }

    my $file = $redis->hget( $id, "file" );
    $self->render_file( filepath => $file );
}

#Remove temp dir.
sub clean_tempfolder {

    my $self = shift;
    remove_tree( './public/temp', { error => \my $err } );

    my $cleanmsg = "";
    if (@$err) {
        for my $diag (@$err) {
            my ( $file, $message ) = %$diag;
            if ( $file eq '' ) {
                $self->LRR_LOGGER->error( "General error: " . $message );
                $cleanmsg = "General error: $message\n";
            }
            else {
                $self->LRR_LOGGER->error("Problem unlinking $file: $message");
                $cleanmsg = "Problem unlinking $file: $message\n";
            }
        }
    }

    my $size = 0;
    find( sub { $size += -s if -f }, "./public/temp" );

    $self->render(
        json => {
            operation => "cleantemp",
            success   => $cleanmsg eq "",
            error     => $cleanmsg,
            newsize   => int( $size / 1048576 * 100 ) / 100
        }
    );
}

sub serve_thumbnail {
    my $self = shift;

    my $id      = $self->req->param('id');
    my $dirname = $self->LRR_CONF->get_userdir;

    if ($id eq "0") {
        #High-level API documentation!
        $self->render(json => {
            error => "API usage: thumbnail?id=YOUR_ID"
            });
        return;
    }

    #Thumbnails are stored in the content directory, thumb subfolder.
    my $thumbname = $dirname . "/thumb/" . $id . ".jpg";

    unless ( -e $thumbname ) {

        $thumbname =
          LANraragi::Utils::Archive::extract_thumbnail( $dirname, $id );

    }

    #Simply serve the thumbnail. 
    #If it doesn't exist, serve an error placeholder instead.
    if ( -e $thumbname ) {
        $self->render_file( filepath => $thumbname );
    }
    else {
        $self->render_file( filepath => "./public/img/noThumb.png" );
    }

}

sub force_refresh {

    my $self = shift;
    LANraragi::Utils::Database::invalidate_cache();

    $self->render(
        json => {
            operation => "refresh_cache",
            status    => 1,
            message   => "JSON cache invalidated."
        }
    );
}

#Use all enabled plugins on an archive ID. Tags are automatically saved in the background.
#Returns number of successes and failures.
sub use_enabled_plugins {

    my $self = shift;

    my $id    = $self->req->param('id');
    my $redis = $self->LRR_CONF->get_redis();

    if ( $redis->hexists( $id, "title" )
        && LANraragi::Model::Config::enable_autotag )
    {

        my ( $succ, $fail ) =
          LANraragi::Model::Plugins::exec_enabled_plugins_on_file($id);

        $self->render(
            json => {
                operation => "autotag",
                id        => $id,
                success   => 1,
                message =>
                  "$succ Plugins used successfully, $fail Plugins failed."
            }
        );
    }
    else {

        $self->render(
            json => {
                operation => "autotag",
                id        => $id,
                success   => 0,
                message =>
                  "ID not found in database or AutoTagging disabled by admin."
            }
        );
    }
}

#Uses a plugin on the given archive with the given argument.
#Returns the fetched tags in a JSON response.
sub use_plugin {
    my $self = shift;

    my $id         = $self->req->param('id');
    my $plugname   = $self->req->param('plugin');
    my $oneshotarg = $self->req->param('arg');
    my $redis      = $self->LRR_CONF->get_redis();

    #Go through plugins to find one with a matching namespace
    my @plugins = LANraragi::Model::Plugins::plugins;

    foreach my $plugin (@plugins) {

        my %pluginfo  = $plugin->plugin_info();
        my $namespace = $pluginfo{namespace};

        if ( $plugname eq $namespace ) {

            #Get the matching argument JSON in Redis
            my $namerds = "LRR_PLUGIN_" . uc($namespace);
            my @args    = ();

            if ( $redis->hexists( $namerds, "enabled" ) ) {
                my $argsjson = $redis->hget( $namerds, "customargs" );
                $argsjson = LANraragi::Utils::Database::redis_decode($argsjson);

                #Decode it to an array for proper use
                if ($argsjson) {
                    @args = @{ decode_json($argsjson) };
                }
            }

            #Finally, execute the plugin, appending the custom args at the end
            my %plugin_result =
              LANraragi::Model::Plugins::exec_plugin_on_file( $plugin, $id,
                $oneshotarg, @args );

            if ( exists $plugin_result{error} ) {

                $self->render(
                    json => {
                        operation => "fetch_tags",
                        success   => 0,
                        message   => $plugin_result{error}
                    }
                );
            }
            else {

                $self->render(
                    json => {
                        operation => "fetch_tags",
                        success   => 1,
                        tags      => $plugin_result{new_tags}
                    }
                );
            }

            return;
        }
    }

    $self->render(
        json => {
            operation => "fetch_tags",
            success   => 0,
            message   => "Plugin not found on system."
        }
    );

}

1;
