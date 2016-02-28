#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use File::Basename;
use IPC::Cmd qw[can_run run];
use Encode;

#Require config 
require 'config.pl';
require 'functions/functions_generic.pl';
require 'functions/functions_login.pl';

my $qupload = new CGI;

#Before anything, check if the user is logged in. If not, redirect him to login.pl?redirect=edit.pl
if (&isUserLogged($qupload))
{

	print $qupload->header(-type    => 'text/html',
                   -charset => 'utf-8');
	print $qupload->start_html
		(
		-title=>&get_htmltitle." - Upload Mode",
	    -author=>'lanraragi-san',
	    -script=>[{-type=>'JAVASCRIPT',
								-src=>'./js/css.js'},
					{-type=>'JAVASCRIPT',
								-src=>'./js/ajax.js'},
					{-type=>'JAVASCRIPT',
								-src=>'./bower_components/jquery/dist/jquery.min.js'}],							
		-head=>[Link({-rel=>'icon',-type=>'image/png',-href=>'favicon.ico'}),
						meta({-name=>'viewport', -content=>'width=device-width'})],
		-encoding => "utf-8",
		-onLoad => "//Set the correct CSS from the user's localStorage.
							set_style_from_storage();"
		);
		
	print &printCssDropdown(0);

	if ($qupload->param()) 
	{
	    # Parameters are defined, therefore something has been submitted...	
		#Start upload.
		my $filename = $qupload->param('file');
		my $uploadMime = $qupload->uploadInfo($filename)->{'Content-Type'};

		my @mimeTypes = ("application/zip","application/x-rar-compressed","application/x-7z-compressed","application/x-tar","application/x-gtar","application/x-lzma","application/x-xz");
		my %acceptedTypes = map { $_ => 1 } @mimeTypes;

		#Check if the uploaded file's mimetype matches one we accept
		if(exists($acceptedTypes{$uploadMime})) 
			{ 

			my ($name,$path,$suffix) = fileparse("&get_dirname/$filename", qr/\.[^.]*/);
			
			my $output_file = &get_dirname.'/'.$filename; #open up a file on our side
			#if it doesn't already exist, that is.
						
			if (-e $output_file)
				{
					print "<div class='ido' style='text-align:center'><h1>A file bearing this name already exists in the Library.</h1><br/>";
					print "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/>";
					print "<input class='stdbtn' type='button' onclick=\"window.location.replace('./upload.pl');\" value='Upload another Archive'/></div>";
				}
			else
				{
					my ($bytesread, $buffer);
					my $numbytes = 1024;

					open (OUTFILE, ">", "$output_file") 
						or die "Couldn't open $output_file for writing: $!";
					while ($bytesread = read($filename, $buffer, $numbytes)) 
						{
						print OUTFILE $buffer; #Write the uploaded contents to that file.
						}
					close OUTFILE;
					
					print "<div class='ido' style='text-align:center'><h1>Upload Successful!</h1><br/>";
					print "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/>";
					print "<input class='stdbtn' type='button' onclick=\"window.location.replace('./upload.pl');\" value='Upload another Archive'/></div>";				
				}
			}
		else 
			{
			print "<div class='ido' style='text-align:center'><h1>Unsupported file. ($uploadMime)</h1><br/><br/>";
			print "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/>";
			print "<input class='stdbtn' type='button' onclick=\"window.location.replace('./upload.pl');\" value='Upload another Archive'/></div>";		
			}	
	}
	else
	{
		#Print the upload form.
		
		print "<div class='ido' style='text-align:center'>";
		print $qupload->h1( {-class=>'ih', -style=>'text-align:center'},"Uploading an Archive to the Library");
		print $qupload->start_form(
						-name		=> 'uploadArchiveForm',
						-enctype	=> 'multipart/form-data',
						);
		print "<table style='margin:auto'><tbody>";
		
		print "<tr><td style='text-align:left; width:10%'>Select File:</td><td>";
		print $qupload->filefield(
				-name      => 'file',
				-size      => 20,
				-maxlength => 255,
				-style => "width:80%",
				-readonly,
				-required,
				#-style='',
			);
		print "</td></tr>";
		
		print "<tr><td></td><td style='text-align:left'>";

		print "<input class='stdbtn' type='submit' value='Upload Archive'/>";
		print "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/>";
		

		print "</td></tbody></table>";
		print $qupload->end_form;
		
		print "</div>";

	}
}
else
{
		#Not logged in, redirect
		print &redirectToPage($qupload,"login.pl");

}

print $qupload->end_html;