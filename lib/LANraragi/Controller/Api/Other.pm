package LANraragi::Controller::Api::Other;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON qw(encode_json decode_json);
use Redis;

use LANraragi::Model::Stats;
use LANraragi::Utils::TempFolder qw(get_tempsize clean_temp_full);
use LANraragi::Utils::Generic qw(render_api_response);
use LANraragi::Utils::Plugins qw(get_plugin get_plugins get_plugin_parameters use_plugin);

sub serve_serverinfo {
    my $self = shift;

    my $redis      = $self->LRR_CONF->get_redis;
    my $last_clear = $redis->hget( "LRR_SEARCHCACHE", "created" ) || time;
    my $page_stat  = LANraragi::Model::Stats::get_page_stat;
    $redis->quit();

    # A simple endpoint that forwards some info from LRR_CONF.
    $self->render(
        json => {
            name                   => $self->LRR_CONF->get_htmltitle,
            motd                   => $self->LRR_CONF->get_motd,
            version                => $self->LRR_VERSION,
            version_name           => $self->LRR_VERNAME,
            version_desc           => $self->LRR_DESC,
            has_password           => $self->LRR_CONF->enable_pass,
            debug_mode             => $self->LRR_CONF->enable_devmode,
            nofun_mode             => $self->LRR_CONF->enable_nofun,
            archives_per_page      => $self->LRR_CONF->get_pagesize,
            server_resizes_images  => $self->LRR_CONF->enable_resize,
            server_tracks_progress => !$self->LRR_CONF->enable_localprogress . "",    # bad hack to force string type
            total_pages_read       => $page_stat,
            cache_last_cleared     => "$last_clear"
        }
    );
}

sub serve_opds {
    my $self = shift;

    # TODO: Move to LRR::Model::Opds
    $self->render( text => LANraragi::Model::Archive::generate_opds_catalog($self), format => 'xml' );
}

#Remove temp dir.
sub clean_tempfolder {
    my $self = shift;

    #Run a full clean, errors are dumped into $@ if they occur
    eval { clean_temp_full() };

    $self->render(
        json => {
            operation => "cleantemp",
            success   => $@ eq "",
            error     => $@,
            newsize   => get_tempsize()
        }
    );
}

# List all plugins of the given type.
sub list_plugins {
    my $self = shift;
    my $type = $self->stash('type');

    my @plugins = get_plugins($type);
    $self->render( json => \@plugins );
}

# Returns the info for the given Minion job id.
sub minion_job_status {
    my $self = shift;
    my $id   = $self->stash('jobid');

    my $job = $self->minion->job($id);

    if ($job) {
        $self->render( json => $job->info );
    } else {
        render_api_response( $self, "minion_job_status", "No job with this ID." );
    }
}

# Queue the regen_all_thumbnails Minion job.
sub regen_thumbnails {
    my $self     = shift;
    my $thumbdir = LANraragi::Model::Config->get_thumbdir;
    my $force    = ( $self->req->param('force') && $self->req->param('force') ne "false" ) ? 1 : 0;

    my $jobid = $self->minion->enqueue( regen_all_thumbnails => [ $thumbdir, $force ] => { priority => 0 } );

    $self->render(
        json => {
            operation => "regen_thumbnails",
            success   => 1,
            job       => $jobid
        }
    );
}

sub download_url {

    my ($self) = shift;
    my $url    = $self->req->param('url');
    my $catid  = $self->req->param('catid');

    if ($url) {

        # Send a job to Minion to queue the download.
        my $jobid = $self->minion->enqueue( download_url => [ $url, $catid ] => { priority => 1, attempts => 5 } );

        $self->render(
            json => {
                operation => "download_url",
                url       => $url,
                category  => $catid,
                success   => 1,
                job       => $jobid
            }
        );

    } else {
        render_api_response( $self, "download_url", "No URL specified." );
    }

}

# Uses a plugin, with the standard global arguments and a provided oneshot argument.
sub use_plugin_sync {

    my ($self)   = shift;
    my $id       = $self->req->param('id') || 0;
    my $plugname = $self->req->param('plugin');
    my $input    = $self->req->param('arg');

    my ( $pluginfo, $plugin_result ) = use_plugin( $plugname, $id, $input );

    #Returns the fetched tags in a JSON response.
    $self->render(
        json => {
            operation => "use_plugin",
            type      => $pluginfo->{type},
            success   => ( exists $plugin_result->{error} ? 0 : 1 ),
            error     => $plugin_result->{error},
            data      => $plugin_result
        }
    );
    return;
}

# Queues a plugin execution into Minion.
sub use_plugin_async {

    my ($self) = shift;
    my $id       = $self->req->param('id')       || 0;
    my $priority = $self->req->param('priority') || 0;
    my $plugname = $self->req->param('plugin');
    my $input    = $self->req->param('arg');

    my $jobid = $self->minion->enqueue( run_plugin => [ $plugname, $id, $input ] => { priority => $priority } );

    $self->render(
        json => {
            operation => "queue_plugin_exec",
            success   => 1,
            job       => $jobid
        }
    );
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

