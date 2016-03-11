#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use Redis;

require 'config.pl';
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


	print $qreader->header(-type => 'text/html',
                   -charset => 'utf-8');
	
	print $qreader->start_html
	(
	-title=>$arcname,
	-author=>'lanraragi-san',	
	-script=>[{-type=>'JAVASCRIPT',
						-src=>'./js/css.js'},
			  {-type=>'JAVASCRIPT',
						-src=>'./bower_components/jquery/dist/jquery.min.js'},
			  {-type=>'JAVASCRIPT',
						-src=>'./bower_components/jQuery-rwdImageMaps/jquery.rwdImageMaps.min.js'}],				
	-head=>[Link({-rel=>'icon', -type=>'image/png', -href=>'favicon.ico'}),
			meta({-name=>'viewport', -content=>'width=device-width'})],		
	-encoding => "utf-8",
	-style=>[{'src'=>'./styles/lrr.css'},
			{'src'=>'./bower_components/font-awesome/css/font-awesome.min.css'}],
	-onload=> "
				//dynamic html imagemap magic
				\$('img[usemap]').rwdImageMaps();
				set_style_from_storage();
				",
	);
	
	my $force = $qreader->param('force-reload');
	my $thumbreload = $qreader->param('reload_thumbnail');
	my $imgpath = "";
	my $arcpages = 0;

	if ($qreader->param('page')) 
		{ 
			($imgpath, $arcpages) = &getImage($id,$force,$thumbreload,$qreader->param('page'));
			print &printReaderHTML($id,$imgpath,$arcname,$arcpages,$qreader->param('page'));  #$imgpath is the path to the image we want to display, $arcpages is the total number of pages in the archive.
		}
	else
	 	{ 
	 		($imgpath, $arcpages) = &getImage($id,$force,$thumbreload); 
	 		print &printReaderHTML($id,$imgpath,$arcname,$arcpages);
	 	}
	
} 
else 
{
    # No parameters back the fuck off
    print &redirectToPage($qreader,"index.pl");
}

print $qreader->end_html;