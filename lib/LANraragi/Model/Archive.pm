package LANraragi::Model::Archive;

use v5.36;
use experimental 'try';

use strict;
use warnings;
use utf8;

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
use LANraragi::Utils::Archive    qw(extract_single_file extract_single_file extract_thumbnail);
use LANraragi::Utils::Database
  qw(redis_encode redis_decode invalidate_cache set_title set_tags set_summary get_archive_json get_archive_json_multi);
use LANraragi::Utils::PageCache;

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
    no warnings 'experimental::try';
    try {
        $newthumb = extract_thumbnail( $id, $page, 1, 1 )
    } catch ($e) {
        render_api_response( $self, "update_thumbnail", $e );
        return;
    }

    if ( !$newthumb ) {
        render_api_response( $self, "update_thumbnail", "Thumbnail not generated." );
    } else {
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
        my $thumbname = "$thumbdir/$subfolder/$id/$page.$format";

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
    my $is_first_page = $page == 0;

    my $no_fallback = $self->req->param('no_fallback');
    $no_fallback = ( $no_fallback && $no_fallback eq "true" ) || "0";    # Prevent undef warnings by checking the variable first

    my $thumbdir        = LANraragi::Model::Config->get_thumbdir;
    my $use_jxl         = LANraragi::Model::Config->get_jxlthumbpages;
    my $format          = $use_jxl         ? 'jxl' : 'jpg';

    # Thumbnails are stored in the content directory, thumb subfolder.
    # Another subfolder with the first two characters of the id is used for FS optimization.
    my $subfolder = substr( $id, 0, 2 );

    # Check for the page and set the appropriate thumbnail name and fallback thumbnail name
    my $thumbbase          = ($is_first_page) ? "$thumbdir/$subfolder/$id" : "$thumbdir/$subfolder/$id/$page";
    my $thumbname          = "$thumbbase.$format";
    my $use_hq             = $page eq 0 || LANraragi::Model::Config->get_hqthumbpages;

    my $cachekey = "thumbnail/" . $thumbname;

    my $thumbnail = LANraragi::Utils::PageCache::fetch($cachekey);
    if (!defined($thumbnail)) {
        $thumbnail = extract_thumbnail($id, $page, $page eq 0, $use_hq);
        if (defined($thumbnail)) {
            LANraragi::Utils::PageCache::put($cachekey, $thumbnail);

        } else {
            $thumbnail = "fuck";
        }
    }
    return $self->render_file(data => $thumbnail);
}

sub get_page_data ($id, $path) {
    my $cachekey     = "page/$id/$path";
    my $content = LANraragi::Utils::PageCache::fetch($cachekey);
    if ( !defined($content) ) {
        # Extract the file from the parent archive if it doesn't exist
        my $redis = LANraragi::Model::Config->get_redis;
        my $archive = $redis->hget($id, "file");
        $redis->quit();
        $content = extract_single_file($archive, $path);
        LANraragi::Utils::PageCache::put($cachekey, $content);
    }
    return $content;
}

sub serve_page {
    my ( $self, $id, $path ) = @_;

    my $logger = get_logger( "File Serving", "lanraragi" );

    $logger->debug("Page /$id/$path was requested");

    # Apply resizing transformation if set in Settings
    if ( LANraragi::Model::Config->enable_resize ) {

        # Store resized files in a subfolder of the ID's temp folder, keyed by quality
        my $threshold    = LANraragi::Model::Config->get_threshold;
        my $quality      = LANraragi::Model::Config->get_readquality;

        # TODO: This is inefficient, doesn't reuse non-resized image cache
        my $cachekey = "resize_page/$id/$path/$threshold/$quality";
        my $content = LANraragi::Utils::PageCache::fetch($cachekey);
        if ( !defined($content)) {
            $content = LANraragi::Model::Reader::resize_image(get_page_data($id, $path), $quality, $threshold);
            LANraragi::Utils::PageCache::put($cachekey, $content);
        }

        # resize_image always converts the image to jpg
        $self->render_file(
            data => $content
        );
    } else {

     # Get the file extension to report content-type properly
        my ( $n, $p, $file_ext ) = fileparse( $path, qr/\.[^.]*/ );
        my $content = get_page_data($id, $path);
        $logger->debug("Data size:".length($content));
        # Serve extracted file directly
        $self->render_file(
            data   => $content,
            format => substr( $file_ext, 1 )
        );
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
    $redis_search->zrem( "LRR_TITLES", "$oldtitle\0$id" );
    $redis_search->srem( "LRR_NEW",         $id );
    $redis_search->srem( "LRR_UNTAGGED",    $id );
    $redis_search->srem( "LRR_TANKGROUPED", $id );
    $redis_search->quit();

    # Remove from tanks/collections
    foreach my $tank_id ( LANraragi::Model::Tankoubon::get_tankoubons_containing_archive($id) ) {
        LANraragi::Model::Tankoubon::remove_from_tankoubon( $tank_id, $id );
    }

    foreach my $cat ( LANraragi::Model::Category::get_categories_containing_archive($id) ) {
        my $catid = %{$cat}{"id"};
        LANraragi::Model::Category::remove_from_category( $catid, $id );
    }

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
