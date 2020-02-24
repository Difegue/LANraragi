package LANraragi::Controller::Edit;
use Mojo::Base 'Mojolicious::Controller';

use File::Basename;
use Redis;
use Encode;
use Template;

use LANraragi::Utils::Generic qw(generate_themes_selector generate_themes_header remove_spaces remove_newlines);
use LANraragi::Utils::Database qw(redis_decode invalidate_cache);
use LANraragi::Utils::Plugins qw(get_plugins);

sub save_metadata {
    my $self = shift;

    my $id    = $self->req->param('id');
    my $title = $self->req->param('title');
    my $tags  = $self->req->param('tags');

    #clean up the user's inputs and encode them.
    ( remove_spaces($_) )   for ( $title, $tags );
    ( remove_newlines($_) ) for ( $title, $tags );

    #Input new values into redis hash.
    #prepare the hash which'll be inserted.
    my %hash = (
        title => encode_utf8($title),
        tags  => encode_utf8($tags)
    );

    my $redis = $self->LRR_CONF->get_redis();

    # For all keys of the hash, add them to the redis hash $id with the matching keys.
    $redis->hset( $id, $_, $hash{$_}, sub { } ) for keys %hash;
    $redis->wait_all_responses;
    $redis->quit();

    #Trigger a JSON rebuild.
    invalidate_cache();

    $self->render(
        json => {
            id        => $id,
            operation => "edit",
            success   => 1
        }
    );
}

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

        my ( $name, $title, $tags, $file, $thumbhash ) =
          @hash{qw(name title tags file thumbhash)};

        ( $_ = redis_decode($_) )
          for ( $name, $title, $tags );

        #Build plugin listing
        my @pluginlist = get_plugins("metadata");

        $redis->quit();

        $self->render(
            template  => "edit",
            id        => $id,
            name      => $name,
            arctitle  => $title,
            tags      => $tags,
            file      => decode_utf8($file),
            thumbhash => $thumbhash,
            plugins   => \@pluginlist,
            title     => $self->LRR_CONF->get_htmltitle,
            cssdrop   => generate_themes_selector,
            csshead   => generate_themes_header($self),
            version   => $self->LRR_VERSION
        );
    }
    else { $self->redirect_to('index') }
}

1;
