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

    #Fill the list with archives by looking up in redis
    my $arclist = "";
    my $redis = $self->LRR_CONF->get_redis();
    my @keys  = $redis->keys( '????????????????????????????????????????' ); 
    #40-character long keys only => Archive IDs 

    #Parse the archive list and add <li> elements accordingly.
    foreach my $id (@keys) {

        if ($redis->hexists($id,"title")) {
            my $title = $redis->hget($id,"title");
            $title = LANraragi::Utils::Database::redis_decode($title);

            #If the archive has no tags, pre-check it in the list.
            if ($redis->hget($id,"tags") eq "") { 
                $arclist .= "<li><input type='checkbox' name='archive' id='$id' checked><label for='$id'> $title</label></li>";
            } else { 
                $arclist .= "<li><input type='checkbox' name='archive' id='$id' ><label for='$id'> $title</label></li>"; 
            }
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

    $self->on(message => sub {
        my ($self, $msg) = @_;

        #JSON-decode message and grab the plugin
        my $command  = decode_json($msg);

        my $plugin   = LANraragi::Utils::Database::plugin_lookup($command ->{"plugin"});
        my @archives = @{$command->{"archives"}};
        my $timeout  = $command->{"timeout"} || 0;

        #Start iterating on list and sending a message for each completed archive
        if ($plugin) {

            my @args = LANraragi::Utils::Database::get_plugin_globalargs($command ->{"plugin"});
        
            foreach my $id (@archives) {
                $logger->debug($id);

                if ($cancelled eq 1)
                    { 
                        $client->finish(1001 => 'The client has left!');
                        return; 
                    }

                my %plugin_result =
                LANraragi::Model::Plugins::exec_plugin_on_file( $plugin, $id,
                "", @args );
                
                $client->send({json => {
                    id        => $id,
                    success   => (exists $plugin_result{error} ? 0:1),
                    message   => $plugin_result{error},
                    tags      => $plugin_result{new_tags}
                }});    

                $logger->debug("Waiting $timeout seconds.");
                sleep $timeout;            
            }       
            $client->finish(1000 => 'All operations completed!');
        } else {
            $client->finish(1001 => 'This plugin does not exist');
        }
    });

    #If the client doesn't respond, halt processing
    $self->on(finish => sub {
        $logger->info('Client disconnected, halting remaining operations');
        $cancelled = 1;
    });

}

1;
