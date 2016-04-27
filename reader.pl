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
		my $redis = Redis->new(server => &get_redisad, 
					reconnect => 100,
					every     => 3000);

		unless ($redis->hexists($id,"title"))
			{
				print &redirectToPage($qreader,"index.pl");
				exit;
			}

		#Get a computed archive name if the archive exists
		my $arcname = $redis->hget($id,"title")." by ".$redis->hget($id,"artist");
		$arcname = decode_utf8($arcname);
	
		my $force = $qreader->param('force_reload');
		my $thumbreload = $qreader->param('reload_thumbnail');
		my $imgpath = "";
		my $arcpages = 0;

		print $qreader->header(-type    => 'text/html',
               					-charset => 'utf-8');

		if ($qreader->param('page')) 
			{ 
				my $page = $qreader->param('page');
				($imgpath, $arcpages) = &getImage($id,$force,$thumbreload,$page);
				&printReaderHTML($id,$imgpath,$arcname,$arcpages,$page);  #$imgpath is the path to the image we want to display, $arcpages is the total number of pages in the archive.
			}
		else
		 	{ 
		 		($imgpath, $arcpages) = &getImage($id,$force,$thumbreload);
		 		&printReaderHTML($id,$imgpath,$arcname,$arcpages);
		 	}
		
	} 
	else 
	{
	    # No parameters back the fuck off
	    print &redirectToPage($qreader,"index.pl");
	}