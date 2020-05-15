package LANraragi::Controller::Api::Database;
use Mojo::Base 'Mojolicious::Controller';

use Redis;

use LANraragi::Model::Backup;
use LANraragi::Model::Stats;
use LANraragi::Utils::Generic qw(success);
use LANraragi::Utils::Database qw(invalidate_cache);

sub serve_backup {
    my $self = shift;
    $self->render( json => from_json(LANraragi::Model::Backup::build_backup_JSON) );
}

sub drop_database {
    LANraragi::Utils::Database::drop_database();
    success( shift, "drop_database" );
}

sub serve_tag_stats {
    my $self = shift;
    $self->render( json => from_json(LANraragi::Model::Stats::build_tag_json) );
}

sub clean_database {
    my $num = LANraragi::Utils::Database::clean_database();

    shift->render(
        json => {
            operation => "clean_database",
            total     => $num,
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
    invalidate_cache();
    $redis->quit();
    success( $self, "clear_new_all" );
}

1;

