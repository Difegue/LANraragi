package LANraragi::Controller::Login;
use Mojo::Base 'Mojolicious::Controller';
use MIME::Base64;

use Redis;
use Authen::Passphrase;

use LANraragi::Utils::Generic qw(generate_themes_selector generate_themes_header);

sub check {
    my $self = shift;

    my $pw = $self->req->param('password') || '';

    #match password we got with the authen hash stored in redis
    my $ppr = Authen::Passphrase->from_rfc2307( $self->LRR_CONF->get_password );

    if ( $ppr->match($pw) ) {
        $self->session( is_logged  => 1 );
        $self->session( expiration => 60 * 60 * 24 );
        $self->redirect_to('index');
    } else {
        $self->render(
            template  => "login",
            title     => $self->LRR_CONF->get_htmltitle,
            cssdrop   => generate_themes_selector,
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
    $self->redirect_to('login');
    return 0;
}

#For APIs, the request can also be authentified with a valid API Key.
sub logged_in_api {
    my $self = shift;

    # Uncomment this to send Access-Control-Allow-Origin = '*'
    #$self->res->headers->access_control_allow_origin('*');

    # The API key can be either a key parameter, or in the Authentication header.
    # The parameter variant is deprecated and will be removed in a future release.
    my $key          = $self->req->param('key') || '';
    my $expected_key = $self->LRR_CONF->get_apikey;

    my $auth_header     = $self->req->headers->authorization || "";
    my $expected_header = "Bearer " . encode_base64( $expected_key, "" );

    return 1
      if ( $key ne "" && $key eq $expected_key )
      || ( $expected_key ne "" && $auth_header eq $expected_header )
      || $self->session('is_logged')
      || $self->LRR_CONF->enable_pass == 0;
    $self->render(
        json   => { error => "This API is protected and requires login or an API Key." },
        status => 401
    );
    return 0;
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
        cssdrop  => generate_themes_selector,
        csshead  => generate_themes_header($self),
        version  => $self->LRR_VERSION
    );
}

1;
