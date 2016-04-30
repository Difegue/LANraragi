#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use Encode;
use Redis;
use Template;
use utf8;

#Require config 
require 'functions/functions_config.pl';
require 'functions/functions_generic.pl';
require 'functions/functions_login.pl';

my $qupload = new CGI;
my $tt  = Template->new({
        INCLUDE_PATH => "templates",
        #ENCODING => 'utf8' 
    });


#Before anything, check if the user is logged in. If not, redirect him to login.
if (&isUserLogged($qupload))
{

	if ($qupload->param()) 
	{
	    # Parameters are defined, therefore something has been submitted.

	    # Prepare header for a JSON reply 
	    print $qupload->header(-type    => 'application/json',
	                   -charset => 'utf-8');

		#Receive uploaded file.
		my $filename = $qupload->param('file');
		my $uploadMime = $qupload->uploadInfo($filename)->{'Content-Type'};

		my @mimeTypes = ("application/zip","application/x-zip-compressed","application/x-rar-compressed","application/x-7z-compressed","application/x-tar","application/x-gtar","application/x-lzma","application/x-xz");
		my %acceptedTypes = map { $_ => 1 } @mimeTypes;

		#Check if the uploaded file's mimetype matches one we accept
		if(exists($acceptedTypes{$uploadMime})) 
			{
			
			my $output_file = &get_dirname.'/'.decode_utf8($filename); #open up a file on our side
					
			if (-e $output_file) #if it doesn't already exist, that is.
				{
					print qq({
								"name":"$filename",
								"type":"$uploadMime",
								"success":0,
								"error":"A file bearing this name already exists in the Library."
								});
				}
			else
				{
					my ($bytesread, $buffer);
					my $numbytes = 1024;

					open (OUTFILE, ">", "$output_file") 
						or die "Couldn't open $output_file for writing: $!";

					while ($bytesread = read($filename, $buffer, $numbytes)) 
						{ print OUTFILE $buffer; } #Write the uploaded contents to that file.

					close OUTFILE;

					#Parse for metadata right now and get the database ID
					my $redis = Redis->new(server => &get_redisad, 
							reconnect => 100,
							every     => 3000);

					my $id = sha256_hex(encode_utf8($output_file));

					&addArchiveToRedis($id,$output_file,$redis);

					print qq({
								"name":"$filename",
								"type":"$uploadMime",
								"success":1,
								"id":"$id"
								});				
				}
			}
		else 
			{
			print qq({
								"name":"$filename",
								"type":"$uploadMime",
								"success":0,
								"error":"Unsupported Filetype."
								});	
			}	
	}
	else
	{
		#Print the upload form.	
		print $qupload->header(-type    => 'text/html',
	                   -charset => 'utf-8');

		my $title = &get_htmltitle;

		my $out;

		$tt->process(
	        "upload.tmpl",
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
		print &redirectToPage($qupload,"login.pl");

}