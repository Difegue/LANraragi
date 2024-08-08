package LANraragi::Model::Archive;

use strict;
use warnings;
use utf8;

use feature qw(signatures);
no warnings 'experimental::signatures';

use Cwd 'abs_path';
use Redis;
use Time::HiRes qw(usleep);
use File::Path  qw(remove_tree);
use File::Basename;
use File::Copy "cp";
use File::Path qw(make_path);

use LANraragi::Utils::Generic    qw(render_api_response);
use LANraragi::Utils::String     qw(trim trim_CRLF);
use LANraragi::Utils::TempFolder qw(get_temp);
use LANraragi::Utils::Logging    qw(get_logger);
use LANraragi::Utils::Archive    qw(extract_single_file extract_thumbnail);
use LANraragi::Utils::Database
  qw(redis_encode redis_decode invalidate_cache set_title set_tags set_summary get_archive_json get_archive_json_multi);

# get_title(id)
#   Returns the title for the archive matching the given id.
#   Returns undef if the id doesn't exist.
sub get_title ($id) {

    my $logger = get_logger( "Archives", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis;

    if ( $id eq "" ) {
        $logger->debug("No archive ID provided.");
        return ();
    }

    return redis_decode( $redis->hget( $id, "title" ) );
}

# Functions used when dealing with archives.

# Generates an array of all the archive JSONs in the database that have existing files.
sub generate_archive_list {

    my $redis = LANraragi::Model::Config->get_redis;
    my @keys  = $redis->keys('????????????????????????????????????????');
    $redis->quit;

    return get_archive_json_multi(@keys);
}

sub update_thumbnail {

    my ( $self, $id ) = @_;

    my $page = $self->req->param('page');
    $page = 1 unless $page;

    my $thumbdir = LANraragi::Model::Config->get_thumbdir;
    my $use_jxl  = LANraragi::Model::Config->get_jxlthumbpages;
    my $format   = $use_jxl ? 'jxl' : 'jpg';

    # Thumbnails are stored in the content directory, thumb subfolder.
    # Another subfolder with the first two characters of the id is used for FS optimization.
    my $subfolder = substr( $id, 0, 2 );
    my $thumbname = "$thumbdir/$subfolder/$id.$format";    # Path to main thumbnail

    my $newthumb = "";

    # Get the required thumbnail we want to make the main one
    eval { $newthumb = extract_thumbnail( $thumbdir, $id, $page, 1 ) };

    if ( $@ || !$newthumb ) {
        render_api_response( $self, "update_thumbnail", $@ );
    } else {
        if ( $newthumb ne $thumbname && $newthumb ne "" ) {

            # Copy the thumbnail to the main thumbnail location
            cp( $newthumb, $thumbname );
        }

        $self->render(
            json => {
                operation     => "update_thumbnail",
                new_thumbnail => $newthumb,
                success       => 1
            }
        );
    }

}

sub generate_page_thumbnails {

    my ( $self, $id ) = @_;

    my $force = $self->req->param('force');
    $force = ( $force && $force eq "true" ) || "0";    # Prevent undef warnings by checking the variable first

    my $logger   = get_logger( "Archives", "lanraragi" );
    my $thumbdir = LANraragi::Model::Config->get_thumbdir;
    my $use_hq   = LANraragi::Model::Config->get_hqthumbpages;
    my $use_jxl  = LANraragi::Model::Config->get_jxlthumbpages;
    my $format   = $use_jxl ? 'jxl' : 'jpg';

    # Get the number of pages in the archive
    my $redis = LANraragi::Model::Config->get_redis;
    my $pages = $redis->hget( $id, "pagecount" );

    my $subfolder = substr( $id, 0, 2 );
    my $thumbname = "$thumbdir/$subfolder/$id.$format";

    my $should_queue_job = 0;

    for ( my $page = 1; $page <= $pages; $page++ ) {
        my $thumbname = ( $page - 1 > 0 ) ? "$thumbdir/$subfolder/$id/$page.$format" : "$thumbdir/$subfolder/$id.$format";

        unless ( $force == 0 && -e $thumbname ) {
            $logger->debug("Thumbnail for page $page doesn't exist (path: $thumbname or force=$force), queueing job.");
            $should_queue_job = 1;
            last;
        }
    }

    if ($should_queue_job) {

        # Check if a job is already queued for this archive
        if ( $redis->hexists( $id, "thumbjob" ) ) {

            my $job_id = $redis->hget( $id, "thumbjob" );

            # If the job is pending or running, don't queue a new job and just return this one
            my $job_state = $self->minion->job($job_id)->info->{state};
            if ( $job_state eq "active" || $job_state eq "inactive" ) {
                $self->render(
                    json => {
                        operation => "generate_page_thumbnails",
                        success   => 1,
                        job       => $job_id
                    },
                    status => 202    # 202 Accepted
                );
                $redis->quit;
                return;
            }
        }

        # Queue a minion job to generate the thumbnails. Clients can check on its progress through the job ID.
        my $job_id = $self->minion->enqueue( page_thumbnails => [ $id, $force ] => { priority => 0, attempts => 3 } );

        # Save job in Redis so we can check on it if this endpoint is called again
        $redis->hset( $id, "thumbjob", $job_id );
        $self->render(
            json => {
                operation => "generate_page_thumbnails",
                success   => 1,
                job       => $job_id
            },
            status => 202    # 202 Accepted
        );
    } else {
        $self->render(
            json => {
                operation => "generate_page_thumbnails",
                success   => 1,
                message   => "No job queued, all thumbnails already exist."
            },
            status => 200    # 200 OK
        );
    }

    $redis->quit;
}

sub serve_thumbnail {

    my ( $self, $id ) = @_;

    my $page = $self->req->param('page');
    $page = 0 unless $page;

    my $no_fallback = $self->req->param('no_fallback');
    $no_fallback = ( $no_fallback && $no_fallback eq "true" ) || "0";    # Prevent undef warnings by checking the variable first

    my $thumbdir        = LANraragi::Model::Config->get_thumbdir;
    my $use_jxl         = LANraragi::Model::Config->get_jxlthumbpages;
    my $format          = $use_jxl         ? 'jxl' : 'jpg';
    my $fallback_format = $format eq 'jxl' ? 'jpg' : 'jxl';

    # Thumbnails are stored in the content directory, thumb subfolder.
    # Another subfolder with the first two characters of the id is used for FS optimization.
    my $subfolder = substr( $id, 0, 2 );

    # Check for the page and set the appropriate thumbnail name and fallback thumbnail name
    my $thumbbase          = ( $page - 1 > 0 ) ? "$thumbdir/$subfolder/$id/$page" : "$thumbdir/$subfolder/$id";
    my $thumbname          = "$thumbbase.$format";
    my $fallback_thumbname = "$thumbbase.$fallback_format";

    # Check if the preferred format thumbnail exists, if not, try the alternate format
    unless ( -e $thumbname ) {
        $thumbname = $fallback_thumbname;
    }

    unless ( -e $thumbname ) {

        if ($no_fallback) {

            # Queue a minion job to generate the thumbnail. Thumbnail jobs have the lowest priority.
            my $job_id = $self->minion->enqueue( thumbnail_task => [ $thumbdir, $id, $page ] => { priority => 0, attempts => 3 } );
            $self->render(
                json => {
                    operation => "serve_thumbnail",
                    success   => 1,
                    job       => $job_id
                },
                status => 202    # 202 Accepted
            );
        } else {

            # If the thumbnail doesn't exist, serve the default thumbnail.
            $self->render_file( filepath => "./public/img/noThumb.png" );
        }
        return;
    } else {

        # Simply serve the thumbnail.
        $self->render_file( filepath => $thumbname );
    }
}

sub serve_page {
    my ( $self, $id, $path ) = @_;

    my $logger = get_logger( "File Serving", "lanraragi" );

    $logger->debug("Page /$id/$path was requested");

    my $tempfldr = get_temp();
    my $file     = $tempfldr . "/$id/$path";

    if ( -e $file ) {

        # Freshly created files might not be complete yet.
        # We have to wait before trying to serve them out...
        my $last_size = 0;
        my $size      = -s $file;
        my $timeout   = 0;
        while (1) {
            $logger->debug("Waiting for file to be fully written ($size, previously $last_size)");
            usleep(10000);     # 10ms
            $timeout += 10;    # Sanity check in case the file remains at 0 bytes forever
            $last_size = $size;
            $size      = -s $file;

            # If the size hasn't changed since the last loop, it's likely the file is ready.
            last
              if ( $last_size eq $size && ( $size ne 0 || $timeout > 1000 ) );
        }

    } else {

        # Extract the file from the parent archive if it doesn't exist
        $logger->debug("Extracting missing file");
        my $redis   = LANraragi::Model::Config->get_redis;
        my $archive = $redis->hget( $id, "file" );
        $redis->quit();

        # Check again just in case
        unless ( -e $file ) {
            my $outfile = extract_single_file( $archive, $path, $tempfldr . "/$id" );
            die "mismatched filenames $file and $outfile" unless $file eq $outfile;    # sanity check
        }
    }

    # abs_path returns null if the path is invalid or doesn't exist.
    my $abspath = abs_path($file);

    if ( !$abspath ) {
        $logger->debug("abs_path returned null with $file as input");
        render_api_response( $self, "serve_page", "Invalid path $path." );
        return;
    }

    $logger->debug("Path to requested file is $abspath");

    # This API can only serve files from the temp folder
    if ( index( $abspath, $tempfldr ) != -1 ) {

        # Apply resizing transformation if set in Settings
        if ( LANraragi::Model::Config->enable_resize ) {

            # Store resized files in a subfolder of the ID's temp folder, keyed by quality
            my $threshold    = LANraragi::Model::Config->get_threshold;
            my $quality      = LANraragi::Model::Config->get_readquality;
            my $resized_file = "$tempfldr/$id/resized/$quality/$path";

            unless ( -e $resized_file ) {
                my ( $n, $resized_folder, $e ) = fileparse( $resized_file, qr/\.[^.]*/ );
                make_path($resized_folder);

                $logger->debug("Copying file to $resized_folder for resize transformation");
                cp( $file, $resized_file );

                LANraragi::Model::Reader::resize_image( $resized_file, $quality, $threshold );
            }

            # resize_image always converts the image to jpg
            $self->render_file(
                filepath            => $resized_file,
                content_disposition => "inline",
                format              => "jpg"
            );

        } else {

            # Get the file extension to report content-type properly
            my ( $n, $p, $file_ext ) = fileparse( $file, qr/\.[^.]*/ );

            # Serve extracted file directly
            $self->render_file(
                filepath            => $file,
                content_disposition => "inline",
                format              => substr( $file_ext, 1 )
            );
        }

    } else {
        render_api_response( $self, "serve_page", "This API cannot render files outside of the temporary folder." );
    }
}

sub update_metadata {
    my ( $id, $title, $tags, $summary ) = @_;

    unless ( defined $title || defined $tags ) {
        return "No metadata parameters (Please supply title, tags or summary)";
    }

    # Clean up the user's inputs and encode them.
    ( $_ = trim($_) )      for ( $title, $tags );
    ( $_ = trim_CRLF($_) ) for ( $title, $tags );

    if ( defined $title ) {
        set_title( $id, $title );
    }

    if ( defined $tags ) {
        set_tags( $id, $tags );
    }

    if ( defined $summary ) {
        set_summary( $id, $summary );
    }

    # Bust cache
    invalidate_cache();

    # No errors.
    return "";
}

# Deletes the archive with the given id from redis, and the matching archive file/thumbnail.
sub delete_archive ($id) {

    my $redis    = LANraragi::Model::Config->get_redis;
    my $filename = $redis->hget( $id, "file" );
    my $oldtags  = $redis->hget( $id, "tags" );
    $oldtags = redis_decode($oldtags);

    my $oldtitle = lc( redis_decode( $redis->hget( $id, "title" ) ) );
    $oldtitle = trim($oldtitle);
    $oldtitle = trim_CRLF($oldtitle);
    $oldtitle = redis_encode($oldtitle);

    $redis->del($id);
    $redis->quit();

    # Remove matching data from the search indexes
    my $redis_search = LANraragi::Model::Config->get_redis_search;
    $redis_search->zrem( "LRR_TITLES",       "$oldtitle\0$id" );
    $redis_search->srem( "LRR_NEW",          $id );
    $redis_search->srem( "LRR_UNTAGGED",     $id );
    $redis_search->srem( "LRR_TANKGROUPED",  $id );
    $redis_search->quit();

    LANraragi::Utils::Database::update_indexes( $id, $oldtags, "" );

    if ( -e $filename ) {
        my $status = unlink $filename;

        my $thumbdir  = LANraragi::Model::Config->get_thumbdir;
        my $subfolder = substr( $id, 0, 2 );

        my $jpg_thumbname = "$thumbdir/$subfolder/$id.jpg";
        unlink $jpg_thumbname;

        my $jxl_thumbname = "$thumbdir/$subfolder/$id.jxl";
        unlink $jxl_thumbname;

        # Delete the thumbpages folder
        remove_tree("$thumbdir/$subfolder/$id/");

        return $status ? $filename : "0";
    }

    return "0";
}

1;
