package LANraragi::Controller::Api::Archive;
use Mojo::Base 'Mojolicious::Controller';

use Digest::SHA qw(sha1_hex);
use Redis;
use Encode;
use Storable;
use Mojo::JSON   qw(decode_json);
use Scalar::Util qw(looks_like_number);

use File::Temp qw(tempdir);
use File::Basename;
use File::Find;

use LANraragi::Utils::Archive  qw(extract_thumbnail);
use LANraragi::Utils::Generic  qw(render_api_response is_archive get_bytelength);
use LANraragi::Utils::Database qw(get_archive_json set_isnew);
use LANraragi::Utils::Logging  qw(get_logger);

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

# Create a file archive along with any metadata.
# adapted from Upload.pm
sub create_archive {
    my $self = shift;

    my $logger = get_logger( "Archive API ", "lanraragi");
    my $redis   = LANraragi::Model::Config->get_redis;

    # receive uploaded file
    my $upload              = $self->req->upload('file');
    my $expected_checksum   = $self->req->param('file_checksum'); # optional

    # require file
    if ( ! defined $upload || !$upload ) {
        return $self->render(
            json => {
                operation   => "upload",
                success     => 0,
                error       => "No file attached"
            },
            status => 400
        );
    }

    # checksum verification stage.
    if ( $expected_checksum ) {
        my $file_content        = $upload->slurp;
        my $actual_checksum     = sha1_hex($file_content);
        if ( $expected_checksum ne $actual_checksum ) {
            return $self->render(
                json => {
                    operation   => "upload",
                    success     => 0,
                    error       => "Checksum mismatch: expected $expected_checksum, got $actual_checksum."
                },
                status => 417
            );
        }
    }

    my $filename        = $upload->filename;
    my $uploadMime      = $upload->headers->content_type;

    # utf downgrade (see LANraragi::Utils::Minion)
    $filename = encode('UTF-8', $filename);
    unless (utf8::downgrade($filename, 1)) {
        $logger->error("Bullshit! File path \"$filename\" could not be converted back to a byte sequence!");
        return $self->render(
            json => {
                operation   => "upload",
                success     => 0,
                error       => "\"$filename\" could not be converted back to a byte sequence!"
            },
            status => 422
        )
    };

    # lock resource
    my $lock            = $redis->setnx( "upload:$filename", 1 );
    if ( !$lock ) {
        return $self->render(
            json => {
                operation   => "upload",
                success     => 0,
                error       => "Locked resource: $filename."
            },
            status => 423
        );
    }
    $redis->expire( "upload:$filename", 10 );

    # metadata extraction
    my $catid           = $self->req->param('category_id');
    my $tags            = $self->req->param('tags');
    my $title           = $self->req->param('title');
    my $summary         = $self->req->param('summary');

    # return error if archive is not supported.
    if ( !is_archive($filename) ) {
        $redis->del("upload:$filename");
        $redis->quit();
        return $self->render(
            json => {
                operation   => "upload",
                success     => 0,
                error       => "Unsupported file extension ($filename)"
            },
            status => 415
        );
    }

    # Move file to a temp folder (not the default LRR one)
    my $tempdir                 = tempdir();

    my ( $fn, $path, $ext )     = fileparse( $filename, qr/\.[^.]*/ );
    my $byte_limit              = LANraragi::Model::Config->enable_cryptofs ? 143 : 255;

    $filename = $fn;
    while ( get_bytelength( $filename . $ext . ".upload") > $byte_limit ) {
        $filename = substr( $filename, 0, -1 );
    }
    $filename = $filename . $ext;

    my $tempfile = $tempdir . '/' . $filename;
    if ( !$upload->move_to($tempfile) ) {
        $logger->error("Could not move uploaded file $filename to $tempfile");
        $redis->del("upload:$filename");
        $redis->quit();
        return $self->render(
            json => {
                operation   => "upload",
                success     => 0,
                error       => "Couldn't move uploaded file to temporary location."
            },
            status => 500
        );
    }

    # Update $tempfile to the exact reference created by the host filesystem
    # This is done by finding the first (and only) file in $tempdir.
    find(
        sub {
            return if -d $_;
            $tempfile = $File::Find::name;
            $filename = $_;
        },
        $tempdir
    );

    my ( $status_code, $id, $response_title, $message ) = LANraragi::Model::Upload::handle_incoming_file( $tempfile, $catid, $tags, $title, $summary );

    # post-processing thumbnail generation
    my %hash    = $redis->hgetall($id);
    my ( $thumbhash ) = @hash{qw(thumbhash)};
    unless ( length $thumbhash ) {
        $logger->info("Thumbnail hash invalid, regenerating.");
        my $thumbdir = LANraragi::Model::Config->get_thumbdir;
        $thumbhash = "";
        extract_thumbnail( $thumbdir, $id, 0, 1 );
        $thumbhash = $redis->hget( $id, "thumbhash" );
        $thumbhash = LANraragi::Utils::Database::redis_decode($thumbhash);
    }
    $redis->del("upload:$filename");
    $redis->quit();

    unless ( $status_code == 200 ) {
        return $self->render(
            json => {
                operation   => "upload",
                success     => 0,
                error       => $message,
                id          => $id
            },
            status => $status_code
        );
    }

    return $self->render(
        json => {
            operation   => "upload",
            success     => 1,
            id          => $id
        },
        status => 200
    );
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

    my $err = LANraragi::Model::Archive::update_metadata( $id, $title, $tags, $summary );

    if ( $err eq "" ) {
        my $title          = LANraragi::Model::Archive::get_title($id);
        my $successMessage = "Updated metadata for \"$title\"!";

        render_api_response( $self, "update_metadata", undef, $successMessage );
    } else {
        render_api_response( $self, "update_metadata", $err );
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
