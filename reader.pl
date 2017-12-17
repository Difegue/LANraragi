#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use Redis;
use Template;

require 'functions/functions_config.pl';
require 'functions/functions_generic.pl';
require 'functions/functions_reader.pl';


	my $qreader = new CGI;

	if ($qreader->param()) 
	{
	    # We got a file name, let's get crackin'.
		my $id = $qreader->param('id');

		#Quick Redis check to see if the ID exists:
		my $redis = &getRedisConnection();

		unless ($redis->hexists($id,"title"))
			{
				print &redirectToPage($qreader,"index.pl");
				exit;
			}

		#Get a computed archive name if the archive exists
		my $artist = $redis->hget($id,"artist");
		my $arcname = $redis->hget($id,"title");

		unless ($artist =~ /^\s*$/)
			{$arcname = $arcname." by ".$artist; }
			
		$arcname = decode_utf8($arcname);
	
		my $force = $qreader->param('force_reload');
		my $thumbreload = $qreader->param('reload_thumbnail');
		my $imgpaths = "";

		print $qreader->header(-type    => 'text/html',
               					-charset => 'utf-8');

		#Load a json matching pages to paths
		$imgpaths = &buildReaderData($id,$force,$thumbreload);
		&printReaderHTML($id,$imgpaths,$arcname,$qreader);  
		
	} 
	else 
	{
	    # No parameters back the fuck off
	    print &redirectToPage($qreader,"index.pl");
	}