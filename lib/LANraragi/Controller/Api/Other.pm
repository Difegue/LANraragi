package LANraragi::Controller::Api::Other;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON qw(encode_json);
use Redis;

use LANraragi::Utils::TempFolder qw(get_tempsize clean_temp_full);
use LANraragi::Utils::Generic qw(render_api_response);
use LANraragi::Utils::Plugins qw(get_plugin get_plugins get_plugin_parameters);

sub serve_serverinfo {
    my $self = shift;

    # A simple endpoint that forwards some info from LRR_CONF.
    $self->render(
        json => {
            name                  => $self->LRR_CONF->get_htmltitle,
            motd                  => $self->LRR_CONF->get_motd,
            version               => $self->LRR_VERSION,
            version_name          => $self->LRR_VERNAME,
            has_password          => $self->LRR_CONF->enable_pass,
            debug_mode            => $self->LRR_CONF->enable_devmode,
            nofun_mode            => $self->LRR_CONF->enable_nofun,
            archives_per_page     => $self->LRR_CONF->get_pagesize,
            server_resizes_images => $self->LRR_CONF->enable_resize
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

# Uses a plugin, with the standard global arguments and a provided oneshot argument.
sub use_plugin {

    my ($self)   = shift;
    my $id       = $self->req->param('id') || 0;
    my $plugname = $self->req->param('plugin');
    my $input    = $self->req->param('arg');

    my $plugin = get_plugin($plugname);
    my %plugin_result;
    my %pluginfo;

    if ( !$plugin ) {
        $plugin_result{error} = "Plugin not found on system.";
    } else {
        %pluginfo = $plugin->plugin_info();

        #Get the plugin settings in Redis
        my @settings = get_plugin_parameters($plugname);

        #Execute the plugin, appending the custom args at the end
        if ( $pluginfo{type} eq "script" ) {
            eval { %plugin_result = LANraragi::Model::Plugins::exec_script_plugin( $plugin, $input, @settings ); };
        }

        if ( $pluginfo{type} eq "metadata" ) {
            eval { %plugin_result = LANraragi::Model::Plugins::exec_metadata_plugin( $plugin, $id, $input, @settings ); };
        }

        if ( $pluginfo{type} eq "download" ) {

            # TODO queue a minion job here instead
            eval { %plugin_result = LANraragi::Model::Plugins::exec_download_plugin( $plugin, $input, @settings ); };
        }

        if ($@) {
            $plugin_result{error} = $@;
        }
    }

    #Returns the fetched tags in a JSON response.
    $self->render(
        json => {
            operation => "use_plugin",
            type      => $pluginfo{type},
            success   => ( exists $plugin_result{error} ? 0 : 1 ),
            error     => $plugin_result{error},
            data      => \%plugin_result
        }
    );
    return;

}

1;

