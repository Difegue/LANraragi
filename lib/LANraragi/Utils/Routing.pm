package LANraragi::Utils::Routing;

use strict;
use warnings;
use utf8;

use Mojolicious::Plugin::Minion::Admin;

#Contains all the routes used by the app, and applies them on boot.
sub apply_routes {
    my $self = shift;

    # Router
    my $r = $self->routes;

    # Normal route to controller
    $r->get('/login')->to('login#index');
    $r->post('/login')->to('login#check');

    my $logged_in = $r->under('/')->to('login#logged_in');

    # These API endpoints will always require the API Key or to be logged in
    my $logged_in_api = $r->under('/')->to('login#logged_in_api');

    # Router used for all loginless routes
    my $public_routes = $r;
    my $public_api    = $r;

    #No-Fun Mode locks the base routes behind login as well
    if ( $self->LRR_CONF->enable_nofun ) {
        $public_routes = $logged_in;
        $public_api    = $logged_in_api;
    }

    $public_routes->get('/')->to('index#index');
    $public_routes->get('/index')->to('index#index');
    $public_routes->get('/random')->to('index#random_archive');
    $public_routes->get('/reader')->to('reader#index');
    $public_routes->get('/stats')->to('stats#index');

    # Minion Admin UI
    $self->plugin( 'Minion::Admin' => { route => $logged_in->get('/minion') } );

    # Those routes are only accessible if user is logged in
    $logged_in->get('/config')->to('config#index');
    $logged_in->post('/config')->to('config#save_config');

    $logged_in->get('/config/plugins')->to('plugins#index');
    $logged_in->post('/config/plugins')->to('plugins#save_config');
    $logged_in->post('/config/plugins/upload')->to('plugins#process_upload');

    $logged_in->get('/config/categories')->to('category#index');

    $logged_in->get('/batch')->to('batch#index');
    $logged_in->websocket('/batch/socket')->to('batch#socket');

    $logged_in->get('/edit')->to('edit#index');
    $logged_in->delete('/edit')->to('edit#delete_archive');

    $logged_in->get('/backup')->to('backup#index');
    $logged_in->post('/backup')->to('backup#restore');

    $logged_in->get('/upload')->to('upload#index');
    $logged_in->post('/upload')->to('upload#process_upload');

    $logged_in->get('/logs')->to('logging#index');
    $logged_in->get('/logs/general')->to('logging#print_general');
    $logged_in->get('/logs/shinobu')->to('logging#print_shinobu');
    $logged_in->get('/logs/plugins')->to('logging#print_plugins');
    $logged_in->get('/logs/mojo')->to('logging#print_mojo');
    $logged_in->get('/logs/redis')->to('logging#print_redis');

    # Miscellaneous API
    $public_api->get('/api/opds')->to('api-other#serve_opds');
    $public_api->get('/api/info')->to('api-other#serve_serverinfo');
    $logged_in_api->get('/api/plugins/:type')->to('api-other#list_plugins');
    $logged_in_api->post('/api/plugins/use')->to('api-other#use_plugin');
    $logged_in_api->delete('/api/tempfolder')->to('api-other#clean_tempfolder');
    $logged_in_api->get('/api/minion/:jobid')->to('api-other#minion_job_status');
    $logged_in_api->post('/api/download_url')->to('api-other#download_url');
    $logged_in_api->post('/api/regen_thumbs')->to('api-other#regen_thumbnails');

    # Archive API
    $public_api->get('/api/archives')->to('api-archive#serve_archivelist');
    $public_api->get('/api/archives/untagged')->to('api-archive#serve_untagged_archivelist');
    $public_api->get('/api/archives/:id/thumbnail')->to('api-archive#serve_thumbnail');
    $public_api->get('/api/archives/:id/download')->to('api-archive#serve_file');
    $public_api->get('/api/archives/:id/page')->to('api-archive#serve_page');
    $public_api->post('/api/archives/:id/extract')->to('api-archive#extract_archive');
    $public_api->put('/api/archives/:id/progress/:page')->to('api-archive#update_progress');
    $public_api->delete('/api/archives/:id/isnew')->to('api-archive#clear_new');
    $public_api->get('/api/archives/:id')->to('api-archive#serve_metadata');
    $public_api->get('/api/archives/:id/categories')->to('api-archive#get_categories');
    $public_api->get('/api/archives/:id/metadata')->to('api-archive#serve_metadata');
    $logged_in_api->put('/api/archives/:id/metadata')->to('api-archive#update_metadata');

    # Search API
    $public_api->get('/search')->to('api-search#handle_datatables');
    $public_api->get('/api/search')->to('api-search#handle_api');
    $logged_in_api->delete('/api/search/cache')->to('api-search#clear_cache');

    # Database API
    $logged_in_api->get('/api/database/backup')->to('api-database#serve_backup');
    $logged_in_api->delete('/api/database/isnew')->to('api-database#clear_new_all');
    $logged_in_api->post('/api/database/drop')->to('api-database#drop_database');
    $logged_in_api->post('/api/database/clean')->to('api-database#clean_database');
    $public_api->get('/api/database/stats')->to('api-database#serve_tag_stats');

    # Shinobu API
    $logged_in_api->get('/api/shinobu')->to('api-shinobu#shinobu_status');
    $logged_in_api->post('/api/shinobu/stop')->to('api-shinobu#stop_shinobu');
    $logged_in_api->post('/api/shinobu/restart')->to('api-shinobu#restart_shinobu');

    # Category API
    $public_api->get('/api/categories')->to('api-category#get_category_list');
    $public_api->get('/api/categories/:id')->to('api-category#get_category');
    $logged_in_api->put('/api/categories')->to('api-category#create_category');
    $logged_in_api->put('/api/categories/:id')->to('api-category#update_category');
    $logged_in_api->delete('/api/categories/:id')->to('api-category#delete_category');
    $logged_in_api->put('/api/categories/:id/:archive')->to('api-category#add_to_category');
    $logged_in_api->delete('/api/categories/:id/:archive')->to('api-category#remove_from_category');

    $r->get('/logout')->to('login#logout');

}

1;
