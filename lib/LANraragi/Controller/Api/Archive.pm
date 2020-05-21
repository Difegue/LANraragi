package LANraragi::Controller::Api::Archive;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Encode;
use Storable;
use Mojo::JSON qw(decode_json encode_json from_json);

use LANraragi::Model::Archive;
use LANraragi::Model::Backup;
use LANraragi::Model::Config;
use LANraragi::Model::Plugins;
use LANraragi::Model::Reader;
use LANraragi::Model::Stats;

# Archive API. To be refactored soon!

# Handle missing ID parameter for a whole lot of api methods down below.
sub check_id_parameter {
    my ( $mojo, $endpoint ) = @_;

    my $id = $mojo->req->param('id') || 0;
    unless ($id) {

        #High-level API documentation!
        $mojo->render(
            json   => { error => "API usage: $endpoint?id=YOUR_ID" },
            status => 400
        );
    }
    return $id;
}

sub serve_archivelist {
    my $self   = shift;
    my @idlist = LANraragi::Model::Archive::generate_archive_list;
    $self->render( json => \@idlist );
}

sub serve_untagged_archivelist {
    my $self   = shift;
    my @idlist = LANraragi::Model::Archive::find_untagged_archives;
    $self->render( json => \@idlist );
}

sub serve_thumbnail {
    my $self = shift;
    my $id   = check_id_parameter( $self, "thumbnail" ) || return;
    LANraragi::Model::Archive::serve_thumbnail( $self, $id );
}

# Use RenderFile to get the file of the provided id to the client.
sub serve_file {

    my $self  = shift;
    my $id    = check_id_parameter( $self, "servefile" ) || return;
    my $redis = $self->LRR_CONF->get_redis();

    my $file = $redis->hget( $id, "file" );
    $redis->quit();
    $self->render_file( filepath => $file );
}

# Serve an archive page from the temporary folder, using RenderFile.
sub serve_page {
    my $self = shift;
    my $id   = check_id_parameter( $self, "servefile" ) || return;
    LANraragi::Model::Archive::serve_page( $self, $id );
}

sub extract_archive {
    my $self = shift;
    my $id   = check_id_parameter( $self, "extract" ) || return;
    my $readerjson;

    eval { $readerjson = LANraragi::Model::Reader::build_reader_JSON( $self, $id, "0", "0" ); };
    my $err = $@;

    if ($err) {
        $self->render(
            json   => { error => $err },
            status => 500
        );
    } else {
        $self->render( json => decode_json($readerjson) );
    }
}

sub clear_new {
    my $self = shift;
    my $id   = check_id_parameter( $self, "clear_new" ) || return;

    my $redis = $self->LRR_CONF->get_redis();

    # Just set isnew to false for the provided ID.
    if ( $redis->hget( $id, "isnew" ) ne "false" ) {

        # Bust search cache...partially!
        LANraragi::Utils::Database::invalidate_isnew_cache();

        $redis->hset( $id, "isnew", "false" );
    }
    $redis->quit();

    $self->render(
        json => {
            operation => "clear_new",
            id        => $id,
            success   => 1
        }
    );
}

#Use all enabled plugins on an archive ID. Tags are automatically saved in the background.
#Returns number of successes and failures.
sub use_enabled_plugins {

    my $self  = shift;
    my $id    = check_id_parameter( $self, "autoplugin" ) || return;
    my $redis = $self->LRR_CONF->get_redis();

    if ( $redis->exists($id) && LANraragi::Model::Config->enable_autotag ) {

        my ( $succ, $fail, $addedtags ) = LANraragi::Model::Plugins::exec_enabled_plugins_on_file($id);

        $self->render(
            json => {
                operation => "autoplugin",
                id        => $id,
                success   => 1,
                message   => "$succ Plugins used successfully, $fail Plugins failed, $addedtags tags added."
            }
        );
    } else {
        $self->render(
            json => {
                operation => "autoplugin",
                id        => $id,
                success   => 0,
                message   => "ID not found in database or AutoPlugin disabled by admin."
            }
        );
    }
    $redis->quit();
}

1;
