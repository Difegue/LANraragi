#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use File::Basename;
use File::Path;
use Image::Info qw(image_info dim);
use URI::Escape;
use utf8;
use File::Find qw(find);

require 'config.pl';

#I ripped off some code from edit.pl to begin.
my $path;
my $qedit = new CGI;

if ($qedit->param()) 
{
    # We got a file name, let's get crackin'.
	my $filename = $qedit->param('file');
	my $id = shasum(&get_dirname.'/'.$filename);
	
	#First, where is our temporary directory? Makes it so that if the same user opens an archive, it doesn't re-extract it all the time.
	my $tempdir= "";
	my $namet = "";
	my $patht = "";
	my $suffixt = "";
	my $destination = "";
	my @images = ();
	
	#We'll get the page number from the GET parameters. Default is page 1.
	my $pagenum = 1;
	my $quality = &get_quality;
	
	$tempdir = &get_dirname."/temp";
	
	#Now, has our file been extracted to the temporary directory recently?
	#If it hasn't, a quick call to the Unarchiver will solve that.
	$path = $tempdir."/".$id;
	my $force = $qedit->param('force-reload');
	
	unless((-e $path) && ($force eq "0"))
		{
			my $zipFile= &get_dirname."/".$filename;
			#print 'unar -o '.$path.' "'.$zipFile.'"';
			
			unless ( `unar -o $path "$zipFile"`) #Extraction using unar
				{  # Make sure archive got read
				&rebuild_index;
				print 'Archive parsing error!';
				exit;
				}
		}
		
	#We have to go deeper. Most archives often hide their images a few folders in...	
	my @images;
	find({ wanted => sub { 
							if ($_ =~ /^(.*\/)*.+\.(png|jpg|gif|bmp|jpeg|PNG|JPG|GIF|BMP)$/ ) #is it an image? readdir tends to read folder names too...
								{push @images, $_ }
						} , no_chdir => 1 }, $path); #find () does exactly that. 
		
	@images = sort { lc($a) cmp lc($b) } @images;
		
	#print @images;
	
	if ($qedit->param('page')) #Has a specific page been mentioned? If so, that's the one we'll need to display.
		{
		$pagenum = $qedit->param('page');
		
		if ($pagenum <= 0)
			{$pagenum = 1;}
			
		if ($pagenum >= $#images+1)
			{$pagenum = $#images+1;}
		
		}
	
	#convert to a cheaper on bandwidth format if the option is enabled.
	if (&get_threshold != 0)
	{
			#Is the file size higher than the threshold?
			#print (int((-s @images[$pagenum-1] )/ 1024*10)/10 );
			if ( (int((-s @images[$pagenum-1] )/ 1024*10)/10 ) > &get_threshold)
			{
				#print "mogrify -geometry 1064x -quality $quality $i";
				`mogrify -scale 1064x -quality $quality "@images[$pagenum-1]"`; 
			}
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
					<a id="prev" href="./reader.pl?file='.$filename.'&page='.($pagenum-1).'" style="text-decoration:none; "> <img src="./img/p.png"></img> </a>
					<div><span id ="current">'.$pagenum.'</span> / <span id ="max">'.($#images+1).'</span> </div>
					<a id="next" href="./reader.pl?file='.$filename.'&page='.($pagenum+1).'" style="text-decoration:none; "> <img src="./img/n.png"></img> </a>
					<a href="./reader.pl?file='.$filename.'&page='.($#images+1).'" style="text-decoration:none; "> <img src="./img/l.png"></img> </a></div>';
					
					
	my $pagesel = '<div style="position: absolute; right: 20px;" ><form style="float: right;"><select size="1"  onChange="location = this.options[this.selectedIndex].value;">';

	#We opened a drop-down list. Now, we'll fill it.
	for ( my $i = 1; $i < $#images+2; $i++) 
	{
		if ($i eq $pagenum) #If the option we'll print is our current page, we should make it the selected choice.
		{$pagesel = $pagesel.'<option selected="selected" value="./reader.pl?file='.$filename.'&page='.$i.'">Page '.$i.'</option>';}
		else
		{$pagesel = $pagesel.'<option value="./reader.pl?file='.$filename.'&page='.$i.'">Page '.$i.'</option>';}
	}		

	$pagesel = $pagesel.'</select></form></div>';
	
	
	#Outputs something like "0001.png :: 1052 x 1500 :: 996.6 KB".
	my $size = (int((-s (@images[$pagenum-1]) )/ 1024*10)/10 ) ;
	
	my $fileinfo ='<div id = "fileinfo">'. $namet.$suffixt .' :: '. $info->{width} .' x '. $info->{height} .' :: '. $size .'KBs</div>';
	
	#We need to sanitize the image's path, in case the folder contains illegal characters, but uri_escape would also nuke the / needed for navigation.
	#Let's solve this with a quick regex search&replace.
	#First, we sanitize it all...
	@images[$pagenum-1] = &uri_escape(@images[$pagenum-1]);
	
	#Then we bring the slashes back.
	@images[$pagenum-1] =~ s!%2F!/!g;
	
	print '<div id="i1" class="sni" style="width: 1072px; max-width: 1072px;">
			<h1>'.&uri_unescape($filename).'</h1>
			
			<div id="i2">'.$pagesel.$arrows.$fileinfo.'</div>
			
			<div id ="i3">
			
			<a style=" z-index: 10; position: absolute; width:50%; height:100%;" href="./reader.pl?file='.$filename.'&page='.($pagenum-1).'"></a>
			<a style=" z-index: 10; position: absolute; left:50%; width:50%; height:100%;" href="./reader.pl?file='.$filename.'&page='.($pagenum+1).'"></a>
			
			<a id ="display">
			<img id="img" style="width: 1052px; max-width: 1052px; max-height: 1500px;" src="'.@images[$pagenum-1].'"></img>
			</a>
	
			</div>
			
			<div id = "i4">'.$fileinfo.$pagesel.$arrows.'</div>
			
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
			
			<div id="i7" class="if">
			<img class="mr" src="./img/mr.gif"></img>
			<a href="'.@images[$pagenum-1].'">View full-size image</a>
			</div>
			
		</div>';
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