package LANraragi::Model::Archive;

use strict;
use warnings;
use utf8;

use Cwd 'abs_path';
use Redis;
use Time::HiRes qw(usleep);
use File::Basename;
use File::Copy "cp";
use File::Path qw(make_path);

use LANraragi::Utils::Generic qw(remove_spaces remove_newlines render_api_response);
use LANraragi::Utils::TempFolder qw(get_temp);
use LANraragi::Utils::Logging qw(get_logger);
use LANraragi::Utils::Archive qw(extract_single_file extract_thumbnail);
use LANraragi::Utils::Database
  qw(redis_encode redis_decode invalidate_cache set_title set_tags get_archive_json get_archive_json_multi);

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

    # Thumbnails are stored in the content directory, thumb subfolder.
    # Another subfolder with the first two characters of the id is used for FS optimization.
    my $subfolder = substr( $id, 0, 2 );
    my $thumbname = "$thumbdir/$subfolder/$id.jpg";    # Path to main thumbnail

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

sub serve_thumbnail {

    my ( $self, $id ) = @_;

    my $page = $self->req->param('page');
    $page = 0 unless $page;

    my $no_fallback = $self->req->param('no_fallback');
    $no_fallback = ( $no_fallback && $no_fallback eq "true" ) || "0";    # Prevent undef warnings by checking the variable first

    my $thumbdir = LANraragi::Model::Config->get_thumbdir;

    # Thumbnails are stored in the content directory, thumb subfolder.
    # Another subfolder with the first two characters of the id is used for FS optimization.
    my $subfolder = substr( $id, 0, 2 );
    my $thumbname = "$thumbdir/$subfolder/$id.jpg";

    if ( $page > 0 ) {
        $thumbname = "$thumbdir/$subfolder/$id/$page.jpg";
    }

    # Queue a minion job to generate the thumbnail. Thumbnail jobs have the lowest priority.
    unless ( -e $thumbname ) {
        my $job_id = $self->minion->enqueue( thumbnail_task => [ $thumbdir, $id, $page ] => { priority => 0, attempts => 3 } );

        if ($no_fallback) {

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
            usleep(10000);    # 10ms
            $timeout += 10;   # Sanity check in case the file remains at 0 bytes forever
            $last_size = $size;
            $size      = -s $file;

            # If the size hasn't changed since the last loop, it's likely the file is ready.
            last
              if ( $last_size eq $size && ( $size ne 0 || $timeout > 1000 ) );
        }

    } else {

        # Extract the file from the parent archive if it doesn't exist
        $logger->debug("Extracting missing file");
        my $redis = LANraragi::Model::Config->get_redis;
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

            # Store resized files in a subfolder of the ID's temp folder
            my $resized_file = "$tempfldr/$id/resized/$path";
            my ( $n, $resized_folder, $e ) = fileparse( $resized_file, qr/\.[^.]*/ );
            make_path($resized_folder);

            $logger->debug("Copying file to $resized_folder for resize transformation");
            cp( $file, $resized_file );

            my $threshold = LANraragi::Model::Config->get_threshold;
            my $quality   = LANraragi::Model::Config->get_readquality;
            LANraragi::Model::Reader::resize_image( $resized_file, $quality, $threshold );

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
    my ( $id, $title, $tags ) = @_;

    unless ( defined $title || defined $tags ) {
        return "No metadata parameters (Please supply title, tags or both)";
    }

    # Clean up the user's inputs and encode them.
    ( remove_spaces($_) )   for ( $title, $tags );
    ( remove_newlines($_) ) for ( $title, $tags );

    if ( defined $title ) {
        set_title( $id, $title );
    }

    if ( defined $tags ) {
        set_tags( $id, $tags );
    }

    # Bust cache
    invalidate_cache();

    # No errors.
    return "";
}

1;
