package LANraragi::Controller::Batch;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Encode;
use Mojo::IOLoop::Subprocess;
use Mojo::JSON qw(decode_json encode_json from_json);

use LANraragi::Utils::Generic;
use LANraragi::Utils::Database;

use LANraragi::Model::Config;
use LANraragi::Model::Plugins;

# This action will render a template
sub index {
    my $self = shift;
    my $redis   = $self->LRR_CONF->get_redis();

    #Fill a hash with the untagged archives
    #The hash matches IDs to true(no tags) or false(has tags)
    my %untagged = map { $_ => 1 } LANraragi::Utils::Database::find_untagged_archives;

    #Then complete it with the rest from the database.
    #40-character long keys only => Archive IDs
    my @keys = $redis->keys('????????????????????????????????????????');

    foreach my $id (@keys) {
        unless ( exists $untagged{$id} ) {
            my $zipfile = $redis->hget( $id, "file" );
            if (-e $zipfile) {$untagged{$id} = 0;}
        }
    }

    #Parse the archive list and add <li> elements accordingly.
    my $arclist = "";
    for(keys %untagged) {
        my $title = $redis->hget( $_, "title" );
        $title = LANraragi::Utils::Database::redis_decode($title);
        
        #Untagged archives are pre-checked in the list.
        if ($untagged{$_}) {
            $arclist .=
                "<li><input type='checkbox' name='archive' id='$_' checked>"
                . "<label for='$_'> $title</label></li>";
        }
        else {
            $arclist .=
                "<li><input type='checkbox' name='archive' id='$_' >"
                . "<label for='$_'> $title</label></li>";
        }
    }

    $redis->quit();

    #Build plugin listing
    my @plugins = LANraragi::Model::Plugins::plugins;

    #Plugin list is an array of hashes
    my @pluginlist = ();

    foreach my $plugin (@plugins) {
        my %pluginfo = $plugin->plugin_info();
        push @pluginlist, \%pluginfo;
    }

    $self->render(
        template => "batch",
        arclist  => $arclist,
        plugins  => \@pluginlist,
        title    => $self->LRR_CONF->get_htmltitle,
        cssdrop  => LANraragi::Utils::Generic::generate_themes_selector,
        csshead  => LANraragi::Utils::Generic::generate_themes_header
    );
}

#Websocket server receiving a list of IDs as a JSON and calling the specified plugin on them.
sub socket {

    my $self      = shift;
    my $cancelled = 0;
    my $client    = $self->tx;
    my $redis     = $self->LRR_CONF->get_redis();

    my $logger =
      LANraragi::Utils::Generic::get_logger( "Batch Tagging", "lanraragi" );

    $logger->info('Client connected to Batch Tagging service');

    # Increase inactivity timeout for connection a bit
    $self->inactivity_timeout(300);

    $self->on(
        message => sub {
            my ( $self, $msg ) = @_;

            #JSON-decode message and grab the plugin
            my $command    = decode_json($msg);
            my $pluginname = $command->{"plugin"};

            my $plugin = LANraragi::Utils::Database::plugin_lookup($pluginname);

            #Global arguments can come from the database or the user override
            my @args     = @{ $command->{"args"} };
            my @archives = @{ $command->{"archives"} };
            my $timeout  = $command->{"timeout"} || 0;

            if ($plugin) {

                #If the array is empty(no overrides)
                if ( !@args ) {
                    $logger->debug("No user overrides given.");
                    #Try getting the app defaults
                    @args = LANraragi::Utils::Database::get_plugin_globalargs(
                        $pluginname);
                }

                # Start the job in a subprocess
                my $subprocess = Mojo::IOLoop::Subprocess->new;

                #Send a message for each completed archive
                $subprocess->on(
                    progress => sub {
                        my ( $subprocess, @data ) = @_;

                        $logger->debug("Subprocess reported progress");
                        $logger->debug("iscancelled = $cancelled");

                        if ( $cancelled eq 1 ) {
                            $client->finish( 1001 =>
                                  'The client has left or cancelled the job.' );

                            #kill subprocess
                            LANraragi::Utils::Generic::kill_pid(
                                $subprocess->pid );
                            return;
                        }

                        $client->send(
                            {
                                json => {
                                    id      => $data[0],
                                    success => $data[1],
                                    message => $data[2],
                                    tags    => $data[3],
                                    title   => $data[4],
                                    timeout => $timeout
                                }
                            }
                        );
                    }
                );

                #Main subprocess method
                $subprocess->run(
                    sub {
                        my $subprocess = shift;

                        #Start iterating on given archive list
                        foreach my $id (@archives) {
                            $logger->debug("Processing $id");

                            my %plugin_result =
                              LANraragi::Model::Plugins::exec_plugin_on_file(
                                $plugin, $id, "", @args );

                            #If the plugin exec returned tags, add them
                            unless ( exists $plugin_result{error} ) {    
                                LANraragi::Utils::Database::add_tags($id, $plugin_result{new_tags});

                                if (exists $plugin_result{title}) {
                                    LANraragi::Utils::Database::set_title($id, $plugin_result{title});
                                }
                            }

                            $subprocess->progress(
                                $id,
                                ( exists $plugin_result{error} ? 0 : 1 ),
                                $plugin_result{error},
                                $plugin_result{new_tags},
                                (exists $plugin_result{title} ? $plugin_result{title}:"")
                            );

                            $logger->debug("Waiting $timeout seconds.");
                            sleep $timeout;
                        }

                    },
                    sub {
                        my ( $subprocess, $err, @results ) = @_;
                        $logger->debug("Subprocess completed.");
                        $logger->debug("Error log (should be empty): $err");
                        $client->finish( 1000 => 'All operations completed!' );
                    }
                );
            }
            else {
                $client->finish( 1001 => 'This plugin does not exist' );
            }
        }
    );

    $self->on(

        #If the client doesn't respond, halt processing
        finish => sub {
            $logger->info('Client disconnected, halting remaining operations');
            $cancelled = 1;
        }
    );

}

1;
