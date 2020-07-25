package LANraragi::Controller::Edit;
use Mojo::Base 'Mojolicious::Controller';

use File::Basename;
use Redis;
use Encode;
use Template;
use Mojo::Util qw(xml_escape);

use LANraragi::Utils::Generic qw(generate_themes_selector generate_themes_header);
use LANraragi::Utils::Database qw(redis_decode);
use LANraragi::Utils::Plugins qw(get_plugins);

sub delete_archive {
    my $self = shift;
    my $id   = $self->req->param('id');

    my $delStatus = LANraragi::Utils::Database::delete_archive($id);

    $self->render(
        json => {
            id        => $id,
            operation => "delete",
            success   => $delStatus
        }
    );
}

sub index {
    my $self = shift;

    #Does the passed file exist in the database?
    my $id = $self->req->param('id');

    my $redis = $self->LRR_CONF->get_redis();

    if ( $redis->exists($id) ) {
        my %hash = $redis->hgetall($id);

        my ( $name, $title, $tags, $file, $thumbhash ) = @hash{qw(name title tags file thumbhash)};

        ( $_ = redis_decode($_) ) for ( $name, $title, $tags );

        #Build plugin listing
        my @pluginlist = get_plugins("metadata");

        $redis->quit();

        $self->render(
            template  => "edit",
            id        => $id,
            name      => $name,
            arctitle  => xml_escape($title),
            tags      => xml_escape($tags),
            file      => decode_utf8($file),
            thumbhash => $thumbhash,
            plugins   => \@pluginlist,
            title     => $self->LRR_CONF->get_htmltitle,
            cssdrop   => generate_themes_selector,
            csshead   => generate_themes_header($self),
            version   => $self->LRR_VERSION
        );
    } else {
        $self->redirect_to('index');
    }
}

1;
