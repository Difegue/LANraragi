#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use File::Basename;
use Redis;
use Encode;

require 'config.pl';

my $qedit = new CGI;
print $qedit->header(-type    => 'text/html',
                   -charset => 'utf-8');
				   
print $qedit->start_html
	(
	-title=>&get_htmltitle.' - Edit Mode',
    -author=>'lanraragi-san',
    -style=>{'src'=>'./styles/'.&get_style},					
	-head=>[Link({-rel=>'icon',-type=>'image/png',-href=>'favicon.ico'})],
	-encoding => "utf-8",
	);
	
if ($qedit->param()) {
    # Parameters are defined, therefore something has been submitted...	
	
	#Redis initialization.
	my $redis = Redis->new(server => &get_redisad, 
						reconnect => 100,
						every     => 3000);

	
	#Are the submitted arguments POST?
	if ('POST' eq $qedit->request_method ) { # ty stack overflow 
	# It is, which means parameters for a rename have been passed. Let's get cracking!
	#Check for password first.
	my $pass = $qedit->param('pass');
	unless (&enable_pass && ($pass eq &get_password))
		{
		print "<div class='ido' style='text-align:center'><h1>Wrong password.</h1><br/>";
		print "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/></div>";
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
		print "<div class='ido' style='text-align:center'><h1>Edit Successful!</h1><br/>";
			
		print "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/></div>";
		}
		
	} else {
		# It's GET. That means we've only been given a file id. Generate the renaming form.
	    
		#Does the passed file exist?
		my $id = $qedit->param('id');
		
		if ($redis->hexists($id,"title"))
		{
			generateForm($qedit);	
		}
		else
			{
			print "<div class='ido' style='text-align:center'><h1>File not found. </h1><br/>";
			print "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/></div>";
			}
	} 
} else {
    # No parameters back the fuck off
    print $qedit->redirect('./');
}

print $qedit->end_html;



sub generateForm
	{
	my $id = $_[0]->param('id');
	
	my $redis = Redis->new(server => &get_redisad, 
						reconnect => 100,
						every     => 3000);
						
	my %hash = $redis->hgetall($id);					
	my ($name,$event,$artist,$title,$series,$language,$tags,$file) = @hash{qw(name event artist title series language tags file)};
	($_ = decode_utf8($_)) for ($name, $event, $artist, $title, $series, $language, $tags, $file);

	print "<div class='ido' style='text-align:center'>";
	if ($artist eq "")
		{print $_[0]->h1({-class=>'ih', -style=>'text-align:center'},'Editing '.$title);}
	else
		{print $_[0]->h1({-class=>'ih', -style=>'text-align:center'},'Editing '.$title.' by '.$artist);}
	print $_[0]->start_form;
	print "<table style='margin:auto'><tbody>";
	
	print "<tr><td style='text-align:left; width:100px'>Current File Name:</td><td>";
	print $_[0]->textfield(
			-name      => 'filename',
			-value     => $file,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:820px",
			-readonly,
		);
	print "</td></tr>";
	
	print "<tr><td style='text-align:left; width:100px'>ID:</td><td>";
	print $_[0]->textfield(
			-name      => 'id',
			-value     => $id,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:820px",
			-readonly,
		);
	print "</td></tr>";
	
	print "<tr><td style='text-align:left; width:100px'>Title:</td><td>";
	print $_[0]->textfield(
			-name      => 'title',
			-value     => $title,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:820px",
		);
	print "</td></tr>";
	
	print "<tr><td style='text-align:left; width:100px'>Artist:</td><td>";
	print $_[0]->textfield(
			-name      => 'artist',
			-value     => $artist,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:820px ",
		);
	print "</td></tr>";
	
	print "<tr><td style='text-align:left; width:100px'>Series:</td><td>";
	print $_[0]->textfield(
			-name      => 'series',
			-value     => $series,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:820px",
		);
	print "</td></tr>";
	
	print "<tr><td style='text-align:left; width:100px'>Language:</td><td>";
	print $_[0]->textfield(
			-name      => 'language',
			-value     => $language,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:820px",
		);
	print "</td></tr>";
	
	print "<tr><td style='text-align:left; width:100px'>Released at:</td><td>";
	print $_[0]->textfield(
			-name      => 'event',
			-value     => $event,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:820px",
		);
	print "</td></tr>";
	
	print "<tr><td style='text-align:left; width:100px; vertical-align:top'>Tags:</td><td>";
	print $_[0]->textarea(
			-name      => 'tags',
			-value     => $tags,
			-size      => 20,
			-maxlength => 5000,
			-class => "stdinput",
			-style => "width:820px; height:300px",
		);
	print "</td></tr>";
	
		if (&enable_pass)
	{
		print "<tr><td style='text-align:left; width:100px'>Admin Password:</td><td>";
		print $_[0]->password_field(
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
	print $_[0]->submit(
			-name     => 'submit_form',
			-value    => 'Edit Archive',
			-onsubmit => 'javascript: validate_form()',
			-class => 'stdbtn', 
		);
	print "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/>";
	

	print "</td></tbody></table>";
	print $_[0]->end_form;
	
	print "</div>";
	}
