package LANraragi::Controller::Api::Other;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON qw(encode_json decode_json);
use Redis;

use LANraragi::Model::Stats;
use LANraragi::Model::Opds;
use LANraragi::Model::Server     qw(is_restart_pending);
use LANraragi::Utils::Generic    qw(render_api_response);
use LANraragi::Utils::Logging    qw(get_logger);
use LANraragi::Utils::Plugins    qw(get_plugin get_plugins use_plugin);

sub serve_serverinfo {
    my $self = shift;

    my $redis      = $self->LRR_CONF->get_redis_config;
    my $last_clear = $redis->hget( "LRR_SEARCHCACHE", "created" ) || time;
    my $restart    = is_restart_pending($redis);
    my $arc_stat   = LANraragi::Model::Stats::get_archive_count;
    my $page_stat  = LANraragi::Model::Stats::get_page_stat;
    $redis->quit();

    # A simple endpoint that forwards some info from LRR_CONF.
    $self->render(
        json => {
            name         => $self->LRR_CONF->get_htmltitle,
            motd         => $self->LRR_CONF->get_motd,
            version      => $self->LRR_VERSION,
            version_name => $self->LRR_VERNAME,
            version_desc => $self->LRR_DESC,
            has_password => $self->LRR_CONF->enable_pass    ? \1 : \0,
            debug_mode   => $self->LRR_CONF->enable_devmode ? \1 : \0,
            ,
            nofun_mode => $self->LRR_CONF->enable_nofun ? \1 : \0,
            ,
            archives_per_page     => $self->LRR_CONF->get_pagesize + 0,
            server_resizes_images => $self->LRR_CONF->enable_resize ? \1 : \0,
            ,
            server_tracks_progress => $self->LRR_CONF->enable_localprogress ? \0 : \1,
            authenticated_progress => $self->LRR_CONF->enable_authprogress ? \1 : \0,
            total_pages_read       => $page_stat,
            total_archives         => $arc_stat,
            cache_last_cleared     => $last_clear,
            restart_required       => $restart ? \1 : \0,
            excluded_namespaces    => [
                split( /\s*,\s*/, $self->LRR_CONF->get_excludednamespaces )
            ]
        }
    );
}

# Basic OPDS catalog
sub serve_opds_catalog {
    my $self = shift->openapi->valid_input or return;
    $self->render( text => LANraragi::Model::Opds::generate_opds_catalog($self), format => 'xml' );
}

sub serve_opds_item {
    my $self = shift->openapi->valid_input or return;
    my $id   = $self->stash('id');
    $self->render( text => LANraragi::Model::Opds::generate_opds_item( $self, $id ), format => 'xml' );
}

# OPDS-PSE specific endpoint
sub serve_opds_page {
    my $self = shift->openapi->valid_input or return;
    my $id   = $self->stash('id');
    my $page = $self->req->param('page') || 1;

    LANraragi::Model::Opds::render_archive_page( $self, $id, $page );
}

#Remove temp dir.
sub clean_tempfolder {
    my $self = shift->openapi->valid_input or return;

    #Run a full clean, errors are dumped into $@ if they occur
    eval { LANraragi::Utils::PageCache::clear(); };

    $self->render(
        openapi => {
            operation => "cleantemp",
            success   => $@ eq "",
            error     => $@,
            newsize   => 0,
        }
    );
}

# List all plugins of the given type.
sub list_plugins {
    my $self = shift->openapi->valid_input or return;
    my $type = $self->stash('type');

    my @plugins = get_plugins($type);
    my $redis   = $self->LRR_CONF->get_redis_config;
    my $logger  = get_logger( "Plugins", "lanraragi" );

    foreach my $plugin (@plugins) {
        if ( ref( $plugin->{parameters} ) eq 'HASH' ) {
            my @parameters_array;
            while ( my ( $name, $value ) = each %{ $plugin->{parameters} } ) {
                push @parameters_array, { %{$value}, 'name' => $name };
            }
            $plugin->{parameters} = \@parameters_array;
        }

        my $namerds         = "LRR_PLUGIN_" . uc( $plugin->{namespace} );
        $plugin->{registry} = $redis->hget( $namerds, "installed_registry" );
        $plugin->{sha256}   = $redis->hget( $namerds, "installed_sha256" );

        # Usually installed_version shouldn't be different from version.
        my $installed_version   = $redis->hget( $namerds, "installed_version" );
        my $plugin_version      = $plugin->{version};
        if ( defined $installed_version && $installed_version ne $plugin_version ) {
            $logger->warn(
                "Plugin $plugin installed_version='$installed_version' but plugin->version='$plugin_version'"
            );
        }
    }

    $redis->quit();
    $self->render( openapi => \@plugins );
}

# Queue the regen_all_thumbnails Minion job.
sub regen_thumbnails {
    my $self     = shift->openapi->valid_input or return;
    my $thumbdir = LANraragi::Model::Config->get_thumbdir;
    my $force    = ( $self->req->param('force') && $self->req->param('force') ne "false" ) ? 1 : 0;

    my $jobid = $self->minion->enqueue( regen_all_thumbnails => [ $thumbdir, $force ] => { priority => 0 } );

    $self->render(
        openapi => {
            operation => "regen_thumbnails",
            success   => 1,
            job       => $jobid
        }
    );
}

sub download_url {
    my ($self) = shift->openapi->valid_input or return;
    my $url    = $self->req->param('url');
    my $catid  = $self->req->param('catid');

    if ($url) {

        # Send a job to Minion to queue the download.
        my $jobid = $self->minion->enqueue( download_url => [ $url, $catid ] => { priority => 1, attempts => 5 } );

        $self->render(
            openapi => {
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
    my ($self)   = shift->openapi->valid_input or return;
    my $id       = $self->req->param('id') || 0;
    my $plugname = $self->req->param('plugin');
    my $input    = $self->req->param('arg');

    my ( $pluginfo, $plugin_result ) = use_plugin( $plugname, $id, $input );

    #Returns the fetched tags in a JSON response.
    my %response = (
        operation => "use_plugin",
        success   => ( exists $plugin_result->{error} ? 0 : 1 ),
        error     => $plugin_result->{error},
        data      => $plugin_result,
    );
    $response{type} = $pluginfo->{type} if defined $pluginfo->{type};
    $self->render( openapi => \%response );
    return;
}

# Queues a plugin execution into Minion.
sub use_plugin_async {
    my ($self)   = shift->openapi->valid_input or return;
    my $id       = $self->req->param('id')       || 0;
    my $priority = $self->req->param('priority') || 0;
    my $plugname = $self->req->param('plugin');
    my $input    = $self->req->param('arg');

    my $jobid = $self->minion->enqueue( run_plugin => [ $plugname, $id, $input ] => { priority => $priority } );

    $self->render(
        openapi => {
            operation => "queue_plugin_exec",
            success   => 1,
            job       => $jobid
        }
    );
}

1;

