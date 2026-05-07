package LANraragi::Controller::Backup;
use Mojo::Base 'Mojolicious::Controller';

use LANraragi::Utils::Generic qw(generate_themes_header);

# This action will render the backup/restore page
sub index {
    my $self = shift;

    $self->render(
        template => "backup",
        title    => $self->LRR_CONF->get_htmltitle,
        descstr  => $self->LRR_DESC,
        csshead  => generate_themes_header($self),
        version  => $self->LRR_VERSION
    );
}

1;
