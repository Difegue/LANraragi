use strict;
use Redis;
use CGI::Session;

require 'config.pl';

#redirectToPage($cgi,pageName,cookie)
sub redirectToPage {

	my ( $cgi, $redirURL, $cookie) = @_;

	#Redirection header
	unless (defined $cookie)
	{ return $cgi->redirect(    -URL     => $redirURL); }
	else
	{ return $cgi->redirect(    -URL     => $redirURL,
                				-COOKIE  => $cookie);   }

	}


#isUserLogged($cgi)
#If passwording is enabled, did the user input the password ? 
#Opens the session object (after clearing expired sessions) and checks is_logged. 
#If unlogged, redirect to login.pl. 
sub isUserLogged{

	if (&enable_pass)
	{

		my $cgi = $_[0];
		my $redis = Redis->new(server => &get_redisad, 
								reconnect => 100,
								every     => 3000);


		my $session = CGI::Session->new( "driver:redis", $cgi, { Redis => $redis,
	                                                             Expire => 60*60*24 } );

		if ($session->param("is_logged")==1)
			{ return 1;}
		else
			{ return 0;}
	}
	else
	{ return 1; }

	}

#loginUser($cgi, password)
#Handle a login request. Check password, and if it's correct setup a session object with is_logged=1 and return the cookie object to embed in html header.
#Return 0 and do nothing if incorrect password.
sub loginUser{

	my $pw = $_[1];
	my $cgi = $_[0];

	if ($pw eq &get_password)
	{
		my $redis = Redis->new(server => &get_redisad, 
								reconnect => 100,
								every     => 3000);


		my $session = CGI::Session->new( "driver:redis", $cgi, { Redis => $redis,
	                                                             Expire => 60*60*24 } );

		$session->param("is_logged",1);

		my $cookie = $cgi->cookie( "CGISESSID", $session->id );
		return $cookie;
	}
	else
	{return "0";}

}
