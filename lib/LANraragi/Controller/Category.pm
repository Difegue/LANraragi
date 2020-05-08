package LANraragi::Controller::Category;
use Mojo::Base 'Mojolicious::Controller';

use utf8;
use URI::Escape;
use Redis;
use Encode;

use LANraragi::Utils::Generic qw(generate_themes_selector generate_themes_header);

# Go through the archives in the content directory and build the template at the end.
sub index {

    my $self  = shift;
    my $redis = $self->LRR_CONF->get_redis();
    my $force = 0;

    my $userlogged = $self->LRR_CONF->enable_pass == 0 || $self->session('is_logged');

    $redis->quit();

    $self->render(
        template => "category",
        title    => $self->LRR_CONF->get_htmltitle,
        cssdrop  => generate_themes_selector,
        csshead  => generate_themes_header($self)
    );
}

1;
