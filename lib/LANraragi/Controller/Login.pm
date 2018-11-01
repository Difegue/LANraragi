package LANraragi::Controller::Login;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Authen::Passphrase;

use LANraragi::Utils::Generic;
use LANraragi::Utils::Archive;
use LANraragi::Utils::Database;

use LANraragi::Model::Config;

sub check {
    my $self = shift;

    my $pw = $self->req->param('password') || '';

    #match password we got with the authen hash stored in redis
    my $ppr = Authen::Passphrase->from_rfc2307( $self->LRR_CONF->get_password );

    if ( $ppr->match($pw) ) {
        $self->session( is_logged  => 1 );
        $self->session( expiration => 60 * 60 * 24 );
        $self->redirect_to('index');
    }
    else {
        $self->render(
            template  => "login",
            title     => $self->LRR_CONF->get_htmltitle,
            cssdrop   => LANraragi::Utils::Generic::generate_themes(0),
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
      if $self->session('is_logged') || 
         $self->LRR_CONF->enable_pass == 0;
    $self->redirect_to('login');
    return 0;
}

#For APIs, the request can also be authentified with a valid API Key.
sub logged_in_api {
    my $self = shift;
    my $key = $self->req->param('key') || '';
    return 1
      if $key ne "" && $key eq $self->LRR_CONF->get_apikey ||
         $self->session('is_logged') || 
         $self->LRR_CONF->enable_pass == 0;
    $self->render(json => {
            error => "This API is protected and requires login or an API Key."
            });
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
        cssdrop   => LANraragi::Utils::Generic::generate_themes_selector,
        csshead   => LANraragi::Utils::Generic::generate_themes_header
    );
}

1;
