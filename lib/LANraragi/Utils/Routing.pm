package LANraragi::Utils::Routing;

use strict;
use warnings;
use utf8;

use Config;
use Encode;

use Mojolicious::Plugin::Minion::Admin;

use LANraragi::Utils::Login      qw(is_logged_in_api);

use constant IS_UNIX => ( $Config{osname} ne 'MSWin32' );

#Contains all the routes used by the app, and applies them on boot.
sub apply_routes {
    my $self = shift;

    # Initialize Mojolicious::Plugin::OpenAPI
    # And the single "/search" API endpoint because datatables
    my $api         = $self->routes;
    my $search_api  = $self->routes;

    # The API router outputs CORS headers if the user allows it in the settings.
    if ( $self->LRR_CONF->enable_cors ) {

        # Private API requests are non-simple due to the Authorization header, so browsers send a preflight request.
        # Preflight requests are OPTIONS requests, which we need to support explicitly
        $api        = $api->under('/')->to('login#setup_cors');
        $search_api = $search_api->under('/')->to('login#setup_cors');
    }
    if ( $self->LRR_CONF->enable_nofun ) {
        $api        = $api->under('/')->to('login#logged_in_api');
        $search_api = $search_api->under('/')->to('login#logged_in_api');
    }

    # All "/api/*" endpoints are passed to OpenAPI.
    $self->plugin(
        "OpenAPI" => {
            url    => $self->home->rel_file("tools/openapi.yaml"),
            route  => $api,
            security => {
                api_key => sub {
                    my ( $c, $definition, $scopes, $cb ) = @_;
                    if ( is_logged_in_api($c) ) {
                        return $c->$cb();
                    }
                    else {
                        return $c->$cb('Unauthorized');
                    }
                }
            }
        }
    );

    if ( !IS_UNIX ) {

        # If the path to /public contains any special characters we need to decode it and pass it back to mojo
        @{ $self->static->paths }[0] = decode_utf8( @{ $self->static->paths }[0] );
    }

    # Routers used for all loginless routes
    my $public_routes = $self->routes;

    # Normal route to controller
    $public_routes->get('/login')->to('login#index');
    $public_routes->post('/login')->to('login#check');
    $public_routes->get('/logout')->to('login#logout');

    # Routers for routes that require auth
    my $logged_in               = $public_routes->under('/')->to('login#logged_in');
    my $logged_in_search_api    = $search_api->under('/')->to('login#logged_in');

    # No-Fun Mode locks the base routes behind login as well
    if ( $self->LRR_CONF->enable_nofun ) {
        $public_routes  = $logged_in;
        $search_api     = $logged_in_search_api;
    }

    $public_routes->get('/')->to('index#index');
    $public_routes->get('/index')->to('index#index');
    $public_routes->get('/random')->to('index#random_archive');
    $public_routes->get('/reader')->to('reader#index');
    $public_routes->get('/stats')->to('stats#index');
    $public_routes->get('/js/i18n.js')->to('i18_n#index');

    # Minion Admin UI
    $self->plugin( 'Minion::Admin' => { route => $logged_in->get('/minion') } );

    # Mojo Status UI
    if ( $self->mode eq 'development' ) {

        # Not supported on Windows
        eval {
            require Mojolicious::Plugin::Status;
            $self->plugin( 'Status' => { route => $logged_in->get('/debug') } );
        };
    }

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

    $logged_in->get('/tankoubons')->to('tankoubon#index');

    $logged_in->get('/duplicates')->to('duplicates#index');

    $search_api->get('/search')->to('api-search#handle_datatables');

}

1;
