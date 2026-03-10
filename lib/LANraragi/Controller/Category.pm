package LANraragi::Controller::Category;
use Mojo::Base 'Mojolicious::Controller';

use utf8;
use URI::Escape;
use Redis;
use Encode;
use Mojo::Util qw(xml_escape);

use LANraragi::Model::Tankoubon;
use LANraragi::Utils::Generic qw(generate_themes_header);
use LANraragi::Utils::Redis   qw(redis_decode);

# Go through the archives in the content directory and build the template at the end.
sub index {

    my $self  = shift;
    my $redis = $self->LRR_CONF->get_redis;
    my $force = 0;

    my $userlogged = $self->LRR_CONF->enable_pass == 0 || $self->session('is_logged');

    $redis->quit();

    # Build archive list
    my @idlist  = LANraragi::Model::Archive::generate_archive_list;
    my $arclist = "";

    # Only show IDs that still have their files present.
    foreach my $arc (@idlist) {
        my $title = xml_escape( $arc->{title} );
        my $id    = xml_escape( $arc->{arcid} );

        $arclist .=
          "<li><input type='checkbox' name='archive' id='$id' class='archive' onchange='Category.updateArchiveInCategory(this.id, this.checked)'>";
        $arclist .= "<label for='$id'> $title</label></li>";
    }

    # Build tankoubon list
    my ( $total, $filtered, @tanklist_data ) = LANraragi::Model::Tankoubon::get_tankoubon_list(-1);
    my $tanklist = "";

    foreach my $tank (@tanklist_data) {
        my $title = xml_escape( $tank->{name} );
        my $id    = xml_escape( $tank->{id} );

        $tanklist .=
          "<li><input type='checkbox' name='tankoubon' id='$id' class='tankoubon' onchange='Category.updateArchiveInCategory(this.id, this.checked)'>";
        $tanklist .= "<label for='$id'> $title</label></li>";
    }

    $self->render(
        template => "category",
        arclist  => $arclist,
        tanklist => $tanklist,
        title    => $self->LRR_CONF->get_htmltitle,
        descstr  => $self->LRR_DESC,
        csshead  => generate_themes_header($self),
        version  => $self->LRR_VERSION
    );
}

1;
