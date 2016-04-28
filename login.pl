#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use File::Basename;
use Redis;
use Encode;
use Template;

require 'functions/functions_config.pl';
require 'functions/functions_generic.pl';
require 'functions/functions_login.pl';

my $qlogin = new CGI;
my $tt  = Template->new({
        INCLUDE_PATH => "templates",
        #ENCODING => 'utf8' 
    });

my $wrongPass = 0;


if (&isUserLogged($qlogin))
	{
		#Redirect immediately
		print &redirectToPage($qlogin,"index.pl");
	}
else
	{
		#Handle login requests
		if ($qlogin->param()) {
		    # Parameters are defined, therefore something has been submitted.
		    if ('POST' eq $qlogin->request_method ) { 
					my $pass = $qlogin->param('password');

					my $loginCookie = &loginUser($qlogin,$pass);
					
					unless ($loginCookie eq "0") #We're logged, redirect with cookie
						{ print &redirectToPage($qlogin,"index.pl",$loginCookie); }
					else
						{ $wrongPass = 1; }

				}
		}

		#Regular HTML printout
		print $qlogin->header(-type    => 'text/html',
                   	-charset => 'utf-8');

		my $out;

		$tt->process(
	        "login.tmpl",
	        {
	            title => &get_htmltitle,
	            cssdrop => &printCssDropdown(0),
	            wrongpass => $wrongPass,
	        },
	        \$out,
	    ) or die $tt->error;

	    print $out;


	}
