#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use File::Basename;
use Redis;
use Encode;
use CGI::Ajax;

require 'config.pl';
require 'functions.pl';

my $qedit = new CGI;

#Bind the ajax function to the getThumb subroutine.
my $pjx = new CGI::Ajax( 'import_tags' => \&getTags );				   

my $html = start_html
	(
	-title=>&get_htmltitle.' - Edit Mode',
    -author=>'lanraragi-san',		
    -script=>{-type=>'JAVASCRIPT',
							-src=>'./js/css.js'},		
	-head=>[Link({-rel=>'icon',-type=>'image/png',-href=>'favicon.ico'})],
	-encoding => "utf-8",
	);

$html .= &printCssDropdown(0);
$html .= "<script>set_style_from_cookie();
				function updateTags(a) {
					document.getElementById('tagText').value=document.getElementById('tagText').value+a;
				}
			</script>";
	
if ($qedit->param()) {
    # Parameters are defined, therefore something has been submitted...	
	
	#Redis initialization.
	my $redis = Redis->new(server => &get_redisad, 
						reconnect => 100,
						every     => 3000);

	
	#Are the submitted arguments POST(and not the cgi:ajax ones)?
	my %params = $qedit->Vars;
	unless (exists $params{"fname"}){
		if ('POST' eq $qedit->request_method ) { # ty stack overflow 
		# It is, which means parameters for a rename have been passed. Let's get cracking!
		#Check for password first.
		my $pass = $qedit->param('pass');
		unless ((&enable_pass && ($pass eq &get_password)) || &enable_pass==0)
			{
			$html .= "<div class='ido' style='text-align:center'><h1>Wrong password.</h1><br/>";
			$html .= "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/></div>";
			}
		else
			{ 
			my $event = $qedit->param('event');
			my $artist = $qedit->param('artist');
			my $title = $qedit->param('title');
			my $series = $qedit->param('series');
			my $language = $qedit->param('language');
			my $tags = $qedit->param('tags');
			my $id = $qedit->param('id');
			
			#clean up the user's inputs.
			removeSpaceF($event);
			removeSpaceF($artist);
			removeSpaceF($title);
			removeSpaceF($series);
			removeSpaceF($language);
			removeSpaceF($tags);
			
			#Input new values into redis hash.
			#prepare the hash which'll be inserted.
			my %hash = (
					event => $event,
					artist => $artist,
					title => $title,
					series => $series,
					language => $language,
					tags => $tags
				);
				
			#for all keys of the hash, add them to the redis hash $id with the matching keys.
			$redis->hset($id, $_, $hash{$_}, sub {}) for keys %hash;
			$redis->wait_all_responses;
			&rebuild_index;
			$html .= "<div class='ido' style='text-align:center'><h1>Edit Successful!</h1><br/>";
				
			$html .= "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/></div>";
			
			}		
		} else {
			# It's GET. That means we've only been given a file id. Generate the renaming form.
		    
			#Does the passed file exist?
			my $id = $qedit->param('id');
			
			if ($redis->hexists($id,"title"))
			{
				$redis->quit();
				$html .=generateForm($qedit);	
			}
			else
				{
				$redis->quit();
				$html .= "<div class='ido' style='text-align:center'><h1>File not found. </h1><br/>";
				$html .= "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/></div>";
				}
		} 
	}
	else
	{
		#If this is an AJAX request, we get the tags and send them back.
		$html.= getTags($qedit->param('hashDiv'));
	}
} else {
    # No parameters back the fuck off
    $html .= "pls gib arguments";
}

$html .= end_html;

#We let CGI::Ajax print the HTML we specified in the $html .=Page sub, with the header options specified (utf-8)
print $pjx->build_html($qedit, $html,{-type => 'text/html', -charset => 'utf-8'});

sub getTags
	{
			
		#This rings up g.e-hentai with the SHA hash we obtained.
		my $queryJson = &getGalleryId($_[0]);
		#print $queryJson."<br/>";
		my $tags = &getTagsFromAPI($queryJson);

		unless ($tags eq(""))
			{
				return $tags;
			}	
		else
			{
				return "No tags found!";
			}
	}

sub generateForm
	{
	my $id = $_[0]->param('id');
	
	my $redis = Redis->new(server => &get_redisad, 
						reconnect => 100,
						every     => 3000);
						
	my %hash = $redis->hgetall($id);					
	my ($name,$event,$artist,$title,$series,$language,$tags,$file,$thumbhash) = @hash{qw(name event artist title series language tags file thumbhash)};
	($_ = decode_utf8($_)) for ($name, $event, $artist, $title, $series, $language, $tags, $file);


	my $html = "<div class='ido' style='text-align:center'>";
	if ($artist eq "")
		{$html .= $_[0]->h1({-class=>'ih', -style=>'text-align:center'},'Editing '.$title);}
	else
		{$html .= $_[0]->h1({-class=>'ih', -style=>'text-align:center'},'Editing '.$title.' by '.$artist);}
	$html .= $_[0]->start_form;
	$html .= "<table style='margin:auto'><tbody>";
	
	$html .= "<tr><td style='text-align:left; width:100px'>Current File Name:</td><td>";
	$html .= $_[0]->textfield(
			-name      => 'filename',
			-value     => $file,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:820px",
			-readonly,
		);
	$html .= "</td></tr>";
	
	$html .= "<tr><td style='text-align:left; width:100px'>ID:</td><td>";
	$html .= $_[0]->textfield(
			-name      => 'id',
			-id 	   => 'archiveID',
			-value     => $id,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:820px",
			-readonly,
		);
	$html .= "</td></tr>";
	
	$html .= "<tr><td style='text-align:left; width:100px'>Title:</td><td>";
	$html .= $_[0]->textfield(
			-name      => 'title',
			-value     => $title,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:820px",
		);
	$html .= "</td></tr>";
	
	$html .= "<tr><td style='text-align:left; width:100px'>Artist:</td><td>";
	$html .= $_[0]->textfield(
			-name      => 'artist',
			-value     => $artist,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:820px ",
		);
	$html .= "</td></tr>";
	
	$html .= "<tr><td style='text-align:left; width:100px'>Series:</td><td>";
	$html .= $_[0]->textfield(
			-name      => 'series',
			-value     => $series,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:820px",
		);
	$html .= "</td></tr>";
	
	$html .= "<tr><td style='text-align:left; width:100px'>Language:</td><td>";
	$html .= $_[0]->textfield(
			-name      => 'language',
			-value     => $language,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:820px",
		);
	$html .= "</td></tr>";
	
	$html .= "<tr><td style='text-align:left; width:100px'>Released at:</td><td>";
	$html .= $_[0]->textfield(
			-name      => 'event',
			-value     => $event,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:820px",
		);
	$html .= "</td></tr>";
	
	$html .="<div style='display:none' id='hashDiv' >".$thumbhash."</div>";
	#The button here calls the ajax function, which in turn calls the getTags sub.
	$html .= qq(<tr><td style='text-align:left; width:100px; vertical-align:top'>Tags:
			<input type='button' name='tag_import' value='Import E-Hentai&#x00A; Tags' onclick="import_tags(['hashDiv'], [updateTags]);" 
			class='stdbtn' style='margin-top:25px;max-width:100px;height:50px '>
			</td><td>);
	$html .= $_[0]->textarea(
			-name      => 'tags',
			-id  	   => 'tagText',
			-value     => $tags,
			-size      => 20,
			-maxlength => 5000,
			-class => "stdinput",
			-style => "width:820px; height:300px",
		);
	$html .= "</td></tr>";
	
		if (&enable_pass)
	{
		$html .= "<tr><td style='text-align:left; width:100px'>Admin Password:</td><td>";
		$html .= $_[0]->password_field(
				-name      => 'pass',
				-value     => '',
				-size      => 20,
				-maxlength => 255,
				-class => "stdinput",
				-style => "width:820px",
			);
		$html .= "</td></tr>";
	}
	
	$html .= "<tr><td></td><td style='text-align:left'>";
	$html .= $_[0]->submit(
			-name     => 'submit_form',
			-value    => 'Edit Archive',
			-onsubmit => 'javascript: validate_form()',
			-class => 'stdbtn', 
		);
	$html .= "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/>";
	

	$html .= "</td></tbody></table>";
	$html .= $_[0]->end_form;
	
	$html .= "</div>";
	$redis->quit();
	return $html;
	}
