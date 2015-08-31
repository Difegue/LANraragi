#!/usr/bin/perl

#ajax calls possible:
#?function=thumbnail&id=xxxxxx
#?function=tags&ishash=0/1&input=xxxxxx

use strict;
use CGI qw(:standard);

require 'config.pl';
require 'functions.pl';

#set up cgi for receiving ajax calls
my $qajax = new CGI;
print $qajax->header('text/plain');

#Is this a call? 
if ($qajax->param())
{

	my $call = $qajax->param('function');

	if ($call eq "thumbnail")
		{
			my $id = $qajax->param('id');
			print &getThumb($id); #getThumb is in functions.pl.
		}

	if ($call eq "tags")
		{
			my $ishash = $qajax->param('ishash');
			my $input = $qajax->param('input');
			my $queryJson;

			#This rings up g.e-hentai with the input we obtained.
			$queryJson = &getGalleryId($input,$ishash); #getGalleryId is in functions.pl.

			#Call the actual e-hentai API with the json we created and grab dem tags
			my $tags = &getTagsFromAPI($queryJson);

			unless ($tags eq(""))
				{
					print $tags;
				}	
			else
				{
					print "NOTAGS";
				}
		}


}
else
{
	print "nothing to see here welp"
}


	
