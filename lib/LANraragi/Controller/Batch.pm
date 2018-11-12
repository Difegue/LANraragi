package LANraragi::Controller::Batch;
use Mojo::Base 'Mojolicious::Controller';

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


1;
