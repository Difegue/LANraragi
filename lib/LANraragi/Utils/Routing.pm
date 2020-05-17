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

    my $logged_in = $r->under('/')->to('login#logged_in');

    # These API endpoints will always require the API Key or to be logged in
    my $logged_in_api = $r->under('/')->to('login#logged_in_api');

    # Router used for all loginless routes
    my $public_routes = $r;

    #No-Fun Mode locks the base routes behind login as well
    if ( $self->LRR_CONF->enable_nofun ) {
        $public_routes = $logged_in_api;
    }

    $public_routes->get('/')->to('index#index');
    $public_routes->get('/index')->to('index#index');
    $public_routes->get('/random')->to('index#random_archive');
    $public_routes->get('/reader')->to('reader#index');
    $public_routes->get('/stats')->to('stats#index');

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
    $logged_in->post('/edit')->to('edit#save_metadata');
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
    $public_routes->get('/api/opds')->to('api#serve_opds');
    $logged_in_api->get('/api/use_plugin')->to('api#use_plugin');
    $logged_in_api->post('/api/plugin/use')->to('api#use_plugin');
    $logged_in_api->get('/api/clean_temp')->to('api#clean_tempfolder');    #old
    $logged_in_api->delete('/api/tempfolder')->to('api#clean_tempfolder');

    # Archive API (TODO)
    $public_routes->get('/api/thumbnail')->to('api#serve_thumbnail');
    $public_routes->get('/api/servefile')->to('api#serve_file');
    $public_routes->get('/api/archivelist')->to('api#serve_archivelist');
    $public_routes->get('/api/untagged')->to('api#serve_untagged_archivelist');
    $public_routes->get('/api/extract')->to('api#extract_archive');
    $public_routes->get('/api/clear_new')->to('api#clear_new');
    $logged_in_api->post('/api/autoplugin')->to('api#use_enabled_plugins');

    # /api/page is always available even in No-Fun-Mode.
    # This technically means that people *can* get pages off an uploaded archive if it's been extracted before.
    # (And if they can guess the ID and path to the files)
    # TODO: Remove as the api key moves to an auth header, removing the need for this compat workaround.
    $r->get('/api/page')->to('api#serve_page');

    # Search API
    $public_routes->get('/search')->to('api-search#handle_datatables');
    $public_routes->get('/api/search')->to('api-search#handle_api');
    $logged_in_api->get('/api/discard_cache')->to('api-search#clear_cache');    #old
    $logged_in_api->delete('/api/search/cache')->to('api-search#clear_cache');

    # Database API - old endpoints
    $logged_in_api->get('/api/backup')->to('api-database#serve_backup');
    $logged_in_api->get('/api/clear_new_all')->to('api-database#clear_new_all');
    $logged_in_api->get('/api/drop_database')->to('api-database#drop_database');
    $logged_in_api->get('/api/clean_database')->to('api-database#clean_database');
    $public_routes->get('/api/tagstats')->to('api-database#serve_tag_stats');

    # Database API - new endpoints
    $logged_in_api->get('/api/database/backup')->to('api-database#serve_backup');
    $logged_in_api->delete('/api/database/isnew')->to('api-database#clear_new_all');
    $logged_in_api->post('/api/database/drop')->to('api-database#drop_database');
    $logged_in_api->post('/api/database/clean')->to('api-database#clean_database');
    $public_routes->get('/api/database/stats')->to('api-database#serve_tag_stats');

    # Shinobu API - old endpoints
    $logged_in_api->get('/api/shinobu_status')->to('api-shinobu#shinobu_status');
    $logged_in_api->get('/api/stop_shinobu')->to('api-shinobu#stop_shinobu');
    $logged_in_api->get('/api/restart_shinobu')->to('api-shinobu#restart_shinobu');

    # Shinobu API - new endpoints
    $logged_in_api->get('/api/shinobu')->to('api-shinobu#shinobu_status');
    $logged_in_api->post('/api/shinobu/stop')->to('api-shinobu#stop_shinobu');
    $logged_in_api->post('/api/shinobu/restart')->to('api-shinobu#restart_shinobu');

    # Category API
    $public_routes->get('/api/categories')->to('api-category#get_category_list');
    $logged_in_api->put('/api/categories')->to('api-category#create_category');
    $logged_in_api->put('/api/categories/:id')->to('api-category#update_category');
    $logged_in_api->delete('/api/categories/:id')->to('api-category#delete_category');
    $logged_in_api->put('/api/categories/:id/:archive')->to('api-category#add_to_category');
    $logged_in_api->delete('/api/categories/:id/:archive')->to('api-category#remove_from_category');

    $r->get('/logout')->to('login#logout');

}

1;
