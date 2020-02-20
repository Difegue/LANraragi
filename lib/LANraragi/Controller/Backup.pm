package LANraragi::Controller::Backup;
use Mojo::Base 'Mojolicious::Controller';

use LANraragi::Utils::Generic qw(generate_themes_selector generate_themes_header);
use LANraragi::Model::Backup;

# This action will render a template
sub index {
    my $self = shift;

    #GET with a parameter => do backup
    if ( $self->req->param('dobackup') ) {
        my $json = LANraragi::Model::Backup::build_backup_JSON();

#Write json to file in the user directory and serve that file through render_static
        my $file = $self->LRR_CONF->get_userdir . '/backup.json';

        if ( -e $file ) { unlink $file }

        my $OUTFILE;

        open $OUTFILE, '>>', $file;
        print {$OUTFILE} $json;
        close $OUTFILE;

        $self->render_file( filepath => $file );

    }
    else {    #Get with no parameters => Regular HTML printout
        $self->render(
            template => "backup",
            title    => $self->LRR_CONF->get_htmltitle,
            cssdrop  => generate_themes_selector,
            csshead  => generate_themes_header($self),
            version  => $self->LRR_VERSION
        );
    }
}

sub restore {
    my $self = shift;
    my $file = $self->req->upload('file');

    if ( $file->headers->content_type eq "application/json" ) {

        my $json = $file->slurp;
        LANraragi::Model::Backup::restore_from_JSON($json);

        $self->render(
            json => {
                operation => "restore_backup",
                success   => 1
            }
        );
    }
    else {
        $self->render(
            json => {
                operation => "restore_backup",
                success   => 0,
                error     => "Not a JSON file."
            }
        );
    }
}

1;
