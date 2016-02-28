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

my $html = start_html
	(
	-title=>&get_htmltitle.' - Edit Mode',
    -author=>'lanraragi-san',		
    -style=>[{'src'=>'./bower_components/font-awesome/css/font-awesome.min.css'}],
    -script=>[{-type=>'JAVASCRIPT',
							-src=>'./js/css.js'},
			 {-type=>'JAVASCRIPT',
							-src=>'./bower_components/jquery/dist/jquery.min.js'},
			 {-type=>'JAVASCRIPT',
							-src=>'./js/ajax.js'}],			
	-head=>[Link({-rel=>'icon',-type=>'image/png',-href=>'favicon.ico'}),
					meta({-name=>'viewport', -content=>'width=device-width'})],
	-encoding => "utf-8",
	-onLoad => "//Set the correct CSS from the user's localStorage.
						set_style_from_storage();"
	);

$html .= &printCssDropdown(0);
$html .= "<script>set_style_from_storage();</script>";
	
#Before anything, check if the user is logged in. If not, redirect him to login.pl?redirect=edit.pl
if (&isUserLogged($qedit))
	{
		#Regular header
		print $qedit->header(-type    => 'text/html',
                   	-charset => 'utf-8');

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
					
					$html .= "<div class='ido' style='text-align:center'><h1>Edit Successful!</h1><br/>";
						
					$html .= "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/></div>";
					
							
				} else {
					# It's GET. That means we've only been given a file id. 
				    
					#Does the passed file exist?
					my $id = $qedit->param('id');

					if ($redis->hexists($id,"title")) 
					{
						
						if ($qedit->param('delete') eq "1") #Case 1: Delete Archive
						{
							my $delStatus = &deleteArchive($id);

							$html .= "<div class='ido' style='text-align:center'><h1>Archive deleted. <br/>($delStatus)</h1><br/>";
							$html .= "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/></div>";
						}
						else
						{ $html .= &generateForm($qedit); }	#Case 2: Standard edit. Generate the renaming form.
					}
					else #Case 3: The archive doesn't exist
					{
						$html .= "<div class='ido' style='text-align:center'><h1>File not found. </h1><br/>";
						$html .= "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/></div>";
					}

					$redis->quit();
				} 
		} 
		else 
		{
		   # No parameters at all, redirect
		   print &redirectToPage($qedit,"index.pl");
		}

		$html .= end_html;

		#We print the html we generated.
		print $html;

	}
	else
	{
		#Not logged in, redirect
		print &redirectToPage($qedit,"login.pl");

	}



