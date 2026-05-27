package LANraragi::Controller::Edit;
use Mojo::Base 'Mojolicious::Controller';

use File::Basename;
use Redis;
use Encode;
use Template;
use Mojo::Util qw(xml_escape);

use LANraragi::Utils::Generic qw(generate_themes_header);
use LANraragi::Utils::Redis   qw(redis_decode);
use LANraragi::Utils::Plugins qw(get_plugins);
use LANraragi::Model::Tankoubon;

sub index {
    my $self = shift;

    # Does the passed file exist in the database?
    my $id = $self->req->param('id');

    # Tankoubon IDs follow the pattern TANK_\d{10}
    if ( $id && $id =~ /^TANK_/ ) {
        return $self->edit_tankoubon($id);
    }

    my $redis = $self->LRR_CONF->get_redis;

    if ( $redis->exists($id) ) {
        my %hash = $redis->hgetall($id);

        my ( $name, $title, $tags, $summary, $file, $thumbhash ) = @hash{qw(name title tags summary file thumbhash)};

        ( $_ = redis_decode($_) ) for ( $name, $title, $tags, $summary );

        #Build plugin listing
        my @pluginlist = get_plugins("metadata");

        $redis->quit();

        $self->render(
            template  => "edit",
            id        => $id,
            name      => $name,
            arctitle  => xml_escape($title),
            tags      => xml_escape($tags),
            summary   => xml_escape($summary),
            file      => decode_utf8($file),
            thumbhash => $thumbhash,
            plugins   => \@pluginlist,
            is_tank   => 0,
            title     => $self->LRR_CONF->get_htmltitle,
            descstr   => $self->LRR_DESC,
            csshead   => generate_themes_header($self),
            version   => $self->LRR_VERSION
        );
    } else {
        $self->redirect_to('index');
    }
}

sub edit_tankoubon {
    my ( $self, $id ) = @_;

    my %metadata = LANraragi::Model::Tankoubon::fetch_metadata_fields($id);

    unless (%metadata) {
        $self->redirect_to('index');
        return;
    }

    my ( $total, $filtered, %tank ) = LANraragi::Model::Tankoubon::get_tankoubon( $id, 1 );
    my @archives   = @{ $tank{archives}  // [] };
    my @full_data  = @{ $tank{full_data} // [] };

    my $name    = $metadata{name}    // "";
    my $tags    = $metadata{tags}    // "";
    my $summary = $metadata{summary} // "";

    $self->render(
        template      => "edit",
        id            => $id,
        arctitle      => xml_escape($name),
        tags          => xml_escape($tags),
        summary       => xml_escape($summary),
        is_tank       => 1,
        archives      => \@archives,
        archive_data  => \@full_data,
        title         => $self->LRR_CONF->get_htmltitle,
        descstr       => $self->LRR_DESC,
        csshead       => generate_themes_header($self),
        version       => $self->LRR_VERSION
    );
}

1;
