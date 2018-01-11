package LANraragi::Controller::Login;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Authen::Passphrase;

use LANraragi::Model::Config;

sub check {
  my $self = shift;

  my $pw = $self->param('password') || '';

  #match password we got with the authen hash stored in redis
  my $ppr = Authen::Passphrase->from_rfc2307(&get_password);

  if ($ppr->match($pw))
  {
	my $redis = &getRedisConnection();

	my $session = CGI::Session->new( "driver:redis", $cgi, { Redis => $redis,
                                                             Expire => 60*60*24 } );

	$session->param("is_logged",1);
  }
  else {
  	$self->redirect_to('login', wrongpass => 1);
  }

  $self->session(is_logged => 1);
  $self->session(expiration => 60*60*24);
  $self->redirect_to('index');
}

sub logged_in {
  my $self = shift;
  return 1 if $self->session('is_logged');
  $self->redirect_to('login');
  return undef;
}

sub logout {
  my $self = shift;
  $self->session(expires => 1);
  $self->redirect_to('index');
}

sub render {
  my $self = shift;
  $self->render(template => "templates/login.tmpl",
  				      title => &get_htmltitle,
  	            cssdrop => &printCssDropdown(0)
  	            );
}

1;
