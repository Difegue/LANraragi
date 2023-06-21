package LANraragi::Controller::Readinggroup;
use Mojo::Base 'Mojolicious::Controller';

use utf8;
use URI::Escape;
use Redis;
use Encode;
use Mojo::Util qw(xml_escape);

use LANraragi::Utils::Generic qw(generate_themes_header);
use LANraragi::Utils::Database qw(redis_decode);

# Go through the archives in the content directory and build the template at the end.
sub index {

    my $self  = shift;
    my $redis = $self->LRR_CONF->get_redis;
    my $force = 0;

    my $userlogged = $self->LRR_CONF->enable_pass == 0 || $self->session('is_logged');

    $redis->quit();

    $self->render(
        template => "rgroups",
        title    => $self->LRR_CONF->get_htmltitle,
        descstr  => $self->LRR_DESC,
        csshead  => generate_themes_header($self),
        version  => $self->LRR_VERSION
    );
}

1;