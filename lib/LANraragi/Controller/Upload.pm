package LANraragi::Controller::Upload;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use File::Temp qw/ tempfile tempdir /;
use File::Copy;
use File::Find;
use File::Basename;

use LANraragi::Utils::Generic;
use LANraragi::Utils::Archive;
use LANraragi::Utils::Database;

use LANraragi::Model::Config;

sub process_upload {
    my $self = shift;

    #Receive uploaded file.
    my $file     = $self->req->upload('file');
    my $filename = $file->filename;

    my $uploadMime = $file->headers->content_type;

    #Check if the uploaded file's extension matches one we accept
    if ( $filename =~ /^.+\.(?:zip|rar|7z|tar|tar\.gz|lzma|xz|cbz|cbr)$/ ) {

        # Move file to a temp folder (not the default LRR one)
        my $tempdir  = tempdir();
        my $tempfile = $tempdir . '/' . $filename;
        $file->move_to($tempfile) or die "Couldn't move uploaded file.";

        # Update $tempfile to the exact reference created by the host filesystem
        # This is done by finding the first (and only) file in $tempdir.
        find(sub {
                return if -d $_;
                $tempfile = $File::Find::name;
                $filename = $_;
            }, $tempdir);

        # Compute an ID here
        my $id = LANraragi::Utils::Database::compute_id($tempfile);
        $self->LRR_LOGGER->debug("ID of uploaded file is $id");

        # Future home of the file
        my $output_file = $self->LRR_CONF->get_userdir . '/'
          . $filename;    

        #Check if the ID is already in the database, and
        #that the file it references still exists on the filesystem
        my $redis  = $self->LRR_CONF->get_redis();
        my $isdupe = $redis->exists($id) && -e $redis->hget($id, "file");

        if ( -e $output_file || $isdupe ) {

            # Trash temporary file
            unlink $tempfile;

            # The file already exists
            $self->render(
                json => {
                    operation => "upload",
                    name      => $file->filename,
                    type      => $uploadMime,
                    success   => 0,
                    error     => $isdupe
                    ? "This file already exists in the Library."
                    : "A file with the same name is present in the Library."
                }
            );
        }
        else {

            # Add the file to the database ourselves so Shinobu doesn't do it
            # This allows autoplugin to be ran ASAP.
            LANraragi::Utils::Database::add_archive_to_redis( $id, $output_file,
                $redis );

            # Move the file to the content folder and let Shinobu handle the index JSON.
            # Move to a .tmp first in case copy to the content folder takes a while...
            move($tempfile,$output_file.".upload");
            # Then rename inside the content folder itself to proc Shinobu.
            move($output_file.".upload", $output_file);

            if ( -e $output_file ) {
                $self->render(
                json => {
                    operation => "upload",
                    name      => $file->filename,
                    type      => $uploadMime,
                    success   => 1,
                    id        => $id
                }
                );
            } else {
                $self->render(
                json => {
                    operation => "upload",
                    name      => $file->filename,
                    type      => $uploadMime,
                    success   => 0,
                    error     => "The file couldn't be moved to your content folder!"
                }
                );
            }
            
        }
        $redis->quit();
    }
    else {

        $self->render(
            json => {
                operation => "upload",
                name      => $file->filename,
                type      => $uploadMime,
                success   => 0,
                error     => "Unsupported File Extension. (" . $uploadMime . ")"
            }
        );
    }
}

sub index {

    my $self = shift;

    $self->render(
        template    => "upload",
        title       => $self->LRR_CONF->get_htmltitle,
        autoplugin  => $self->LRR_CONF->enable_autotag,
        cssdrop     => LANraragi::Utils::Generic::generate_themes_selector,
        csshead     => LANraragi::Utils::Generic::generate_themes_header($self),
        version     => $self->LRR_VERSION
    );
}

1;
