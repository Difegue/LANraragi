#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use File::Basename;
use Redis;
use Encode;
use Template;
use utf8;

#Require config 
require 'functions/functions_config.pl';
require 'functions/functions_generic.pl';
require 'functions/functions_login.pl';
require 'functions/functions_edit.pl';

my $qedit = new CGI;	
my $tt  = Template->new({
        INCLUDE_PATH => "templates",
        #ENCODING => 'utf8' 
    });

	
#Before anything, check if the user is logged in. If not, redirect him to login.pl
if (&isUserLogged($qedit) && $qedit->param() )
	{
			
		#Redis initialization.
		my $redis = &getRedisConnection();

		#Three cases, depending on the request type:
		
		#DELETE: Delete archive
		if ('DELETE' eq $qedit->request_method ) { 

			my $id = $qedit->param('id');

			# Return type will be JSON.
			print $qedit->header(-type    => 'application/json',
	                   				-charset => 'utf-8');

			my $delStatus = &deleteArchive($id);

			print qq({
						"id":"$id",
						"operation":"delete",
						"success":"$delStatus"
					 });

		}

		#POST: Edit archive metadata
		if ('POST' eq $qedit->request_method ) { 

			# Return type will be JSON.
			print $qedit->header(-type    => 'application/json',
                   					-charset => 'utf-8');
			 
			my $id = $qedit->param('id');
			my $event = $qedit->param('event');
			my $artist = $qedit->param('artist');
			my $title = $qedit->param('title');
			my $series = $qedit->param('series');
			my $language = $qedit->param('language');
			my $tags = $qedit->param('tags');

			#clean up the user's inputs and encode them.
			(removeSpaceF($_)) for ($event, $artist, $title, $series, $language, $tags);

			#Input new values into redis hash.
			#prepare the hash which'll be inserted.
			my %hash = (
					event => encode_utf8($event),
					artist => encode_utf8($artist),
					title => encode_utf8($title),
					series => encode_utf8($series),
					language => encode_utf8($language),
					tags => encode_utf8($tags)
				);
				
			#for all keys of the hash, add them to the redis hash $id with the matching keys.
			$redis->hset($id, $_, $hash{$_}, sub {}) for keys %hash;
			$redis->wait_all_responses;
			
			print qq({
						"id":"$id",
						"operation":"edit",
						"success":"1"
					 });
							
		} 

		#GET: Print metadata edition form
		if ('GET' eq $qedit->request_method ) { 

			#Does the passed file exist in the database?
			my $id = $qedit->param('id');

			if ($redis->hexists($id,"title")) 
			{
				print $qedit->header(-type    => 'text/html',
               						-charset => 'utf-8');

				my $redis = Redis->new(server => &get_redisad, 
						reconnect => 100,
						every     => 3000);
						
				my %hash = $redis->hgetall($id);					
				my ($name,$event,$artist,$title,$series,$language,$tags,$file,$thumbhash) = @hash{qw(name event artist title series language tags file thumbhash)};
				($_ = decode_utf8($_)) for ($name, $event, $artist, $title, $series, $language, $tags, $file);

				$redis->quit();

				my $out;

				$tt->process(
			        "edit.tmpl",
			        {
			        	id => $id,
			            name => $name,
			            event => $event,
			            artist => $artist,
			            arctitle => $title,
			            series => $series,
			            language => $language,
			            tags => $tags,
			            file => $file,
			            thumbhash => $thumbhash,
			            title => &get_htmltitle,
			            cssdrop => &printCssDropdown(0),

			        },
			        \$out,
			    ) or die $tt->error;

			    print $out;

			}
			else 
			{ print &redirectToPage($qedit,"index.pl"); }

		} 

		$redis->quit();

	}
else
	{
		#Not logged in or no parameters, redirect
		print &redirectToPage($qedit,"login.pl");

	}




