#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use File::Basename;
use File::Path;
use Archive::Zip qw/ :ERROR_CODES :CONSTANTS /;

require 'config.pl';

#I ripped off some code from edit.pl to begin.
my $path;
my $qedit = new CGI;
print $qedit->header;
print $qedit->start_html
	(
	-title=>&get_htmltitle,
    -author=>'lanraragi-san',
    -style=>{'src'=>'./styles/ex.css'},					
	-head=>[Link({-rel=>'icon',-type=>'image/png',-href=>'favicon.ico'})],
	-script=>{-type=>'JAVASCRIPT',
					-src=>'./js/reader.js'},
	);

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
				
				#convert it to a cheaper on bandwidth format if the option is enabled.
				if (&get_bd)
				{
					`mogrify -size 1064x1500 -geometry 1064x1500 -quality $quality $destination`; 
					#since we're operating on the extracted file, the original, tucked away in the .zip, isn't harmed. Downloading the zip grants the highest quality.
				}
				
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
	
	#At this point, @images contains paths to the images extracted from the archive, in numeric order. Now what we have to do is jam these into our javascript reader.
	#First, let's define a JS array that'll contain @images.
	
	print '<script>';
	foreach (@images)
		{
		print 'images.push("'.$_.'");'; #We push an element of @images to the images JS array.
		}
	print '</script>';
	
	#HTML printout. Tried to make it as clean as I could!
	
	my $arrows = '<div class="sn">
					<a onclick="javascript:goto_first(images)"> <img src="./img/f.png"></img> </a> 
					<a id="prev" onclick="goto_prev(images)"> <img src="./img/p.png"></img> </a>
					<div><span id ="current1">1</span> / <span>'.($#images+1).'</span> </div>
					<a id="next" onclick="goto_next(images)"> <img src="./img/n.png"></img> </a>
					<a onclick="javascript:goto_last(images)"> <img src="./img/l.png"></img> </a>
				</div>';
				
	my $arrows2 = '<div class="sn">
					<a onclick="goto_first(images)"> <img src="./img/f.png"></img> </a> 
					<a id="prev" onclick="goto_prev(images)"> <img src="./img/p.png"></img> </a>
					<div><span id ="current2">1</span> / <span>'.($#images+1).'</span> </div>
					<a id="next" onclick="goto_next(images)"> <img src="./img/n.png"></img> </a>
					<a onclick="goto_last(images)"> <img src="./img/l.png"></img> </a>
				</div>';
	
	print '<div id="i1" class="sni" style="width: 1072px; max-width: 1072px;">
			<h1>'.$filename.'</h1>
			
			<div id="i2">'.$arrows.'
			<div id = "fileinfo"> FILE INFO GOES HERE </div>
			</div>
			
			<div id ="i3">
			<a id ="display" onclick="goto_next(images)">
			<img id="img" style="width: 1052px; height: 1500px; max-width: 1052px; max-height: 1500px;" src="'.@images[0].'"></img>
			</a>
			</div>
			
			<div id = "i4">
			<div id = "fileinfo"> FILE INFO GOES HERE'.
			$arrows2.'
			</div>
			
			<div id="i5">
			<div class="sb">
			<a href="./">
			<img src="./img/b.png"></img>
			</a>
			</div>
			</div>
			
			<div id="i6" class="if">
			<img class="mr" src="./img/mr.gif"></img>
			<a href="./reader.pl?file='.$filename.'&force-reload=1">Clear archive cache</a>
			<img class="mr" src="./img/mr.gif"></img>
			<a href="./">Go back to library </a>
			</div>
			
			<div id="i7" class="if"></div>
		</div>
		<p class="ip">
			[
			<a href="https://github.com/Difegue/LANraragi">
				Powered by LANraragi.
			</a>
			]
		</p>'
} 
else 
{
    # No parameters back the fuck off
    print $qedit->redirect('./');
}

print $qedit->end_html;