#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use File::Basename;

require 'config.pl';

my $qedit = new CGI;
print $qedit->header;
print $qedit->start_html
	(
	-title=>&get_htmltitle,
    -author=>'lanraragi-san',
    -style=>{'src'=>'./styles/ex.css'},					
	-head=>[Link({-rel=>'icon',-type=>'image/png',-href=>'favicon.ico'})],
	);
	
if ($qedit->param()) {
    # Parameters are defined, therefore something has been submitted...
	#is it POST?
	if ('POST' eq $qedit->request_method ) { # ty stack overflow 
		# It is, which means parameters for a rename have been passed. Let's get cracking!
		
		my $event = $qedit->param('event');
		my $artist = $qedit->param('artist');
		my $title = $qedit->param('title');
		my $series = $qedit->param('series');
		my $language = $qedit->param('language');
		my $tags = $qedit->param('tags');
		my $oldfilename = $qedit->param('filename');
		
		my $id = md5sum(&get_dirname.'/'.$oldfilename);
		#print $id;
		
		#clean up inputs
		removeSpace($event);
		removeSpace($artist);
		removeSpace($title);
		removeSpace($series);
		removeSpace($language);
		removeSpace($tags);
		
		#Create new filename.
		if ($event ne '')
			{$event = '('.$event.') ';}
		if ($artist ne '')
			{$artist = ' ['.$artist.'] ';}
		if ($series ne '')
			{$series = ' ('.$series.') ';}
		if ($language ne '')
			{$language = ' ['.$language.'] ';}
		
		#You can use the \Q and \E pair of escape sequences to stop and restart interpretation regular expression metacharacters.		
		#$title=\Q$title\E;
		
		my $newfilename = &get_dirname.'/'.$event.$artist.$title.$series.$language;
		removeSpace($newfilename);
		removeSpaceR($newfilename);
		$newfilename = $newfilename.'.zip';
		
		open (MYFILE, '>'.&get_dirname.'/tags/'.$id.'.txt');
		print MYFILE $tags;
		close (MYFILE); 
			
		#Maybe it already exists? Return an error if so.
		if (-e $newfilename)
			{
			print "<div class='ido' style='text-align:center'><h1>A file with the same name already exists in the library. Please change it before proceeding. <br/>Any tag editing you might've done has been applied. </h1><br/>";
			}
		else #good to go!
			{
			
			if (rename &get_dirname.'/'.$oldfilename, $newfilename) #rename returns 1 if successful, 0 otherwise.
				{print "<div class='ido' style='text-align:center'><h1>Edit Successful!</h1><br/>";}
			else
				{print "<div class='ido' style='text-align:center'><h1>The edit process failed for some reason. Maybe you don't have permission to rename files, or your filename hit the character limit.</h1><br/>";}
			}
			
		print "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/></div>";
		
	} else {
		# It's GET. That means we've only been given a file name. Generate the renaming form.
		#ToDo: Check for login?
	    
		#Does the passed file exist?
		my $test = $qedit->param('file');
		#print &get_dirname.'/'.$test.'.zip';
		if (-e (&get_dirname.'/'.$test.'.zip'))
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
	my $value = $_[0]->param('file');
	my ($event,$artist,$title,$series,$language,$tags,$id) = &parseName($value);

	print "<div class='ido' style='text-align:center'>";
	print $_[0]->h1({-class=>'ih', -style=>'text-align:center'},'Editing '.$title.' by '.$artist);
	print $_[0]->start_form;
	print "<table style='margin:auto'><tbody>";
	
	print "<tr><td style='text-align:left; width:100px'>Current File Name:</td><td>";
	print $_[0]->textfield(
			-name      => 'filename',
			-value     => $value.'.zip',
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:820px",
			-readonly,
			#-style='',
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
