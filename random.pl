#!/usr/bin/perl

use strict;
use CGI qw/:standard/;
use Redis;
use Encode;

#Require config 
require 'functions/functions_config.pl';

my $archive="";
my $archiveexists = 0;

#Default redis server location is localhost:6379. 
#Auto-reconnect on, one attempt every 100ms up to 2 seconds. Die after that.
my $redis = Redis->new(server => &get_redisad, 
						reconnect => 100,
						every     => 3000);

#We get a random archive ID. We check for the length to (sort-of) avoid not getting an archive ID.
#Shit's never been designed to work on a redis database where other keys would be lying around. 
#I should probably add a namespace or something?	
until ($archiveexists)
{
	$archive = $redis->randomkey();

	#We got a key, but does the matching archive still exist on the server? Better check it out.
	#This usecase only happens with the random selection : Regular index only parses the database for archive files it finds by default.

	if (length($archive)==64 && $redis->type($archive) eq "hash" && $redis->hexists($archive,"file"))
	{
		my $arclocation = $redis->hget($archive,"file");
		$arclocation = decode_utf8($arclocation);

		if (-e $arclocation)
			{ $archiveexists = 1; }
	}
}
	


#We redirect to the reader, with the key as parameter.
print redirect(-url=>'reader.pl?id='.$archive);