package LANraragi::Controller::Api;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Encode;
use Mojo::JSON qw(decode_json encode_json from_json);
use File::Path qw(remove_tree);

use LANraragi::Utils::Generic;
use LANraragi::Utils::Archive;
use LANraragi::Utils::Database;
use LANraragi::Utils::TempFolder;

use LANraragi::Model::Backup;
use LANraragi::Model::Config;
use LANraragi::Model::Plugins;
use LANraragi::Model::Reader;
use LANraragi::Model::Stats;

sub serve_archivelist {

    my $self  = shift;
    my $redis = $self->LRR_CONF->get_redis();

    if ( $redis->hexists( "LRR_JSONCACHE", "archive_list" ) ) {

        #Get cached JSON from Redis
        my $archivejson =
          decode_utf8( $redis->hget( "LRR_JSONCACHE", "archive_list" ) );

   #Decode the json back to an array so we can use the built-in mojo json render
        $self->render( json => from_json($archivejson) );
    }
    else {
        $self->render( json => () );
    }
}

sub serve_untagged_archivelist {
    my $self = shift;
    my @idlist = LANraragi::Utils::Database::find_untagged_archives;
    $self->render( json => \@idlist );
}

sub serve_tag_stats {
    my $self = shift;
    $self->render( json => from_json(LANraragi::Model::Stats::build_tag_json));
}

sub serve_backup {
    my $self = shift;
    $self->render( json => from_json(LANraragi::Model::Backup::build_backup_JSON));
}

# Handle missing ID parameter for a whole lot of api methods down below.
sub check_id_parameter {
    my ( $mojo, $endpoint ) = @_;

    my $id = $mojo->req->param('id') || 0;
    unless ( $id ) {

        #High-level API documentation!
        $mojo->render(
            json => {
                error => "API usage: $endpoint?id=YOUR_ID"
            },
			status => 400
        );
    }
    return $id;
}

sub extract_archive {
    my $self = shift;
    my $id = check_id_parameter($self, "extract") || return;

    #Basically just API glue to the existing reader method.
    my $readerjson;

    eval {
        $readerjson =
          LANraragi::Model::Reader::build_reader_JSON( $self, $id, "0", "0" );
    };
    my $err = $@;

    if ($err) {
        $self->render(
            json => {
                pages => (),
                error => $err
            }
        );
    }
    else {
        $self->render( json => decode_json($readerjson) );
    }
}

#use RenderFile to get the file of the provided id to the client.
sub serve_file {

    my $self  = shift;
    my $id    = check_id_parameter($self, "servefile") || return;
    my $redis = $self->LRR_CONF->get_redis();

    my $file = $redis->hget( $id, "file" );
    $self->render_file( filepath => $file );
}

#Remove temp dir.
sub clean_tempfolder {

    my $self = shift;

    #Run a full clean, errors are dumped into $@ if they occur
    eval { LANraragi::Utils::TempFolder::clean_temp_full };

    $self->render(
        json => {
            operation => "cleantemp",
            success   => $@ eq "",
            error     => $@,
            newsize   => LANraragi::Utils::TempFolder::get_tempsize
        }
    );
}

sub serve_thumbnail {
    my $self = shift;

    my $id = check_id_parameter($self, "thumbnail") || return;
    my $dirname = $self->LRR_CONF->get_userdir;

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
            success   => 1
        }
    );
}

sub clear_new {
    my $self = shift;
    my $id = check_id_parameter($self, "clear_new") || return;

    my $redis = $self->LRR_CONF->get_redis();

    # Just set isnew to false for the provided ID.
    if ($redis->hget( $id, "isnew") ne "false") {
        $redis->hset( $id, "isnew", "false" );

        #Trigger a JSON cache refresh
        LANraragi::Utils::Database::invalidate_cache();
    }

    $self->render(
        json => {
            operation => "clear_new",
            id        => $id,
            success   => 1
        }
    );
}

#Clear new flag in all archives.
sub clear_new_all {

    my $self = shift;
    my $redis = $self->LRR_CONF->get_redis();

    # Get all archives thru redis
    # 40-character long keys only => Archive IDs
    my @keys  = $redis->keys('????????????????????????????????????????');

    foreach my $idall (@keys) {
        $redis->hset( $idall, "isnew", "false" );
    }
    
    $self->render(
        json => {
            operation => "clear_new_all",
            success   => 1
        }
    );
}

#Use all enabled plugins on an archive ID. Tags are automatically saved in the background.
#Returns number of successes and failures.
sub use_enabled_plugins {

    my $self = shift;

    my $id    = $self->req->param('id');
    my $redis = $self->LRR_CONF->get_redis();

    if ( $redis->exists($id)
        && LANraragi::Model::Config::enable_autotag )
    {

        my ( $succ, $fail, $addedtags ) =
          LANraragi::Model::Plugins::exec_enabled_plugins_on_file($id);

        $self->render(
            json => {
                operation => "autoplugin",
                id        => $id,
                success   => 1,
                message =>
                  "$succ Plugins used successfully, $fail Plugins failed, $addedtags tags added."
            }
        );
    }
    else {

        $self->render(
            json => {
                operation => "autoplugin",
                id        => $id,
                success   => 0,
                message =>
                  "ID not found in database or AutoPlugin disabled by admin."
            }
        );
    }
}

#Uses a plugin with the standard global argument.
sub use_plugin {

    my $self = shift;
    my ( $id, $plugname, $oneshotarg, $redis ) = &get_plugin_params($self);

    my $plugin = LANraragi::Utils::Plugins::get_plugin($plugname);
    my @args   = ();

    if ($plugin) {

        #Get the matching globalargs in Redis
        @args = LANraragi::Utils::Plugins::get_plugin_parameters($plugname);

        #Execute the plugin, appending the custom args at the end
        my %plugin_result;
        eval {
            %plugin_result = LANraragi::Model::Plugins::exec_plugin_on_file( $plugin, $id,
            $oneshotarg, @args );
        };

        if ($@) {
            $plugin_result{error} = $@;
        }

        #Returns the fetched tags in a JSON response.
        $self->render(
            json => {
                operation => "fetch_tags",
                success   => ( exists $plugin_result{error} ? 0 : 1 ),
                message   => $plugin_result{error},
                tags      => $plugin_result{new_tags},
                title =>
                  ( exists $plugin_result{title} ? $plugin_result{title} : "" )
            }
        );
        return;
    }

    &print_plugin_not_found($self);

}

sub get_plugin_params {
    my $self = shift;

    return (
        $self->req->param('id'),  $self->req->param('plugin'),
        $self->req->param('arg'), $self->LRR_CONF->get_redis()
    );
}

sub print_plugin_not_found {
    shift->render(
        json => {
            operation => "fetch_tags",
            success   => 0,
            message   => "Plugin not found on system."
        }
    );
}

sub shinobu_status {

    my $self = shift;
    my $shinobu = $self->SHINOBU;

    $self->render(
        json => {
            operation => "shinobu_status",
            is_alive  => $self->SHINOBU->alive,
            pid       => $self->SHINOBU->pid
        }
    );
}

sub stop_shinobu {
    my $self = shift;

    #commit sudoku
    $self->SHINOBU->die;

    $self->render(
        json => {
            operation => "shinobu_stop",
            success   => 1
        }
    );
}

sub restart_shinobu {
    my $self = shift;

    #commit sudoku
    $self->SHINOBU->die;

    #Create a new ProcBackground object and stuff it in the helper
    my $proc = LANraragi::Utils::Generic::start_shinobu();
    $self->app->helper( SHINOBU => sub { return $proc; } );

    $self->render(
        json => {
            operation => "shinobu_restart",
            success   => $self->SHINOBU->alive,
            new_pid   => $self->SHINOBU->pid
        }
    );
}

sub drop_database {

    my $self = shift;
    LANraragi::Utils::Database::drop_database();

    $self->render(
        json => {
            operation => "drop_database",
            success   => 1
        }
    );
}

1;
