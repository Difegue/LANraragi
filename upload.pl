#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use File::Basename;
use Encode;
use Redis;

#Require config 
require 'config.pl';
require 'functions/functions_generic.pl';
require 'functions/functions_login.pl';

my $qupload = new CGI;

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

			my ($name,$path,$suffix) = fileparse("&get_dirname/$filename", qr/\.[^.]*/);
			
			my $output_file = &get_dirname.'/'.$filename; #open up a file on our side
					
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

					my $id = sha256_hex($output_file);

					&addArchiveToRedis($id,$filename,$redis);

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

		print $qupload->start_html
			(
			-title=>&get_htmltitle." - Upload Mode",
		    -author=>'lanraragi-san',
		    -script=>[{-type=>'JAVASCRIPT',
									-src=>'./js/css.js'},
						{-type=>'JAVASCRIPT',
									-src=>'./js/ajax.js'},
						{-type=>'JAVASCRIPT',
									-src=>'./bower_components/jquery/dist/jquery.min.js'},
						{-type=>'JAVASCRIPT',
									-src=>'./bower_components/blueimp-file-upload/js/vendor/jquery.ui.widget.js'},
						{-type=>'JAVASCRIPT',
									-src=>'./bower_components/blueimp-file-upload/js/jquery.fileupload.js'},
									],
			-style=>[{'src'=>'./bower_components/blueimp-file-upload/css/jquery.fileupload.css'},
					{'src'=>'./bower_components/font-awesome/css/font-awesome.min.css'}],							
			-head=>[Link({-rel=>'icon',-type=>'image/png',-href=>'favicon.ico'}),
							meta({-name=>'viewport', -content=>'width=device-width'})],
			-encoding => "utf-8",
			-onLoad => qq(
						//Set the correct CSS from the user's localStorage.
						set_style_from_storage();

						//Handler for file uploading.
						\$('#fileupload').fileupload({
					        dataType: 'json',
					        done: function (e, data) {

					        	if (data.result.success == 0)
					        		result = "<tr><td>" + data.result.name + 
					        				"</td><td> <i class='fa fa-warning' style='margin-left:20px; margin-right: 10px; color: red'></i>" + data.result.error + "</td></tr>";
					        	else
					        		result = "<tr><td>" + data.result.name + 
					        				"</td><td> <i class='fa fa-check-square' style='margin-left:20px; margin-right: 10px; color: green'></i> <a href='edit.pl?id=" + data.result.id + "'> Click here to edit metadata. </a></td></tr>";

					        	\$('#progress .bar').css('width','0%');
					            \$('#files').append(result);
					        },

					        progressall: function (e, data) {
						        var progress = parseInt(data.loaded / data.total * 100, 10);
						        \$('#progress .bar').css('width', progress + '%');
						    }

					    });
						)
			);
			
		print &printCssDropdown(0);

		print "<div class='ido' style='text-align:center'>
					<h1 class='ih' style='text-align:center'>Uploading Archives to the Library</h1>	

					Drag and drop files here, or click the upload button.
					<br/><br/>

					<table style='margin:auto; font-size:9pt; width: 80% '><tbody id='files'>
					<tr><td colspan = 2>

						<span class='stdbtn fileinput-button' >
							<i class='fa fa-upload' style='padding-top:6px'></i>
							<span>Select files to upload...</span>
							<input type='file' name='file' multiple id='fileupload'> 
						</span>
						
						<div id='progress' style='padding-top:6px; padding-bottom:6px'>
						    <div class='bar' style='width: 0%;'></div>
						</div>
						
					</div>
					</td></tr>



					</tbody></table>
					<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/>

			  </div>
			  ";

		print $qupload->end_html;
	}
}
else
{
		#Not logged in, redirect
		print &redirectToPage($qupload,"login.pl");

}