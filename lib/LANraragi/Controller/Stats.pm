package LANraragi::Controller::Stats;
use Mojo::Base 'Mojolicious::Controller';

use LANraragi::Model::Stats;
use LANraragi::Utils::Generic qw(generate_themes_selector generate_themes_header);

# This action will render a template
sub index {
    my $self = shift;

    $self->render(
        template     => "stats",
        title        => $self->LRR_CONF->get_htmltitle,
        descstr      => $self->LRR_DESC,
        cssdrop      => generate_themes_selector,
        csshead      => generate_themes_header($self),
        archivecount => LANraragi::Model::Stats::get_archive_count,
        arcsize      => LANraragi::Model::Stats::compute_content_size,
        pagestat     => LANraragi::Model::Stats::get_page_stat,
        version      => $self->LRR_VERSION
    );
}

1;
