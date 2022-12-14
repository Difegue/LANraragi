package LANraragi::Controller::Batch;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Encode;
use Mojo::JSON qw(decode_json);

use LANraragi::Utils::Generic qw(generate_themes_header);
use LANraragi::Utils::Tags qw(rewrite_tags split_tags_to_array restore_CRLF);
use LANraragi::Utils::Database qw(get_computed_tagrules set_tags set_title set_isnew invalidate_cache);
use LANraragi::Utils::Plugins qw(get_plugins get_plugin get_plugin_parameters);
use LANraragi::Utils::Logging qw(get_logger);

# This action will render a template
sub index {
    my $self = shift;

    #Build plugin listing
    my @pluginlist = get_plugins("metadata");

    # Get static category list
    my @categories = LANraragi::Model::Category->get_static_category_list;

    $self->render(
        template   => "batch",
        plugins    => \@pluginlist,
        title      => $self->LRR_CONF->get_htmltitle,
        descstr    => $self->LRR_DESC,
        csshead    => generate_themes_header($self),
        tagrules   => restore_CRLF( $self->LRR_CONF->get_tagrules ),
        categories => \@categories,
        version    => $self->LRR_VERSION
    );
}

# Websocket server receiving a list of IDs as a JSON and calling the specified plugin on them.
sub socket {

    my $self      = shift;
    my $cancelled = 0;
    my $client    = $self->tx;
    my $redis     = $self->LRR_CONF->get_redis();

    my $logger = get_logger( "Batch Tagging", "lanraragi" );

    $logger->info('Client connected to Batch Tagging service');

    # Increase inactivity timeout for connection a bit to account for clientside timeouts
    $self->inactivity_timeout(80);

    $self->on(
        message => sub {
            my ( $self, $msg ) = @_;

            # JSON-decode message and perform the requested action
            my $command    = decode_json($msg);
            my $operation  = $command->{'operation'};
            my $pluginname = $command->{"plugin"};
            my $id         = $command->{"archive"};

            unless ($id) {
                $client->finish( 1001 => 'No archives provided.' );
                return;
            }
            $logger->debug("Processing $id");

            if ( $operation eq "plugin" ) {

                my $plugin = get_plugin($pluginname);
                unless ($plugin) {
                    $client->finish( 1001 => 'Plugin not found.' );
                    return;
                }

                # Global arguments can come from the database or the user override
                my @args = @{ $command->{"args"} };

                if ( !@args ) {
                    $logger->debug("No user overrides given.");

                    # Try getting the saved defaults
                    @args = get_plugin_parameters($pluginname);
                }

                # Send reply message for completed archive
                $client->send( { json => batch_plugin( $id, $plugin, @args ) } );
                return;
            }

            if ( $operation eq "clearnew" ) {
                set_isnew( $id, "false" );

                $client->send(
                    {   json => {
                            id      => $id,
                            success => 1,
                        }
                    }
                );
                return;
            }

            if ( $operation eq "addcat" ) {
                my $catid = $command->{"category"};
                my ( $catsucc, $caterr ) = LANraragi::Model::Category::add_to_category( $catid, $id );

                $client->send(
                    {   json => {
                            id       => $id,
                            category => $catid,
                            success  => $catsucc,
                            message  => $caterr
                        }
                    }
                );
                return;
            }

            if ( $operation eq "tagrules" ) {

                $logger->debug("Applying tag rules to $id...");
                my $tags = $redis->hget( $id, "tags" );

                my @tagarray = split_tags_to_array($tags);
                my @rules    = get_computed_tagrules();
                @tagarray = rewrite_tags( \@tagarray, \@rules );

                # Merge array with commas
                my $newtags = join( ', ', @tagarray );
                $logger->debug("New tags: $newtags");
                set_tags( $id, $newtags );

                $client->send(
                    {   json => {
                            id      => $id,
                            success => 1,
                            tags    => $newtags,
                        }
                    }
                );

                invalidate_cache();

                return;
            }

            if ( $operation eq "delete" ) {
                $logger->debug("Deleting $id...");

                my $delStatus = LANraragi::Utils::Database::delete_archive($id);

                $client->send(
                    {   json => {
                            id       => $id,
                            filename => $delStatus,
                            message  => $delStatus ? "Archive deleted." : "Archive not found.",
                            success  => $delStatus ? 1 : 0
                        }
                    }
                );
                return;
            }

            # Unknown operation
            $client->send(
                {   json => {
                        id      => $id,
                        message => "Unknown operation type $operation.",
                        success => 0
                    }
                }
            );
        }
    );

    $self->on(

        # If the client doesn't respond, halt processing
        finish => sub {
            $logger->info('Client disconnected, halting remaining operations');
            $cancelled = 1;
            $redis->quit();
        }
    );

}

sub batch_plugin {
    my ( $id, $plugin, @args ) = @_;

    # Run plugin with args on id
    my %plugin_result;
    eval { %plugin_result = LANraragi::Model::Plugins::exec_metadata_plugin( $plugin, $id, "", @args ); };

    if ($@) {
        $plugin_result{error} = $@;
    }

    # If the plugin exec returned tags, add them
    unless ( exists $plugin_result{error} ) {
        set_tags( $id, $plugin_result{new_tags}, 1 );

        if ( exists $plugin_result{title} ) {
            set_title( $id, $plugin_result{title} );
        }
    }

    return {
        id      => $id,
        success => exists $plugin_result{error} ? 0 : 1,
        message => $plugin_result{error},
        tags    => $plugin_result{new_tags},
        title   => exists $plugin_result{title} ? $plugin_result{title} : ""
    };
}

1;
