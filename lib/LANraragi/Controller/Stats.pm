package LANraragi::Controller::Stats;
use Mojo::Base 'Mojolicious::Controller';

use LANraragi::Model::Stats;

# This action will render a template
sub index {
    my $self = shift;


    $self->render(
        template     => "stats",
        title        => $self->LRR_CONF->get_htmltitle,
        cssdrop      => LANraragi::Utils::Generic::generate_themes_selector,
        csshead      => LANraragi::Utils::Generic::generate_themes_header($self),
        tagcloud     => LANraragi::Model::Stats::build_tag_json,
        archivecount => LANraragi::Model::Stats::get_archive_count,
        arcsize      => LANraragi::Model::Stats::compute_content_size,
        version      => $self->LRR_VERSION
    );
}

1;
