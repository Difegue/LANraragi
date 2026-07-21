package LANraragi::Controller::Api::Database;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Mojo::JSON qw(decode_json);
use File::Temp qw(tempfile);

use LANraragi::Model::Backup;
use LANraragi::Model::Stats;
use LANraragi::Utils::Generic    qw(render_api_response);
use LANraragi::Utils::Database   qw(invalidate_cache);
use LANraragi::Utils::TempFolder qw(get_temp);

sub serve_backup {
    my $self = shift->openapi->valid_input or return;
    $self->render( openapi => decode_json(LANraragi::Model::Backup::build_backup_JSON) );
}

sub queue_backup {
    my $self = shift->openapi->valid_input or return;

    # Enqueue backup_json Minion job
    my $jobid = $self->minion->enqueue( backup_json => [] => { priority => 0 } );

    $self->render(
        openapi => {
            operation => "queue_backup",
            success   => 1,
            job       => $jobid
        }
    );
}

sub download_backup {
    my $self  = shift->openapi->valid_input or return;
    my $jobid = $self->stash('jobid');
    my $job   = $self->minion->job($jobid);

    if ( !$job ) {
        return $self->render(
            openapi => {
                operation => "download_backup",
                success   => 0,
                error     => "Job not found"
            },
            status => 400
        );
    }

    my $info = $job->info;

    if ( $info->{state} ne "finished" ) {
        return $self->render(
            openapi => {
                operation => "download_backup",
                success   => 0,
                error     => "Job not completed yet (state: " . $info->{state} . ")"
            },
            status => 400
        );
    }

    my $result = $info->{result};
    if ( !$result->{success} || !$result->{path} ) {
        return $self->render(
            openapi => {
                operation => "download_backup",
                success   => 0,
                error     => "Backup file not available"
            },
            status => 400
        );
    }

    my $filepath = $result->{path};
    if ( !-e $filepath ) {
        return $self->render(
            openapi => {
                operation => "download_backup",
                success   => 0,
                error     => "Backup file not found on disk"
            },
            status => 400
        );
    }

    # Depending on the requested format, either serve the file directly or read its contents and return as JSON
    if ( $self->req->param('format') && $self->req->param('format') eq 'json' ) {
        open my $fh, '<', $filepath or die "Cannot read $filepath: $!";
        local $/;
        my $json = <$fh>;
        close $fh;

        $self->render( openapi => decode_json($json) );
    } else {
        my $filename = $result->{filename} || "backup.json";
        return $self->render_file( filepath => $filepath, filename => $filename );
    }

}

sub queue_restore {
    my $self = shift->openapi->valid_input or return;

    # Get uploaded file
    my $file = $self->req->upload('file');

    if ( !$file ) {
        return $self->render(
            openapi => {
                operation => "queue_restore",
                success   => 0,
                error     => "No file provided"
            },
            status => 400
        );
    }

    if ( $file->headers->content_type ne "application/json" ) {
        return $self->render(
            openapi => {
                operation => "queue_restore",
                success   => 0,
                error     => "File must be JSON"
            },
            status => 400
        );
    }

    # Read file content
    my $json_data = $file->slurp;

    # Enqueue restore_backup Minion job
    my $jobid = $self->minion->enqueue( restore_backup => [$json_data] => { priority => 0 } );

    $self->render(
        openapi => {
            operation => "queue_restore",
            success   => 1,
            job       => $jobid
        }
    );
}

sub drop_database {
    my $self = shift->openapi->valid_input or return;
    LANraragi::Utils::Database::drop_database();

    # Force a refresh
    invalidate_cache(1);

    render_api_response( $self, "drop_database" );
}

sub serve_tag_stats {
    my $self          = shift->openapi->valid_input or return;
    my $minscore      = $self->req->param('minweight')                || "1";
    my $hide_excluded = $self->req->param('hide_excluded_namespaces') || "0";

    my @excluded;
    if ( $hide_excluded eq "true" ) {
        @excluded = split( /\s*,\s*/, $self->LRR_CONF->get_excludednamespaces );
    }

    $self->render( openapi => LANraragi::Model::Stats::build_tag_stats( $minscore, \@excluded ) );
}

sub clean_database {
    my $self = shift->openapi->valid_input or return;
    my ( $deleted, $unlinked ) = LANraragi::Utils::Database::clean_database;

    # Force a refresh
    invalidate_cache(1);

    $self->render(
        openapi => {
            operation => "clean_database",
            deleted   => $deleted,
            unlinked  => $unlinked,
            success   => 1
        }
    );
}

#Clear new flag in all archives.
sub clear_new_all {

    my $self         = shift->openapi->valid_input or return;
    my $redis        = $self->LRR_CONF->get_redis;
    my $redis_search = $self->LRR_CONF->get_redis_search;

    # Get all archives thru redis
    # 40-character long keys only => Archive IDs
    my @keys = $redis->keys('????????????????????????????????????????');

    foreach my $idall (@keys) {
        $redis->hset( $idall, "isnew", "false" );
    }

    $redis->quit();

    # Bust isnew cache
    $redis_search->del("LRR_NEW");
    $redis_search->quit();

    render_api_response( $self, "clear_new_all" );
}

1;

