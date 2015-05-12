#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use File::Basename;
use utf8;

require 'config.pl';
require 'functions.pl';

my $qupload = new CGI;
print $qupload->header;
print $qupload->start_html
	(
	-title=>&get_htmltitle." - Tag Importer/Exporter",
    -author=>'lanraragi-san',	
    -script=>{-type=>'JAVASCRIPT',
							-src=>'./js/css.js'},			
	-head=>[Link({-rel=>'icon',-type=>'image/png',-href=>'favicon.ico'})],
	-encoding => "utf-8",
	-onload=> "set_style_from_cookie();",
	);

print &printCssDropdown(0);
	

if ($qupload->param()) {
    # Parameters are defined, therefore something has been submitted...	
    my $id = $qupload->param('id');

	#Are the submitted arguments POST?
	if ('POST' eq $qupload->request_method )
		{
		
		#Check if password is correct first.
		my $pass = $qupload->param('pass');
		unless (&enable_pass && ($pass eq &get_password))
			{
			print "<div class='ido' style='text-align:center'><h1>Wrong password.</h1><br/>";
			print "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/>";
			print "<input class='stdbtn' type='button' onclick=\"window.location.replace('./tags.pl');\" value='Try Again'/></div>";
			}
		else
			{ 
			#Get hash from Redis, then use EHSearch_Hash.

			#Open up Redis
			my $redis = Redis->new(server => &get_redisad, 
						reconnect => 100,
						every     => 3000);
			
			my $hash = $redis->hget($id,"thumbhash");
			print $hash."<br/>";
			
			#This rings up g.e-hentai with the SHA hash we obtained.
			my $queryJson = &getGalleryId($hash);
			print $queryJson."<br/>";

			my $tags = &getTagsFromAPI($queryJson);

			if ($tags eq(""))
				{
					print "No tags!";
				}
			else
				{
					print "tags are: ".$tags;
				}

			my $oldtags = $redis->hget($id,"tags");

			$redis->hset($id,"tags",$oldtags.", ".$tags);
			$redis->close();

			}
		}
	else
		{
			#It's GET. Print the form.
			
			print "<div class='ido' style='text-align:center'>";
			print $qupload->h1( {-class=>'ih', -style=>'text-align:center'},"Import Tags from E-Hentai API.");
			print $qupload->start_form;
			print "<table style='margin:auto'><tbody>";
			
			print "<tr><td style='text-align:left; width:100px'>Select File:</td><td>";
			print $qupload->textfield(
					-name      => 'id',
					-value     => $id,
					-size      => 20,
					-maxlength => 255,
					-class => "stdinput",
					-style => "width:820px",
				);
			print "</td></tr>";
			
				if (&enable_pass)
			{
				print "<tr><td style='text-align:left; width:100px'>Admin Password:</td><td>";
				print $qupload->password_field(
						-name      => 'pass',
						-value     => '',
						-size      => 20,
						-maxlength => 255,
						-class => "stdinput",
						-style => "width:820px",
					);
				print "</td></tr>";
			}
			
			print "<tr><td></td><td style='text-align:left'>";
			print $qupload->submit(
					-name     => 'submit_form',
					-value    => 'Upload Archive',
					-onsubmit => 'javascript: validate_form()',
					-class => 'stdbtn', 
				);
				
			print "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/>";
			

			print "</td></tbody></table>";
			print $qupload->end_form;
			
			print "</div>";
			
			
			
		}
	}
	else 
	{
		print "gib arguments";
	}

print $qupload->end_html;