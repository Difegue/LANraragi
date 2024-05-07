package LANraragi::Controller::Api::Archive;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Encode;
use Storable;
use Mojo::JSON   qw(decode_json);
use Scalar::Util qw(looks_like_number);

use LANraragi::Utils::Generic  qw(render_api_response);
use LANraragi::Utils::Database qw(get_archive_json set_isnew);

use LANraragi::Model::Archive;
use LANraragi::Model::Category;
use LANraragi::Model::Config;
use LANraragi::Model::Reader;

# Archive API.

# Handle missing ID parameter for a whole lot of api methods down below.
sub check_id_parameter {
    my ( $mojo, $operation ) = @_;

    # Use either the id query param(deprecated), or the URL component.
    my $id = $mojo->req->param('id') || $mojo->stash('id') || 0;
    unless ($id) {
        render_api_response( $mojo, $operation, "No archive ID specified." );
    }
    return $id;
}

sub serve_archivelist {
    my $self   = shift;
    my @idlist = LANraragi::Model::Archive::generate_archive_list;
    $self->render( json => \@idlist );
}

sub serve_untagged_archivelist {
    my $self  = shift;
    my $redis = $self->LRR_CONF->get_redis_search;

    my @untagged = $redis->smembers("LRR_UNTAGGED");
    $redis->quit;

    $self->render( json => \@untagged );
}

sub serve_metadata {
    my $self  = shift;
    my $id    = check_id_parameter( $self, "metadata" ) || return;
    my $redis = $self->LRR_CONF->get_redis;

    my $arcdata = get_archive_json( $redis, $id );
    $redis->quit;

    if ($arcdata) {
        $self->render( json => $arcdata );
    } else {
        render_api_response( $self, "metadata", "This ID doesn't exist on the server." );
    }
}

# Find which categories this ID is saved in.
sub get_categories {

    my $self = shift;
    my $id   = check_id_parameter( $self, "find_arc_categories" ) || return;

    my @categories = LANraragi::Model::Category::get_categories_containing_archive($id);

    $self->render(
        json => {
            operation  => "find_arc_categories",
            categories => \@categories,
            success    => 1
        }
    );
}

sub serve_thumbnail {
    my $self = shift;
    my $id   = check_id_parameter( $self, "serve_thumbnail" ) || return;
    LANraragi::Model::Archive::serve_thumbnail( $self, $id );
}

sub update_thumbnail {
    my $self = shift;
    my $id   = check_id_parameter( $self, "update_thumbnail" ) || return;
    LANraragi::Model::Archive::update_thumbnail( $self, $id );
}

sub generate_page_thumbnails {
    my $self = shift;
    my $id   = check_id_parameter( $self, "generate_page_thumbnails" ) || return;
    LANraragi::Model::Archive::generate_page_thumbnails( $self, $id );
}

# Use RenderFile to get the file of the provided id to the client.
sub serve_file {

    my $self  = shift;
    my $id    = check_id_parameter( $self, "serve_file" ) || return;
    my $redis = $self->LRR_CONF->get_redis;

    my $file = $redis->hget( $id, "file" );
    $redis->quit();
    $self->render_file( filepath => $file );
}

# Serve an archive page from the temporary folder, using RenderFile.
sub serve_page {
    my $self = shift;
    my $id   = check_id_parameter( $self, "serve_page" ) || return;
    my $path = $self->req->param('path')                 || "404.xyz";

    LANraragi::Model::Archive::serve_page( $self, $id, $path );
}

sub get_file_list {
    my $self = shift;
    my $id   = check_id_parameter( $self, "get_file_list" ) || return;

    my $force = $self->req->param('force') eq "true" || "0";
    my $reader_json;

    eval { $reader_json = LANraragi::Model::Reader::build_reader_JSON( $self, $id, $force ); };
    my $err = $@;

    if ($err) {
        render_api_response( $self, "get_file_list", $err );
    } else {
        $self->render( json => $reader_json );
    }
}

sub clear_new {
    my $self = shift;
    my $id   = check_id_parameter( $self, "clear_new" ) || return;

    set_isnew( $id, "false" );

    $self->render(
        json => {
            operation => "clear_new",
            id        => $id,
            success   => 1
        }
    );
}

sub delete_archive {
    my $self = shift;
    my $id   = check_id_parameter( $self, "delete_archive" ) || return;

    my $delStatus = LANraragi::Model::Archive::delete_archive($id);

    $self->render(
        json => {
            operation => "delete_archive",
            id        => $id,
            filename  => $delStatus,
            success   => $delStatus eq "0" ? 0 : 1
        }
    );
}

sub update_metadata {
    my $self = shift;
    my $id   = check_id_parameter( $self, "update_metadata" ) || return;

    my $title   = $self->req->param('title');
    my $tags    = $self->req->param('tags');
    my $summary = $self->req->param('summary');

    my $res = LANraragi::Model::Archive::update_metadata( $id, $title, $tags, $summary );

    if ( $res eq "" ) {
        render_api_response( $self, "update_metadata" );
    } else {
        render_api_response( $self, "update_metadata", $res );
    }
}

sub update_progress {
    my $self = shift;
    my $id   = check_id_parameter( $self, "update_progress" ) || return;

    my $page = $self->stash('page') || 0;
    my $time = time();

    # Undocumented parameter to force progress update
    my $force = $self->req->param('force') || 0;

    my $redis     = $self->LRR_CONF->get_redis;
    my $redis_cfg = $self->LRR_CONF->get_redis_config;
    my $pagecount = $redis->hget( $id, "pagecount" );

    if ( LANraragi::Model::Config->enable_localprogress ) {
        render_api_response( $self, "update_progress", "Server-side Progress Tracking is disabled on this instance." );
        return;
    }

    # This relies on pagecount, so you can't update progress for archives that don't have a valid pagecount recorded yet.
    unless ( $pagecount || $force ) {
        render_api_response( $self, "update_progress", "Archive doesn't have a total page count recorded yet." );
        return;
    }

    # Safety-check the given page value.
    unless ( $force || ( looks_like_number($page) && $page > 0 && $page <= $pagecount ) ) {
        render_api_response( $self, "update_progress", "Invalid progress value." );
        return;
    }

    # Just set the progress value.
    $redis->hset( $id, "progress",     $page );
    $redis->hset( $id, "lastreadtime", $time );

    # Update total pages read statistic
    $redis_cfg->incr("LRR_TOTALPAGESTAT");

    $redis->quit();
    $redis_cfg->quit();

    $self->render(
        json => {
            operation    => "update_progress",
            id           => $id,
            page         => $page,
            lastreadtime => $time,
            success      => 1
        }
    );

}

1;
