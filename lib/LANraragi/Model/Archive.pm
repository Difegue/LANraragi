package LANraragi::Model::Archive;

use strict;
use warnings;
use utf8;

use Cwd 'abs_path';
use Redis;
use Encode;
use File::Temp qw(tempfile);
use File::Copy "cp";
use Mojo::Util qw(xml_escape);

use LANraragi::Utils::Generic qw(get_tag_with_namespace remove_spaces remove_newlines render_api_response);
use LANraragi::Utils::Archive qw(extract_thumbnail);
use LANraragi::Utils::TempFolder qw(get_temp);
use LANraragi::Utils::Database qw(redis_decode);

# Functions used when dealing with archives.

# Generates an array of all the archive JSONs in the database that have existing files.
sub generate_archive_list {

    my $redis = LANraragi::Model::Config->get_redis;
    my @keys  = $redis->keys('????????????????????????????????????????');
    my @list  = ();

    foreach my $id (@keys) {
        if ( -e $redis->hget( $id, "file" ) ) {
            my $arcdata = LANraragi::Utils::Database::build_archive_JSON( $redis, $id );
            push @list, $arcdata;
        }
    }

    $redis->quit;
    return @list;
}

sub generate_opds_catalog {

    my $mojo  = shift;
    my $redis = $mojo->LRR_CONF->get_redis;
    my @keys  = ();

    # Detailed pages just return a single entry instead of all the archives.
    if ( $mojo->req->param('id') ) {
        @keys = ( $mojo->req->param('id') );
    } else {
        @keys = $redis->keys('????????????????????????????????????????');
    }

    my @list = ();

    foreach my $id (@keys) {
        my $file = $redis->hget( $id, "file" );
        if ( -e $file ) {
            my $arcdata = LANraragi::Utils::Database::build_archive_JSON( $redis, $id );
            my $tags    = $arcdata->{tags};

            # Infer a few OPDS-related fields from the tags
            $arcdata->{dateadded} = get_tag_with_namespace( "dateadded", $tags, "2010-01-10T10:01:11Z" );
            $arcdata->{author}    = get_tag_with_namespace( "artist",    $tags, "" );
            $arcdata->{language}  = get_tag_with_namespace( "language",  $tags, "" );
            $arcdata->{circle}    = get_tag_with_namespace( "group",     $tags, "" );
            $arcdata->{event}     = get_tag_with_namespace( "event",     $tags, "" );

            # Application/zip is universally hated by all readers so it's better to use x-cbz and x-cbr here.
            if ( $file =~ /^(.*\/)*.+\.(pdf)$/ ) {
                $arcdata->{mimetype} = "application/pdf";
            } elsif ( $file =~ /^(.*\/)*.+\.(rar|cbr)$/ ) {
                $arcdata->{mimetype} = "application/x-cbr";
            } else {
                $arcdata->{mimetype} = "application/x-cbz";
            }

            for ( values %{$arcdata} ) { $_ = xml_escape($_); }

            push @list, $arcdata;
        }
    }

    $redis->quit;

    if ( $mojo->req->param('id') ) {
        @keys = ( $mojo->req->param('id') );
    } else {
        @keys = $redis->keys('????????????????????????????????????????');
    }

    return $mojo->render_to_string(
        template => $mojo->req->param('id') ? "opds_entry" : "opds",
        arclist  => \@list,
        arc      => $mojo->req->param('id') ? $list[0] : "",
        title    => $mojo->LRR_CONF->get_htmltitle,
        motd     => $mojo->LRR_CONF->get_motd,
        version  => $mojo->LRR_VERSION
    );
}

# Return a list of archive IDs that have no tags.
# Tags added automatically by the autotagger are ignored.
sub find_untagged_archives {

    my $redis = LANraragi::Model::Config->get_redis;
    my @keys  = $redis->keys('????????????????????????????????????????');
    my @untagged;

    #Parse the archive list.
    foreach my $id (@keys) {
        my $zipfile = $redis->hget( $id, "file" );
        if ( $zipfile && -e $zipfile ) {

            my $title = $redis->hget( $id, "title" );
            $title = redis_decode($title);

            my $tagstr = $redis->hget( $id, "tags" );
            $tagstr = redis_decode($tagstr);
            my @tags           = split( /,\s?/, $tagstr );
            my $nondefaulttags = 0;

            foreach my $t (@tags) {
                remove_spaces($t);
                remove_newlines($t);

                # the following are the only namespaces that LANraragi::Utils::Database::parse_name adds
                # date_added added for convenience as running the matching plugin doesn't really count as tagging
                $nondefaulttags += 1 unless $t =~ /(artist|parody|series|language|event|group|date_added):.*/;
            }

            #If the archive has no tags, or the tags namespaces are only from
            #filename parsing (probably), add it to the list.
            if ( !@tags || $nondefaulttags == 0 ) {
                push @untagged, $id;
            }
        }
    }
    $redis->quit;
    return @untagged;
}

sub serve_thumbnail {

    my ( $self, $id ) = @_;
    my $dirname = LANraragi::Model::Config->get_userdir;

    #Thumbnails are stored in the content directory, thumb subfolder.
    my $thumbname = $dirname . "/thumb/" . $id . ".jpg";

    unless ( -e $thumbname ) {
        $thumbname = extract_thumbnail( $dirname, $id );
    }

    #Simply serve the thumbnail.
    #If it doesn't exist, serve an error placeholder instead.
    if ( -e $thumbname ) {
        $self->render_file( filepath => $thumbname );
    } else {
        $self->render_file( filepath => "./public/img/noThumb.png" );
    }
}

sub serve_page {
    my ( $self, $id, $path ) = @_;

    my $tempfldr = get_temp();
    my $file     = $tempfldr . "/$id/$path";
    my $abspath  = abs_path($file);            # abs_path returns null if the path is invalid.

    if ( !$abspath ) {
        render_api_response($self, "serve_page", "Invalid path $path.");
    }

    unless (-e $abspath) {
        render_api_response($self, "serve_page", "$path does not exist.");
    }

    # This API can only serve files from the temp folder
    if ( index( $abspath, $tempfldr ) != -1 ) {

        # Apply resizing transformation if set in Settings
        if ( LANraragi::Model::Config->enable_resize ) {

            # Use File::Temp to copy the extracted file and resize it
            my ( $fh, $filename ) = tempfile();
            cp( $file, $fh );

            my $threshold = LANraragi::Model::Config->get_threshold;
            my $quality   = LANraragi::Model::Config->get_readquality;
            LANraragi::Model::Reader::resize_image( $filename, $quality, $threshold );

            $self->render_file( filepath => $filename );

        } else {
            # Serve extracted file directly
            $self->render_file( filepath => $file );
        }

    } else {
        render_api_response($self, "serve_page", "This API cannot render files outside of the temporary folder.");
    }
}

1;
