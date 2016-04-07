#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use File::Basename;
use Redis;
use Encode;

#Require config 
require 'config.pl';
require 'functions/functions_generic.pl';
require 'functions/functions_login.pl';
require 'functions/functions_edit.pl';

my $qedit = new CGI;			   
my $pagetitle = &get_htmltitle;
my $html = qq(
	<html>
	<head>
	<title>$pagetitle - Edit Mode</title>

	<meta name="viewport" content="width=device-width" />
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />

	<link type="image/png" rel="icon" href="./img/favicon.ico" />
	<link rel="stylesheet" type="text/css" href="./bower_components/font-awesome/css/font-awesome.min.css" />

	<script src="./js/css.js" type="text/JAVASCRIPT"></script>
	<script src="./bower_components/jquery/dist/jquery.min.js" type="text/JAVASCRIPT"></script>
	<script src="./js/ajax.js" type="text/JAVASCRIPT"></script>
	
	</head>

	<body onload="set_style_from_storage();">

	);

$html .= &printCssDropdown(0);
$html .= "<script>set_style_from_storage();</script>
		<div class='ido' style='text-align:center'>";
	
#Before anything, check if the user is logged in. If not, redirect him to login.pl?redirect=edit.pl
if (&isUserLogged($qedit))
	{
		
		if ($qedit->param()) {
		    # Parameters are defined, therefore something has been submitted...	
			
			#Redis initialization.
			my $redis = Redis->new(server => &get_redisad, 
								reconnect => 100,
								every     => 3000);

			
			#Are the submitted arguments POST?
			if ('POST' eq $qedit->request_method ) { 
					# It's POST, which means parameters for an edit have been passed.
					 
					my $event = $qedit->param('event');
					my $artist = $qedit->param('artist');
					my $title = $qedit->param('title');
					my $series = $qedit->param('series');
					my $language = $qedit->param('language');
					my $tags = $qedit->param('tags');
					my $id = $qedit->param('id');
					
					#clean up the user's inputs and encode them.
					(removeSpaceF($_)) for ($event, $artist, $title, $series, $language, $tags);

					#Input new values into redis hash.
					#prepare the hash which'll be inserted.
					my %hash = (
							event => encode_utf8($event),
							artist => encode_utf8($artist),
							title => encode_utf8($title),
							series => encode_utf8($series),
							language => encode_utf8($language),
							tags => encode_utf8($tags)
						);
						
					#for all keys of the hash, add them to the redis hash $id with the matching keys.
					$redis->hset($id, $_, $hash{$_}, sub {}) for keys %hash;
					$redis->wait_all_responses;

					$html .= "<h1>Edit Successful!</h1><br/>";
					$html .= "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/>";
					
							
				} else {
					# It's GET. That means we've only been given a file id. 
				    
					#Does the passed file exist?
					my $id = $qedit->param('id');

					if ($redis->hexists($id,"title")) 
					{
						
						if ($qedit->param('delete') eq "1") #Case 1: Delete Archive
						{
							my $delStatus = &deleteArchive($id);

							$html .= "<h1>Archive deleted. <br/>($delStatus)</h1><br/>";
							$html .= "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/>";
						}
						else
						{ $html .= &generateForm($qedit); }	#Case 2: Standard edit. Generate the renaming form.
					}
					else #Case 3: The archive doesn't exist
					{
						$html .= "<h1>File not found. </h1><br/>";
						$html .= "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/>";
					}

					$redis->quit();
				} 
		} 
		else 
		{
		   # No parameters at all, redirect
		   print &redirectToPage($qedit,"index.pl");
		}

		$html .= "</div></body></html>";

		#Regular header
		print $qedit->header(-type    => 'text/html',
                   	-charset => 'utf-8');

		#We print the html we generated.
		print $html;

	}
	else
	{
		#Not logged in, redirect
		print &redirectToPage($qedit,"login.pl");

	}




