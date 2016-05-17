#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use Redis;
use Template;
use Encode;
use utf8;

#Import config and functions
require 'functions/functions_config.pl';
require 'functions/functions_generic.pl';
require 'functions/functions_login.pl';

my $qtags = new CGI;
my $tt  = Template->new({
        INCLUDE_PATH => "templates",
        #ENCODING => 'utf8' 
    });

my $redis = &getRedisConnection();
my $title = "";
my $id = "";
my $arclist = "";

#Before anything, check if the user is logged in. If not, redirect him to login.pl?redirect=edit.pl
if (&isUserLogged($qtags))
	{

		#Fill the list with archives by looking up in redis
		my @keys = $redis->keys( '????????????????????????????????????????????????????????????????' ); #64-character long keys only => Archive IDs 

		#Parse the archive list and add <li> elements accordingly.
		foreach $id (@keys)
		{
			if ($redis->hexists($id,"title")) 
				{
					$title = $redis->hget($id,"title");
					$title = decode_utf8($title);
					
					#If the archive has no tags, pre-check it in the list.

					if ($redis->hget($id,"tags") eq "")
						{ $arclist .= "<li><input type='checkbox' name='archive' id='$id' checked><label for='$id'> $title</label></li>"; }
					else
						{ $arclist .= "<li><input type='checkbox' name='archive' id='$id' ><label for='$id'> $title</label></li>"; }
				}
		}

		$redis->quit();

		#Print the form for launching batch tagging.
		print $qtags->header(-type    => 'text/html',
                   -charset => 'utf-8');

		my $out;

		$tt->process(
	        "tags.tmpl",
	        {
	            title => &get_htmltitle,
	            cssdrop => &printCssDropdown(0),
	            arclist => $arclist,
	        },
	        \$out,
	    ) or die $tt->error;

	    print $out;

	}
else
	{
		#Not logged in, redirect
		print &redirectToPage($qtags,"login.pl");

	}