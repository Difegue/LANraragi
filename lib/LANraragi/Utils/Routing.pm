package LANraragi::Utils::Routing;

use strict;
use warnings;
use utf8;

#Contains all the routes used by the app, and applies them on boot.
sub apply_routes {
    my $self = shift;

    # Router
    my $r = $self->routes;

    # Normal route to controller
    $r->get('/login')->to('login#index');
    $r->post('/login')->to('login#check');

    my $logged_in     = $r->under('/')->to('login#logged_in');
    my $logged_in_api = $r->under('/')->to('login#logged_in_api');

    #No-Fun Mode locks the base routes behind login as well
    if ( $self->LRR_CONF->enable_nofun ) {
        $logged_in->get('/')->to('index#index');
        $logged_in->get('/index')->to('index#index');
        $logged_in->get('/search')->to('search#handle_datatables');
        
        $logged_in->get('/random')->to('index#random_archive');
        $logged_in->get('/reader')->to('reader#index');
        $logged_in->get('/stats')->to('stats#index');

        #API Key needed for those endpoints in No-Fun Mode
        $logged_in_api->get('/api/thumbnail')->to('api#serve_thumbnail');
        $logged_in_api->get('/api/servefile')->to('api#serve_file');
        $logged_in_api->get('/api/archivelist')->to('api#serve_archivelist');
        $logged_in_api->get('/api/untagged')->to('api#serve_untagged_archivelist');
        $logged_in_api->get('/api/opds')->to('api#serve_opds');
        $logged_in_api->get('/api/tagstats')->to('api#serve_tag_stats');
        $logged_in_api->get('/api/extract')->to('api#extract_archive');
        $logged_in_api->get('/api/clear_new')->to('api#clear_new');
        $logged_in_api->get('/api/search')->to('search#handle_api');
    }
    else {
        #Standard behaviour is to leave those routes loginless for all clients
        $r->get('/')->to('index#index');
        $r->get('/index')->to('index#index');
        $r->get('/random')->to('index#random_archive');
        $r->get('/reader')->to('reader#index');
        $r->get('/stats')->to('stats#index');
        $r->get('/search')->to('search#handle_datatables');
        $r->get('/auth')->to('auth');
        $r->get('/upload')->to('upload#index');
        $r->post('/upload')->to('upload#process_upload');
        $r->get('/logs')->to('logging#index');

        $r->get('/api/search')->to('search#handle_api');
        $r->get('/api/thumbnail')->to('api#serve_thumbnail');
        $r->get('/api/servefile')->to('api#serve_file');
        $r->get('/api/archivelist')->to('api#serve_archivelist');
        $r->get('/api/untagged')->to('api#serve_untagged_archivelist');
        $r->get('/api/opds')->to('api#serve_opds');
        $r->get('/api/tagstats')->to('api#serve_tag_stats');
        $r->get('/api/extract')->to('api#extract_archive');
        $r->get('/api/clear_new')->to('api#clear_new');
    }

    #Those routes are only accessible if user is logged in
    $logged_in->get('/config')->to('config#index');
    $logged_in->post('/config')->to('config#save_config');

    $logged_in->get('/config/plugins')->to('plugins#index');
    $logged_in->post('/config/plugins')->to('plugins#save_config');
    $logged_in->post('/config/plugins/upload')->to('plugins#process_upload');

    $logged_in->get('/batch')->to('batch#index');
    $logged_in->websocket('/batch/socket')->to('batch#socket');

    $logged_in->get('/edit')->to('edit#index');
    $logged_in->post('/edit')->to('edit#save_metadata');
    $logged_in->delete('/edit')->to('edit#delete_archive');

    $logged_in->get('/backup')->to('backup#index');
    $logged_in->post('/backup')->to('backup#restore');

    # These API endpoints will always require the API Key or to be logged in 
    $logged_in_api->post('/api/use_plugin')->to('api#use_plugin');
    $logged_in_api->post('/api/autoplugin')->to('api#use_enabled_plugins');
    $logged_in_api->get('/api/clean_temp')->to('api#clean_tempfolder');
    $logged_in_api->get('/api/discard_cache')->to('api#clear_cache');
    $logged_in_api->get('/api/shinobu_status')->to('api#shinobu_status');
    $logged_in_api->get('/api/stop_shinobu')->to('api#stop_shinobu');
    $logged_in_api->get('/api/restart_shinobu')->to('api#restart_shinobu');
    $logged_in_api->get('/api/backup')->to('api#serve_backup');
    $logged_in_api->get('/api/clear_new_all')->to('api#clear_new_all');
    $logged_in_api->get('/api/drop_database')->to('api#drop_database');
    $logged_in_api->get('/api/clean_database')->to('api#clean_database');

    $logged_in->get('/logs/general')->to('logging#print_general');
    $logged_in->get('/logs/shinobu')->to('logging#print_shinobu');
    $logged_in->get('/logs/plugins')->to('logging#print_plugins');
    $logged_in->get('/logs/mojo')->to('logging#print_mojo');
    $logged_in->get('/logs/redis')->to('logging#print_redis');

    $r->get('/logout')->to('login#logout');

}

1;
