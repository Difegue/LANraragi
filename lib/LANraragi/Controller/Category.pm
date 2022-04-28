package LANraragi::Controller::Category;
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
    my $redis = $self->LRR_CONF->get_redis();
    my $force = 0;

    my $userlogged = $self->LRR_CONF->enable_pass == 0 || $self->session('is_logged');

    $redis->quit();

    #Then complete it with the rest from the database.
    #40-character long keys only => Archive IDs
    my @keys = $redis->keys('????????????????????????????????????????');

    #Parse the archive list and build <li> elements accordingly.
    my $arclist = "";

    #Only show IDs that still have their files present.
    foreach my $id (@keys) {
        my $zipfile = $redis->hget( $id, "file" );
        my $title   = $redis->hget( $id, "title" );
        $title = redis_decode($title);
        $title = xml_escape($title);

        if ( -e $zipfile ) {
            $arclist .=
              "<li><input type='checkbox' name='archive' id='$id' class='archive' onchange='Category.updateArchiveInCategory(this.id, this.checked)'>";
            $arclist .= "<label for='$id'> $title</label></li>";
        }
    }

    $redis->quit();

    $self->render(
        template => "category",
        arclist  => $arclist,
        title    => $self->LRR_CONF->get_htmltitle,
        descstr  => $self->LRR_DESC,
        csshead  => generate_themes_header($self),
        version  => $self->LRR_VERSION
    );
}

1;
