package LANraragi::Controller::Index;
use Mojo::Base 'Mojolicious::Controller';

use utf8;
use URI::Escape;
use Redis;
use Encode;
use File::Basename;
use Authen::Passphrase;

use LANraragi::Utils::Generic qw(generate_themes_selector generate_themes_header);

sub random_archive {
    my $self          = shift;
    my $archive       = "";
    my $archiveexists = 0;

    my $redis = $self->LRR_CONF->get_redis();

    # We get a random archive ID.
    # We check for the length to (sort-of) avoid not getting an archive ID.
    # TODO: This will loop infinitely if there are zero archives in store.
    until ($archiveexists) {
        $archive = $redis->randomkey();

        $self->LRR_LOGGER->debug("Found key $archive");

        #We got a key, but does the matching archive still exist on the server?
        if (   length($archive) == 40
            && $redis->type($archive) eq "hash"
            && $redis->hexists( $archive, "file" ) ) {
            my $arclocation = $redis->hget( $archive, "file" );
            if ( -e $arclocation ) { $archiveexists = 1; }
        }
    }

    $redis->quit();

    #We redirect to the reader, with the key as parameter.
    $self->redirect_to( '/reader?id=' . $archive );
}

# Render the index template with a few prefilled arguments.
# Most of the work is done in JS these days.
sub index {

    my $self = shift;

    #Checking if the user still has the default password enabled
    my $ppr       = Authen::Passphrase->from_rfc2307( $self->LRR_CONF->get_password );
    my $passcheck = ( $ppr->match("kamimamita") && $self->LRR_CONF->enable_pass );

    my $userlogged = $self->LRR_CONF->enable_pass == 0 || $self->session('is_logged');

    # Get static category list to populate the right-click menu
    my @categories = LANraragi::Model::Category::get_category_list;
    @categories = grep { %$_{"search"} eq "" } @categories;

    $self->render(
        template     => "index",
        version      => $self->LRR_VERSION,
        title        => $self->LRR_CONF->get_htmltitle,
        pagesize     => $self->LRR_CONF->get_pagesize,
        userlogged   => $userlogged,
        categories   => \@categories,
        motd         => $self->LRR_CONF->get_motd,
        cssdrop      => generate_themes_selector,
        csshead      => generate_themes_header($self),
        usingdefpass => $passcheck,
        debugmode    => $self->app->mode eq "development"
    );
}

1;
