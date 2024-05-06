package LANraragi::Controller::Api::Minion;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON qw(encode_json decode_json);
use Redis;

use LANraragi::Model::Stats;
use LANraragi::Utils::TempFolder qw(get_tempsize clean_temp_full);
use LANraragi::Utils::Generic    qw(render_api_response);
use LANraragi::Utils::Plugins    qw(get_plugin get_plugins get_plugin_parameters use_plugin);

# Returns basic info for the given Minion job id.
sub minion_job_status {
    my $self = shift;
    my $id   = $self->stash('jobid');
    my $job  = $self->minion->job($id);

    if ($job) {

        my %info = %{ $job->info };

        # Render a basic json containing the minion job info
        $self->render(
            json => {
                task  => $info{task},
                state => $info{state},
                notes => $info{notes},
                error => $info{error}
            }
        );

    } else {
        render_api_response( $self, "minion_job_status", "No job with this ID." );
    }
}

# Returns the full info for the given Minion job id.
sub minion_job_detail {
    my $self = shift;
    my $id   = $self->stash('jobid');
    my $job  = $self->minion->job($id);

    if ($job) {
        $self->render( json => $job->info );
    } else {
        render_api_response( $self, "minion_job_detail", "No job with this ID." );
    }
}

# Queues a job into Minion.
sub queue_minion_job {

    my ($self)   = shift;
    my $jobname  = $self->stash('jobname');
    my @jobargs  = decode_json( $self->req->param('args') );
    my $priority = $self->req->param('priority') || 0;

    my $jobid = $self->minion->enqueue( $jobname => @jobargs => { priority => $priority } );

    $self->render(
        json => {
            operation => "queue_minion_job",
            success   => 1,
            job       => $jobid
        }
    );
}

1;

