package LANraragi::Controller::Favorite;
use Mojo::Base 'Mojolicious::Controller';

use utf8;
use URI::Escape;
use Redis;
use Encode;
use File::Basename;
use Authen::Passphrase;

use LANraragi::Utils::Generic;
use LANraragi::Utils::Archive;
use LANraragi::Utils::Database;

use LANraragi::Model::Config;

# Go through the archives in the content directory and build the template at the end.
sub index {

    my $self  = shift;
    my $redis = $self->LRR_CONF->get_redis();
    my $force = 0;

    #Checking if the user still has the default password enabled
    my $ppr = Authen::Passphrase->from_rfc2307( $self->LRR_CONF->get_password );
    my $passcheck =
      ( $ppr->match("kamimamita") && $self->LRR_CONF->enable_pass );

    my $userlogged =
      $self->LRR_CONF->enable_pass == 0 || $self->session('is_logged');

    #Read favtags if there are any and craft an array to use in templating
    my @validFavs;

    for ( my $i = 1 ; $i < 6 ; $i++ ) {
        my $favTag = $self->LRR_CONF->get_favtag($i);

        if ( $favTag ne "" ) {
            push @validFavs, $favTag;
        }
    }

    $redis->quit();

    $self->render(
        template        => "favorite",
        version         => $self->LRR_VERSION,
        title           => $self->LRR_CONF->get_htmltitle,
        pagesize        => $self->LRR_CONF->get_pagesize,
        userlogged      => $userlogged,
        motd            => $self->LRR_CONF->get_motd,
        cssdrop         => LANraragi::Utils::Generic::generate_themes_selector,
        csshead         => LANraragi::Utils::Generic::generate_themes_header($self),
        favtags         => \@validFavs,
        usingdefpass    => $passcheck,
        debugmode       => $self->app->mode eq "development"
    );
}

1;
