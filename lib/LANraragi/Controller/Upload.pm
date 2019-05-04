package LANraragi::Controller::Upload;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use File::Temp qw/ tempfile tempdir /;
use File::Copy;

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

        my $output_file = $self->LRR_CONF->get_userdir . '/'
          . $filename;    #future home of the file

        # Move file to a temp folder (not the default LRR one)
        my $tempfile = tempdir() . '/' . $filename;
        $file->move_to($tempfile);

        #Compute an ID here
        my $id = LANraragi::Utils::Database::compute_id($tempfile);
        $self->LRR_LOGGER->debug("ID of uploaded file is $id");

        #Check if the ID is already in the database, and
        #that the file it references still exists on the filesystem
        my $redis  = $self->LRR_CONF->get_redis();
        my $isdupe = $redis->exists($id) && -e $redis->hget($id, "file");

        if ( -e $output_file || $isdupe ) {

            #if it doesn't already exist, that is.
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
            #Move the file to the content folder and let Shinobu handle it
            move($tempfile,$output_file);

            $self->render(
                json => {
                    operation => "upload",
                    name      => $file->filename,
                    type      => $uploadMime,
                    success   => 1,
                    id        => $id
                }
            );
        }
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
        template => "upload",
        title    => $self->LRR_CONF->get_htmltitle,
        cssdrop  => LANraragi::Utils::Generic::generate_themes_selector,
        csshead  => LANraragi::Utils::Generic::generate_themes_header
    );
}

1;
