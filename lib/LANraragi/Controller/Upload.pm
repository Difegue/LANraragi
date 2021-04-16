package LANraragi::Controller::Upload;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use File::Temp qw/ tempfile tempdir /;
use File::Copy;
use File::Find;
use File::Basename;

use LANraragi::Utils::Generic qw(generate_themes_selector generate_themes_header is_archive);

sub process_upload {
    my $self = shift;

    #Receive uploaded file.
    my $file     = $self->req->upload('file');
    my $catid    = $self->req->param('catid');
    my $filename = $file->filename;

    my $uploadMime = $file->headers->content_type;

    #Check if the uploaded file's extension matches one we accept
    if ( is_archive($filename) ) {

        # Move file to a temp folder (not the default LRR one)
        my $tempdir  = tempdir();
        my $tempfile = $tempdir . '/' . $filename;
        $file->move_to($tempfile) or die "Couldn't move uploaded file.";

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

        # Send a job to Minion to handle the uploaded file.
        my $jobid = $self->minion->enqueue( handle_upload => [ $tempfile, $catid ] => { priority => 2 } );

        # Reply with a reference to the job so the client can check on its progress.
        $self->render(
            json => {
                operation => "upload",
                name      => $file->filename,
                type      => $uploadMime,
                success   => 1,
                job       => $jobid
            }
        );

    } else {

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

    # Allow adding to category on direct uploads
    my @categories = LANraragi::Model::Category->get_category_list;

    # But only to static categories
    @categories = grep { %$_{"search"} eq "" } @categories;

    $self->render(
        template   => "upload",
        title      => $self->LRR_CONF->get_htmltitle,
        descstr    => $self->LRR_DESC,
        categories => \@categories,
        cssdrop    => generate_themes_selector,
        csshead    => generate_themes_header($self),
        version    => $self->LRR_VERSION
    );
}

1;
