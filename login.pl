#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use File::Basename;
use Redis;
use Encode;

require 'config.pl';
require 'functions/functions_generic.pl';
require 'functions/functions_login.pl';

my $qlogin = new CGI;			  
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
		my $htmltitle = &get_htmltitle;
		my $html = qq(

			<html>
			<head>
				<title>$htmltitle - Login</title>

				<meta name="viewport" content="width=device-width" />
				<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />

				<link type="image/png" rel="icon" href="./img/favicon.ico" />
				<link rel="stylesheet" type="text/css" href="./bower_components/font-awesome/css/font-awesome.min.css" />

				<script src="./js/css.js" type="text/JAVASCRIPT"></script>
				<script src="./bower_components/jquery/dist/jquery.min.js" type="text/JAVASCRIPT"></script>		
			</head>

			<body onload="set_style_from_storage()">

			);

		$html .= &printCssDropdown(0);
		$html .= "<script>set_style_from_storage();</script>";


		$html.= "<div class='ido' style='text-align:center'>
					<p>This page requires you to log on.</p>
					<form name='loginForm' method='post'>
					<table style='margin:auto; text-align:left; font-size:8pt;'>
						<tbody>
							<tr>
								<td>Admin Password:</td>
								<td>
								<input id='pw_field' class='stdinput' type='password' style='width:90%' value='' maxlength='255' size='20' name='password'>
								</td>
							</tr>
							<tr>
								<td style='padding-top:5px; text-align:center; vertical-align:middle' colspan='2'>
								<input class='stdbtn' type='submit' value='Login' style='width:60px'>
								</td>
							</tr>";

		unless ($wrongPass == 0 )
			{ $html .= 		"<tr style='font-size:23px'><td colspan='2' style='padding-top:5px; text-align:center; vertical-align:middle '>Wrong Password. </td></tr>"};

		$html .="		</tbody>
					</table>
					</form>
				</div>";


		print $qlogin->header(-type    => 'text/html',
                   	-charset => 'utf-8');
		print $html;

	}
