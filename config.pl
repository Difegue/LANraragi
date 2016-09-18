#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use File::Basename;
use Redis;
use Encode;
use Template; 
use Authen::Passphrase::BlowfishCrypt;

#Require config 
require 'functions/functions_config.pl';
require 'functions/functions_generic.pl';
require 'functions/functions_login.pl';

my $qconfig = new CGI;	
my $tt  = Template->new({
        INCLUDE_PATH => "templates",
        #ENCODING => 'utf8' 
    });

	
#Utter ripoff of the edit page because it just werks
#Before anything, check if the user is logged in. If not, redirect him to login.pl
if (&isUserLogged($qconfig))
	{
			
		#Redis initialization.
		my $redis = &getRedisConnection();

		#If we got a POST, it's for setting new config settings.
		if ('POST' eq $qconfig->request_method ) { 

			my $success = 1;
			my $errormess = "";

			# Return type will be JSON.
			print $qconfig->header(-type    => 'application/json',
                   					-charset => 'utf-8');
			
			my %confhash = (
				htmltitle => scalar $qconfig->param('htmltitle'),
				motd => scalar $qconfig->param('motd'),
				dirname => scalar $qconfig->param('dirname'),
				pagesize => scalar $qconfig->param('pagesize'),
				readorder => (scalar $qconfig->param('readorder') ? '1' : '0'), #for checkboxes, we check if the parameter exists in the POST to return either 1 or 0.
				enablepass => (scalar $qconfig->param('enablepass') ? '1' : '0'), 
				enableresize => (scalar $qconfig->param('enableresize') ? '1' : '0'),
				sizethreshold => scalar $qconfig->param('sizethreshold'),
				readerquality => scalar $qconfig->param('readerquality'),
			);
			
			#only add newpassword field as password if enablepass = 1
			if ($qconfig->param('enablepass'))
				{ 

					#hash password with authen
					my $password = $qconfig->param('newpassword');
					my $ppr = Authen::Passphrase::BlowfishCrypt->new(
					    cost        => 8,
					    salt_random => 1,
					    passphrase  => $password,
					);

					my $pass_hashed = $ppr->as_rfc2307;
					$confhash{password} = $pass_hashed; 

				}

		
			#Verifications.
			if ($qconfig->param('newpassword') ne $qconfig->param('newpassword2')) #Password check
				{ 
					$success = 0;
				 	$errormess = "Mismatched passwords.";
				}

			if ($confhash{pagesize} =~ /\D+/ || $confhash{sizethreshold} =~ /\D+/ || $confhash{readerquality} =~ /\D+/ ) #Numbers only in fields w. numbers
				{
					$success = 0;
					$errormess = "Invalid characters.";
				}

			#Did all the checks pass ?
			if ($success)
			{
				#clean up the user's inputs for non-toggle options and encode for redis insertion
				foreach my $key (keys %confhash) 
					{ 
						removeSpaceF($confhash{$key}); 
						encode_utf8($confhash{$key});
					}

				#for all keys of the hash, add them to the redis config hash with the matching keys.
				$redis->hset("LRR_CONFIG", $_, $confhash{$_}, sub {}) for keys %confhash;
				$redis->wait_all_responses;
			}

			print qq({
						"operation":"config",
						"success":"$success",
						"message":"$errormess"
					 });
							
		} 

		#GET: Grab current configuration and print config form
		if ('GET' eq $qconfig->request_method ) 
			{ 	
				print $qconfig->header(-type    => 'text/html',
               						-charset => 'utf-8');

				#Get config values and put them in the template
				my $out;

				$tt->process(
			        "config.tmpl",
			        {
			            motd => &get_motd,
			            dirname => &get_dirname,
			            pagesize => &get_pagesize,
			            readorder => &get_readorder,
			            enablepass => &enable_pass,
			            password => &get_password,
			            enableresize => &enable_resize,
			            sizethreshold => &get_threshold,
			            readerquality => &get_quality,
			            title => &get_htmltitle,
			            cssdrop => &printCssDropdown(0),

			        },
			        \$out,
			    ) or die $tt->error;

			    print $out;


			} 

		$redis->quit();

	}
else
	{
		#Not logged in, redirect
		print &redirectToPage($qconfig,"login.pl");

	}