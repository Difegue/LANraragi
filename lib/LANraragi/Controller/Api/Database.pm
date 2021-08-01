package LANraragi::Controller::Api::Database;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Mojo::JSON qw(decode_json);

use LANraragi::Model::Backup;
use LANraragi::Model::Stats;
use LANraragi::Utils::Generic qw(render_api_response);
use LANraragi::Utils::Database qw(invalidate_cache);

sub serve_backup {
    my $self = shift;
    $self->render( json => decode_json(LANraragi::Model::Backup::build_backup_JSON) );
}

sub drop_database {
    LANraragi::Utils::Database::drop_database();
    render_api_response( shift, "drop_database" );
}

sub serve_tag_stats {
    my $self = shift;
    $self->render( json => decode_json(LANraragi::Model::Stats::build_tag_json) );
}

sub clean_database {
    my ( $deleted, $unlinked ) = LANraragi::Utils::Database::clean_database;

    #Force a refresh
    invalidate_cache(1);

    shift->render(
        json => {
            operation => "clean_database",
            deleted   => $deleted,
            unlinked  => $unlinked,
            success   => 1
        }
    );
}

#Clear new flag in all archives.
sub clear_new_all {

    my $self  = shift;
    my $redis = $self->LRR_CONF->get_redis();

    # Get all archives thru redis
    # 40-character long keys only => Archive IDs
    my @keys = $redis->keys('????????????????????????????????????????');

    foreach my $idall (@keys) {
        $redis->hset( $idall, "isnew", "false" );
    }

    # Bust search cache completely, this is a big change
    invalidate_cache(1);
    $redis->quit();
    render_api_response( $self, "clear_new_all" );
}

1;

