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
	if ('POST' eq $qedit->request_method ) { #&& $c->param('dl') ty stack overflow 
		# It is, which means parameters for a rename have been passed. Let's get cracking!
	} else {
		# It's GET. That means we've only been given a file name. Generate the renaming form.
	    generateForm($qedit);	
	}
} else {
    # No parameters back the fuck off
    print $qedit->redirect('./');
}

print $qedit->end_html;



sub generateForm
	{
	my $value = $_[0]->param('file');
	my ($event,$artist,$title,$series,$language,$tags) = &parseName($value);

	print "<div class='ido' style='text-align:center'>";
	print $_[0]->h1({-class=>'ih', -style=>'text-align:center'},'Editing '.$value);
	print $_[0]->start_form;
	
	print "Title:";
	print $_[0]->textfield(
			-name      => 'title',
			-value     => $title,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:820px",
		);
	print "</br>";
	
	print "Artist:";
	print $_[0]->textfield(
			-name      => 'artist',
			-value     => $artist,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:820px ",
		);
	print "</br>";
	
	print "Series:";
	print $_[0]->textfield(
			-name      => 'series',
			-value     => $series,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:820px",
		);
	print "</br>";
	
	print "Language:";
	print $_[0]->textfield(
			-name      => 'language',
			-value     => $language,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:820px",
		);
	print "</br>";
	
	print "Released at:";
	print $_[0]->textfield(
			-name      => 'event',
			-value     => $event,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:820px",
		);
	print "</br>";
	
	print "Tags:";
	print $_[0]->textfield(
			-name      => 'tags',
			-value     => $tags,
			-size      => 20,
			-maxlength => 5000,
			-class => "stdinput",
			-style => "width:820px",
		);
	print "</br>";
	
	print $_[0]->submit(
			-name     => 'submit_form',
			-value    => 'Edit Archive',
			-onsubmit => 'javascript: validate_form()',
			-class => 'stdbtn', 
		);
		
	print $_[0]->end_form;
	print "</div>";
	}
