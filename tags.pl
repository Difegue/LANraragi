#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use File::Basename;
use LWP::Simple;
use LWP::UserAgent;
use utf8;
use JSON;

require 'config.pl';

my $qupload = new CGI;
print $qupload->header;
print $qupload->start_html
	(
	-title=>&get_htmltitle." - Tag Importer/Exporter",
    -author=>'lanraragi-san',
    -style=>{'src'=>'./styles/ex.css'},					
	-head=>[Link({-rel=>'icon',-type=>'image/png',-href=>'favicon.ico'})],
	-encoding => "utf-8",
	);

#http://g.e-hentai.org/?f_doujinshi=1&f_manga=1&f_artistcg=1&f_gamecg=1&f_western=1&f_non-h=1&f_imageset=1&f_cosplay=1&f_asianporn=1&f_misc=1&f_search=Search+Keywords&f_apply=Apply+Filter&f_shash=F316F69594D3E21910367085E9136591D8D3E212&fs_similar=1

#Search g.e-hentai for the provided image hash, and return the tags in a string.
sub EHSearch_Hash
	{
	my $content = get('http://g.e-hentai.org/?f_doujinshi=1&f_manga=1&f_artistcg=1&f_gamecg=1&f_western=1&f_non-h=1&f_imageset=1&f_cosplay=1&f_asianporn=1&f_misc=1&f_search=Search+Keywords&f_apply=Apply+Filter&f_shash='.$_[0].'&fs_similar=1') or die 'Unable to get page';
	
	#$content is a full web page. But it contains the gallery ID we'll pass to the JSON API afterwards. Let's look for it:
	$content =~ m/g\/xxxx\/yyyyy/;
	
	#GID needs to be in a xxxx/"yyyyy" format. Regex!
	
	#Now that we have the GID, let's call the E-H API.
	my $uri = 'http://g.e-hentai.org/api.php';
	my $json = '{"method": "gdata", "gidlist": [['.$GID.']]}';
	my $req = HTTP::Request->new( 'POST', $uri );
	$req->header( 'Content-Type' => 'application/json' );
	$req->content( $json );

	my $lwp = LWP::UserAgent->new;
	my $json = $lwp->request( $req );
	
	#Let's parse the JSON output:
	my $decoded = decode_json($json);
	
	return $decoded->{'gmetadata'}{'tags'};
	
	}
	
if ($qupload->param()) {
    # Parameters are defined, therefore something has been submitted...	
	
	#Are the submitted arguments POST?
	if ('POST' eq $qupload->request_method )
		{
		#let's do eet
		
		#Check if password is correct first.
		my $pass = $qupload->param('pass');
		unless (&enable_pass && ($pass eq &get_password))
			{
			print "<div class='ido' style='text-align:center'><h1>Wrong password.</h1><br/>";
			print "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/>";
			print "<input class='stdbtn' type='button' onclick=\"window.location.replace('./upload.pl');\" value='Upload another Gallery'/></div>";
			}
		else
			{ 
			#Search for the mentioned hash, get 
			}
		}
}
else
{
	#Print the upload form.
	
	print "<div class='ido' style='text-align:center'>";
	print $qupload->h1( {-class=>'ih', -style=>'text-align:center'},"Import Tags from g.e-hentai.org");
	print $qupload->start_form;
	print "<table style='margin:auto'><tbody>";
	
	print "<tr><td style='text-align:left; width:100px'>Select File:</td><td>";
	print $qupload->filefield(
			-name      => 'file',
			-size      => 20,
			-maxlength => 255,
			-style => "width:820px",
			-readonly,
			#-style='',
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

print $qupload->end_html;