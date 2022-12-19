package LANraragi::Controller::Login;
use Mojo::Base 'Mojolicious::Controller';
use MIME::Base64;

use Redis;
use Authen::Passphrase;

use LANraragi::Utils::Generic qw(generate_themes_header);

sub check {
    my $self = shift;

    my $pw       = $self->req->param('password') || '';
    my $redirect = $self->req->param('redirect') || 'index';

    #match password we got with the authen hash stored in redis
    my $ppr = Authen::Passphrase->from_rfc2307( $self->LRR_CONF->get_password );

    if ( $ppr->match($pw) ) {

        $self->LRR_LOGGER->info( "Successful login attempt from " . $self->tx->remote_address );

        $self->session( is_logged  => 1 );
        $self->session( expiration => 60 * 60 * 24 );
        $self->redirect_to($redirect);
    } else {

        $self->LRR_LOGGER->warn( "Failed login attempt with password '$pw' from " . $self->tx->remote_address );

        $self->render(
            template  => "login",
            title     => $self->LRR_CONF->get_htmltitle,
            descstr   => $self->LRR_DESC,
            csshead   => generate_themes_header($self),
            version   => $self->LRR_VERSION,
            wrongpass => 1
        );
    }
}

#The request can be authentified in two ways:
#Logged in normally with a session cookie
#Password protection disabled
sub logged_in {
    my $self = shift;
    return 1
      if $self->session('is_logged')
      || $self->LRR_CONF->enable_pass == 0;

    my $url = $self->url_for("login");
    $self->redirect_to( $url->query( redirect => $self->req->url->path_query ) );
    return 0;
}

# For APIs, the request can also be authentified with a valid API Key.
sub logged_in_api {
    my $self = shift;

    # The API key is in the Authentication header.
    my $expected_key = $self->LRR_CONF->get_apikey;
    my $expected_header = "Bearer " . encode_base64( $expected_key, "" );

    my $auth_header = $self->req->headers->authorization || "";

    # It can also be passed as a parameter. (Undocumented, mostly just meant for OPDS)
    my $param_key = $self->req->param('key') || '';

    return 1
      if ( $expected_key ne "" && $auth_header eq $expected_header )
      || ( $param_key ne "" && $param_key eq $expected_key )
      || $self->session('is_logged')
      || $self->LRR_CONF->enable_pass == 0;
    $self->render(
        json   => { error => "This API is protected and requires login or an API Key." },
        status => 401
    );
    return 0;
}

sub setup_cors {
    my $self = shift;

    # Set Allow-Origin to wildcard and Allow-Methods to most common ones
    $self->res->headers->header( 'Access-Control-Allow-Origin'  => '*' );
    $self->res->headers->header( 'Access-Control-Allow-Methods' => 'GET, OPTIONS, POST, DELETE, PUT' );

    # Explicitly say requests with an Authorization header (private API requests) are allowed
    $self->res->headers->header( 'Access-Control-Allow-Headers' => 'Authorization' );

    return 1;
}

sub logout {
    my $self = shift;
    $self->session( expires => 1 );
    $self->redirect_to('index');
}

sub index {
    my $self = shift;
    $self->redirect_to('index') if $self->session('is_logged');

    $self->render(
        template => "login",
        title    => $self->LRR_CONF->get_htmltitle,
        descstr  => $self->LRR_DESC,
        csshead  => generate_themes_header($self),
        version  => $self->LRR_VERSION
    );
}

1;
