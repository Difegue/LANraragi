#!/usr/bin/perl

use strict;
use CGI;
use File::Basename;

require 'config.pl';

sub generateForm
	{
	my $qformget = new CGI;
	my $value = $qformget->param('file');
	my ($event,$artist,$title,$series,$language,$tags) = &parseName($value);

	my $qform = new CGI;
	print $qform->start_form;

	print $qform->p("Title:");
	print $qform->textfield(
			-name      => 'title',
			-value     => $title,
			-size      => 20,
			-maxlength => 5000,
		);
		
	print $qform->p("Title:");
	print $qform->textfield(
			-name      => 'artist',
			-value     => $artist,
			-size      => 20,
			-maxlength => 5000,
		);
		
	print $qform->p("Title:");
	print $qform->textfield(
			-name      => 'series',
			-value     => $series,
			-size      => 20,
			-maxlength => 5000,
		);
		
	print $qform->p("Title:");
	print $qform->textfield(
			-name      => 'language',
			-value     => $language,
			-size      => 20,
			-maxlength => 5000,
		);
		
	print $qform->p("Title:");
	print $qform->textfield(
			-name      => 'event',
			-value     => $event,
			-size      => 20,
			-maxlength => 5000,
		);

	print $qform->p("Title:");
	print $qform->textfield(
			-name      => 'tags',
			-value     => $tags,
			-size      => 20,
			-maxlength => 5000,
		);

	print $qform->submit(
			-name     => 'submit_form',
			-value    => 'Edit Archive',
			-onsubmit => 'javascript: validate_form()',
		);
		
	print $qform->end_form;
	}

#Removes spaces if present before a non-space character.
sub removeSpace
	{
	until (substr($_[0],0,1)ne" "){
			$_[0] = substr($_[0],1);}
	}

sub parseName
	{
		my ($event,$artist,$title,$series,$language,$tags) = (" "," "," "," "," "," ");
		my @values=(" "," ");
		my $temp=$_[0];
		#Split up the filename
		#Is the field present? If not, skip it.
		if (substr($temp, 0, 1)eq'(') 
			{
			@values = split('\)', $temp, 2); # (Event)
			$event = substr($values[0],1);
			$temp = $values[1];
			}
		removeSpace($temp);
			
		if (substr($temp, 0, 1)eq"[") 
			{
			@values = split(']', $temp, 2); # [Artist (Pseudonym)]
			$artist = substr($values[0],1);
			$temp = $values[1];
			}
		removeSpace($temp);
			
		#Always needs something in title, so it can't be empty
		@values = split('\(', $temp, 2); #Title. If there's no following (Series), the entire filename is taken and other variables are emptied by default. ┐(￣ー￣)┌
		$title = $values[0];
		$temp = $values[1];
		
		removeSpace($temp);
		
		@values = split('\)', $temp, 2); #Series
		$series = $values[0];
		$temp = $values[1];

		removeSpace($temp);
		
		@values = split(']', $temp, 2); #Language
		$language = substr($values[0],1);
		$temp = $values[1];

		removeSpace($temp);		

		#does the filename contain tags?
		if (substr($temp, 0, 1)eq"%") 
		{
			$tags = substr($temp,1); #only tags left
		}
		
		return ($event,$artist,$title,$series,$language,$tags);
	}
