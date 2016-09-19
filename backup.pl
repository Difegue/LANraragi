#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use Template;
use utf8;

#Import config and functions
require 'functions/functions_config.pl';
require 'functions/functions_generic.pl';
require 'functions/functions_login.pl';
require 'functions/functions_backup.pl';

my $qbck = new CGI;
my $tt  = Template->new({
        INCLUDE_PATH => "templates",
        #ENCODING => 'utf8' 
    });

#Before anything, check if the user is logged in. If not, redirect him to login.pl
if (&isUserLogged($qbck))
	{

		if ($qbck->param()) {

		    # If it's POST, it's a restore.
		    if ('POST' eq $qbck->request_method ) 
		    { 

		    	my $filename = $qbck->param('file');
				my $uploadMime = $qbck->uploadInfo($filename)->{'Content-Type'};

				if ($uploadMime eq "application/json") 
				{

					my ($bytesread, $buffer);
					my $numbytes = 1024;
					my $json;

					while ($bytesread = read($filename, $buffer, $numbytes)) 
						{ $json .= $buffer; } #Write the uploaded contents to that file.

					&restoreFromJSON($json);

					print qq({ "success":1 });
				}
				else
				{
					print qq({ "success":0, "error":"Not a JSON file." });
				}
				

			}
			else
			{
				#GET with a parameter => do backup

				print $qbck->header(-type => 'application/json',
                   					-charset => 'utf-8',
                   					-'Content-Disposition'=>'attachment; filename="backup.json"');

				print &buildBackupJSON();


			}
		}
		else 
		{
			#Get with no parameters => Regular HTML printout
			print $qbck->header(-type    => 'text/html',
	                   	-charset => 'utf-8');

			my $out;

			$tt->process(
		        "backup.tmpl",
		        {
		            title => &get_htmltitle,
		            cssdrop => &printCssDropdown(0),
		        },
		        \$out,
		    ) or die $tt->error;

		    print $out;
		}

	}
else
	{
		#Not logged in, redirect
		print &redirectToPage($qbck,"login.pl");

	}


