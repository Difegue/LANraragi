#!/usr/bin/perl

use strict;
use CGI qw/:standard/;
use Redis;

#Require config 
require 'functions/functions_config.pl';

my $archive="";

#Default redis server location is localhost:6379. 
#Auto-reconnect on, one attempt every 100ms up to 2 seconds. Die after that.
my $redis = Redis->new(server => &get_redisad, 
						reconnect => 100,
						every     => 3000);
	
#We get a random archive ID. We check for the length to (sort-of) avoid not getting an archive ID.
#Shit's never been designed to work on a redis database where other keys would be lying around. 
#I should probably add a namespace or something?	
until (length($archive)==64)
{
	$archive = $redis->randomkey();
}
	
#We redirect to the reader, with the key as parameter.
print redirect(-url=>'reader.pl?id='.$archive);