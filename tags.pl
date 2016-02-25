#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use utf8;
use Redis;

#Import config and functions
require 'config.pl';
require 'functions/functions_generic.pl';
require 'functions/functions_login.pl';

my $qtags = new CGI;

my $redis = Redis->new(server => &get_redisad, 
						reconnect => 100,
						every     => 3000);
my $title = "";
my $hash = "";
my $id = "";

#Before anything, check if the user is logged in. If not, redirect him to login.pl?redirect=edit.pl
if (&isUserLogged($qtags))
	{

		print $qtags->header(-type    => 'text/html',
                   -charset => 'utf-8');
		print $qtags->start_html
			(
			-title=>&get_htmltitle.' - Batch Tagging',
		    -author=>'lanraragi-san',		
		    -style=>[{'src'=>'./bower_components/font-awesome/css/font-awesome.min.css'}],
		    -script=>[{-type=>'JAVASCRIPT',
									-src=>'./js/css.js'},
					  {-type=>'JAVASCRIPT',
									-src=>'./js/ajax.js'},
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

		print &printCssDropdown(0);


		#Print the form for launching batch tagging.

		print "<div class='ido' style='text-align:center'>
				<h2 class='ih' style='text-align:center'>Batch Tagging</h2>
				<br><br>
				<table style='margin-left:auto; margin-right:auto; width:60%'>
					<tbody>

					<tr>
					<td style='text-align:center; width:200px; vertical-align:top'>

						<br>
						You can apply reverse tag research to multiple archives here.<br><br>
						Reverse tag searching leverages the E-Hentai API to find tags for your archives using their title or the hash of their first image. <br><br>
						Check the archives for which you want to search, and click on the button with the method you want to use.<br> Archives with no tags have been pre-checked.<br><br>
						<b>Important</b>: Since this not only leverages the API but also uses g.e-hentai for searches, tagging more than 150 archives at once might get you tempbanned for excessive pageloads.  


						<input type='button' style='margin-top:25px;min-width:50px; max-width:150px;height:60px' value='Global Reverse &#x00A;Tag Research &#x00A;(Using Archive Titles)' class='stdbtn' onclick='massTag(0)'>

						<input type='button' style='margin-top:25px;min-width:50px; max-width:150px;height:60px' value='Global Reverse &#x00A;Tag Research &#x00A;(Using Image Hashes)' class='stdbtn' onclick='massTag(1)'>

					</td>

					<td>
						<table class='itg' style='box-shadow: none; border:none'>
						<tbody>
						<td>
						<ul class='checklist caption' style='height: 380px; overflow: auto; list-style: none outside none; text-align: left; width: 100%; padding-left: 5px; margin-left: 10px;'>
						";

		#Fill the list with archives by looking up in redis
		my @keys = $redis->keys( '????????????????????????????????????????????????????????????????' ); #64-character long keys only => Archive IDs 

		#Parse the archive list and add <li> elements accordingly.
		foreach $id (@keys)
		{
			if ($redis->hexists($id,"title")) 
				{
					$title = $redis->hget($id,"title");
					$hash = $redis->hget($id,"thumbhash");
					#If the archive has no tags, pre-check it in the list.

					if ($redis->hget($id,"tags") eq "")
						{print "<li><input type='checkbox' name='archive' id='$id' hash='$hash' checked><label for='$id'> $title</label></li>"; }
					else
						{print "<li><input type='checkbox' name='archive' id='$id'hash ='$hash'><label for='$id'> $title</label></li>"; }

				}


		}

		$redis->quit();

		print "			</ul>
					    </td>
					    </tbody>
					    </table>
						

						
					</td>
					</tr>


					</tbody>
				</table>
				<br><br>
				<div id='processing' style='display:none'>
					<i class='fa fa-3x fa-cog fa-spin' style='display:none, margin-top:20px' id='tag-spinner'></i>
					<h3 id='processedArchive'>Processing </h3>
				</div>

			   </div>";



	}
else
	{
		#Not logged in, redirect
		print &redirectToPage($qtags,"login.pl");

	}