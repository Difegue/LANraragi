#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use File::Basename;
 use utf8;

require 'config.pl';

my $qupload = new CGI;
print $qupload->header;
print $qupload->start_html
	(
	-title=>&get_htmltitle." - Upload Mode",
    -author=>'lanraragi-san',
    -style=>{'src'=>'./styles/ex.css'},					
	-head=>[Link({-rel=>'icon',-type=>'image/png',-href=>'favicon.ico'})],
	-encoding => "utf-8",
	);
	
if ($qupload->param()) {
    # Parameters are defined, therefore something has been submitted...	
	
	#Are the submitted arguments POST?
	if ('POST' eq $qupload->request_method )
		{
		#let's do eet
		
		#Check if passowrd is correct first.
		my $pass = $qupload->param('pass');
		unless (&enable_pass && ($pass eq &get_password))
			{
			print "<div class='ido' style='text-align:center'><h1>Wrong password.</h1><br/>";
			print "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/></div>";
			}
		else
			{ 
			my $filename = $qupload->param('file');
			my ($name,$path,$suffix) = fileparse("&get_dirname/$filename", qr/\.[^.]*/);
	
			#Then, check if the user uploaded a filetype we support. (only zip for now)
			unless ($suffix eq ".zip")
				{
				print "<div class='ido' style='text-align:center'><h1>Unsupported archive type.</h1><br/>";
				print "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/>";
				}
			else
				{
				my $output_file = &get_dirname.'/'.$filename; #open up a file on our side
				#if it doesn't already exist, that is.
				
				if (-e $output_file)
					{
					print "<div class='ido' style='text-align:center'><h1>A file bearing this name already exists in the Library.</h1><br/>";
					print "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/>";
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
					
					&rebuild_index; #Delete the cached index so that the uploaded file appears.
					
					print "<div class='ido' style='text-align:center'><h1>Upload Successful!</h1><br/>";
					print "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/>";
					print "<input class='stdbtn' type='button' onclick=\"window.location.replace('./edit.pl?file=".$name."');\" value='Edit Uploaded Gallery'/></div>";
					}
				}
			
			}
		}
}
else
{
	#Print the upload form.
	
	print "<div class='ido' style='text-align:center'>";
	print $qupload->h1( {-class=>'ih', -style=>'text-align:center'},"Uploading an Archive to the Library");
	print $qupload->start_form;
	print "<table style='margin:auto'><tbody>";
	
	print "<tr><td style='text-align:left; width:100px'>Select File:</td><td>";
	print $qupload->filefield(
			-name      => 'file',
			-size      => 20,
			-maxlength => 255,
			-style => "width:820px",
			-readonly,
			#-style='',
		);
	print "</td></tr>";
	
		if (&enable_pass)
	{
		print "<tr><td style='text-align:left; width:100px'>Admin Password:</td><td>";
		print $qupload->password_field(
				-name      => 'pass',
				-value     => '',
				-size      => 20,
				-maxlength => 255,
				-class => "stdinput",
				-style => "width:820px",
			);
		print "</td></tr>";
	}
	
	print "<tr><td></td><td style='text-align:left'>";
	print $qupload->submit(
			-name     => 'submit_form',
			-value    => 'Upload Archive',
			-onsubmit => 'javascript: validate_form()',
			-class => 'stdbtn', 
		);
	print "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/>";
	

	print "</td></tbody></table>";
	print $qupload->end_form;
	
	print "</div>";
	
	
	
}

print $qupload->end_html;