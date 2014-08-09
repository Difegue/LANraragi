#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use File::Basename;
use File::Path;
use Archive::Zip qw/ :ERROR_CODES :CONSTANTS /;
use Image::Info qw(image_info dim);
use URI::Escape;
use utf8;

require 'config.pl';

#I ripped off some code from edit.pl to begin.
my $path;
my $qedit = new CGI;

if ($qedit->param()) 
{
    # We got a file name, let's get crackin'.
	my $filename = $qedit->param('file');
	my $id = md5sum(&get_dirname.'/'.$filename);
	
	#First, where is our temporary directory? Makes it so that if the same user opens an archive, it doesn't re-extract it all the time.
	my $tempdir= "";
	my $namet = "";
	my $patht = "";
	my $suffixt = "";
	my $destination = "";
	my @images = ();
	
	my $quality = &get_quality;
	
	$tempdir = &get_dirname."/temp";
	
	#Now, has our file been extracted to the temporary directory recently?
	#If it hasn't, a quick call to Archive::Zip will solve that.
	$path = $tempdir."/".$id;
	my $force = $qedit->param('force-reload');
	
	unless((-e $path) && ($force eq "0"))
		{
			
			my $zipFile = &get_dirname."/".$filename;
			my $zip = Archive::Zip->new();
			

			unless ( $zip->read( $zipFile ) == AZ_OK ) 
				{  # Make sure archive got read
				&rebuild_index;
				die 'Archive parsing error!';
				}
			my @files = $zip->memberNames();  # Lists all members in archive.
			
			@files = sort @files;
			
			foreach (@files) #For all the zip's files...
			{
			
			#Is it an image? We don't care about shit like txt files.
			if ($_ =~ /^(.*\/)*.+\.(png|jpg|gif|bmp|jpeg|PNG|JPG|GIF|BMP)$/ ) #regex magic! :o
				{
				
				($namet,$patht,$suffixt) = fileparse($_, qr/\.[^.]*/); #We get the filename
				#print $namet;
				$destination = $path."/".$namet.$suffixt; #With it, we define the extraction path
				
				$zip->extractMember($_, $destination); #We extract the file.
				
				#Picture is extracted and placed in the temp folder. Add it to the image index array.
				push(@images,$destination);
				}
			}
		}
	else #If the archive's already cached, no need to re-extract.
		{ 	
			opendir (DIR, $path);
			
			while (my $file = readdir(DIR)) 
				{
				if ($file =~ /^(.*\/)*.+\.(png|jpg|gif|bmp|jpeg|PNG|JPG|GIF|BMP)$/ ) #is it an image? readdir tends to read folder names too...
					{push(@images, $file);}
				}
			@images = sort @images;
		}
	
	#Get the page number from the GET parameters. Default is page 1.
	my $pagenum = 1;
	
	
	if ($qedit->param('page')) #Has a specific page been mentioned? If so, that's the one we'll need to display.
		{
		$pagenum = $qedit->param('page');
		
		if ($pagenum <= 0)
			{$pagenum = 1;}
			
		if ($pagenum >= $#images+1)
			{$pagenum = $#images+1;}
		
		}
	
	#convert to a cheaper on bandwidth format if the option is enabled.
	if (&get_bd)
		{
			`mogrify -geometry 1064x -quality $quality @images[$pagenum-1]`; 
			#since we're operating on the extracted file, the original, tucked away in the .zip, isn't harmed. Downloading the zip grants the highest quality.
		}
	
	#At this point, @images contains paths to the images extracted from the archive, in numeric order. 
	#We also have the page number that needs to be displayed. That's all we need!
	
	#Let's get more precise info on the image to display. 
	my $info = image_info(@images[$pagenum-1]);
	if (my $error = $info->{error}) 
		{
		die "Can't parse image info: $error\n";
		}	
		
	#gonna reuse those variables.
	($namet,$patht,$suffixt) = fileparse(@images[$pagenum-1], qr/\.[^.]*/);
	
	#sanitize we must.
	$filename = uri_escape($filename);
	
	#HTML printout. Tried to make it as clean as I could!
	
	print $qedit->header;
	print $qedit->start_html
		(
		-title=>&uri_unescape($filename),
		-author=>'lanraragi-san',
		-style=>{'src'=>'./styles/ex.css'},					
		-head=>[Link({-rel=>'icon',-type=>'image/png',-href=>'favicon.ico'})],		
		-encoding => "utf-8",
		);
		
	
	print '<script src="./js/reader.js"></script>';
	
	#These are the pretty arrows you use to switch pages.
	my $arrows = '<div class="sn">
					<a href="./reader.pl?file='.$filename.'&page=1" style="text-decoration:none;"> <img src="./img/f.png"></img> </a> 
					<a id="prev" href="./reader.pl?file='.$filename.'&page='.($pagenum-1).'" style="text-decoration:none;"> <img src="./img/p.png"></img> </a>
					<div><span id ="current">'.$pagenum.'</span> / <span id ="max">'.($#images+1).'</span> </div>
					<a id="next" href="./reader.pl?file='.$filename.'&page='.($pagenum+1).'" style="text-decoration:none;"> <img src="./img/n.png"></img> </a>
					<a href="./reader.pl?file='.$filename.'&page='.($#images+1).'" style="text-decoration:none;"> <img src="./img/l.png"></img> </a>
				</div>';
				
	#Outputs something like "0001.png :: 1052 x 1500 :: 996.6 KB".
	my $size = (int((-s (@images[$pagenum-1]) )/ 1024*10)/10 ) ;
	
	my $fileinfo ='<div id = "fileinfo">'. $namet.$suffixt .' :: '. $info->{width} .' x '. $info->{height} .' :: '. $size .'KBs</div>';
	
	print '<div id="i1" class="sni" style="width: 1072px; max-width: 1072px;">
			<h1>'.uri_unescape($filename).'</h1>
			
			<div id="i2">'.$arrows.$fileinfo.'</div>
			
			<div id ="i3">
			<a id ="display" href="./reader.pl?file='.$filename.'&page='.($pagenum+1).'">
			<img id="img" style="width: 1052px; max-width: 1052px; max-height: 1500px;" src="'.@images[$pagenum-1].'"></img>
			</a>
			</div>
			
			<div id = "i4">'.$fileinfo.$arrows.'</div>
			
			<div id="i5">
			<div class="sb">
			<a href="./">
			<img src="./img/b.png"></img>
			</a>
			</div>
			</div>
			
			<div id="i6" class="if">
			<img class="mr" src="./img/mr.gif"></img>
			<a href="./reader.pl?file='.$filename.'&page='.$pagenum.'&force-reload=1">Clear archive cache</a>
			<img class="mr" src="./img/mr.gif"></img>
			<a href="./">Go back to library </a>
			</div>
			
			<div id="i7" class="if"></div>
		</div>'
} 
else 
{
    # No parameters back the fuck off
	print $qedit->header;
	print $qedit->start_html
		(
		-title=>&get_htmltitle,
		-author=>'lanraragi-san',
		-style=>{'src'=>'./styles/ex.css'},					
		-head=>[Link({-rel=>'icon',-type=>'image/png',-href=>'favicon.ico'})],			
		);
	
    print $qedit->redirect('./');
}

print '		<p class="ip">
			[
			<a href="https://github.com/Difegue/LANraragi">
				Powered by LANraragi.
			</a>
			]
		</p>';
print $qedit->end_html;