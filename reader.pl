#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use File::Basename;
use File::Path qw(remove_tree);;
use Image::Info qw(image_info dim);
use File::Find qw(find);
use Encode;

require 'config.pl';
require 'functions.pl';

#I ripped off some code from edit.pl to begin.
my $path;
my $qedit = new CGI;

if ($qedit->param()) 
{
    # We got a file name, let's get crackin'.
	my $id = $qedit->param('id');
	
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
	#If it hasn't, a quick call to unar will solve that.
	my $force = $qedit->param('force-reload');
	
	#Redis initialization.
	my $redis = Redis->new(server => &get_redisad, 
				reconnect => 100,
				every     => 3000);
	
	#We opened this id in the reader, so we can't mark it as "new" anymore.
	$redis->hset($id,"isnew","none");

	#Get the path from Redis.
	my $zipFile = $redis->hget($id,"file");
	
	#Get the archive name as well.
	my $arcname = $redis->hget($id,"title")." by ".$redis->hget($id,"artist");
	
	($_ = decode_utf8($_)) for ($zipFile, $arcname);
	
	my ($name,$fpath,$suffix) = fileparse($zipFile, qr/\.[^.]*/);
	my $filename = $name.$suffix;
	
	my $path = $tempdir."/".$id;
	
	if (-e $path && $force eq "1") #If the file has been extracted and force-reload=1, we delete it all
	{
		remove_tree($path);
	}

	unless(-e $path) #If the file hasn't been extracted, or if force-reload =1
		{

			unless ( `unar -D -o $path "$zipFile"`) #Extraction using unar without creating extra folders.
				{  # Make sure archive got read
				&rebuild_index;
				print 'Archive parsing error!';
				exit;
				}
		}
		
	#We have to go deeper. Most archives often hide their images a few folders in...	
	my @images;
	find({ wanted => sub { 
							if ($_ =~ /^*.+\.(png|jpg|gif|bmp|jpeg|PNG|JPG|GIF|BMP)$/ ) #is it an image? readdir tends to read folder names too...
								{push @images, $_ }
						} , no_chdir => 1 }, $path); #find () does exactly that. 
		
	#magical sort function
	sub expand {
                   my $file=shift; 
                   $file=~s{(\d+)}{sprintf "%04d", $1}eg;
                   return $file;
               }
			  
    my @images = sort { expand($a) cmp expand($b) } @images;
	
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
	
	#HTML printout. Tried to make it as clean as I could!
	
	print $qedit->header(-type    => 'text/html',
                   -charset => 'utf-8');
	print $qedit->start_html
		(
		-title=>$arcname,
		-author=>'lanraragi-san',	
		-script=>[{-type=>'JAVASCRIPT',
							-src=>'./js/css.js'},
				  {-type=>'JAVASCRIPT',
							-src=>'./js/jquery-2.1.4.min.js'},
				  {-type=>'JAVASCRIPT',
							-src=>'./js/dropit.js'},
				  {-type=>'JAVASCRIPT',
							-src=>'./js/jquery.rwdImageMaps.min.js'}],				
		-head=>[Link({-rel=>'icon', -type=>'image/png', -href=>'favicon.ico'}),
				meta({-name=>'viewport', -content=>'width=device-width'})],		
		-encoding => "utf-8",
		-style=>[{'src'=>'./styles/lrr.css'},
				{'src'=>'//maxcdn.bootstrapcdn.com/font-awesome/4.3.0/css/font-awesome.min.css'}],
		-onload=> "
					//dynamic html imagemap magic
					\$('img[usemap]').rwdImageMaps();
					set_style_from_storage();

					//Initialize CSS dropdown with dropit
					\$('.menu').dropit();
					",
		);
		
	print &printCssDropdown(0);
	print '<script src="./js/reader.js"></script>';
	#These are the pretty arrows you use to switch pages.
	my $arrows = '<div class="sn">
					<a href="./reader.pl?id='.$id.'&page=1"> <i class="fa fa-angle-double-left fa-2x"></i> </a> 
					<a id="prev" href="./reader.pl?id='.$id.'&page='.($pagenum-1).'"> <i class="fa fa-angle-left fa-2x"></i> </a>
					<div class="pagecount"><span id ="current">'.$pagenum.'</span> / <span id ="max">'.($#images+1).'</span> </div>
					<a id="next" href="./reader.pl?id='.$id.'&page='.($pagenum+1).'"> <i class="fa fa-angle-right fa-2x"></i> </a>
					<a href="./reader.pl?id='.$id.'&page='.($#images+1).'"> <i class="fa fa-angle-double-right fa-2x"></i> </a></div>';
					
	#generate the floating div containing the help popup and the page dropdown
	my $pagesel = '<div style="position: absolute; right: 20px;" >
				<form style="float: right;"><select size="1"  onChange="location = this.options[this.selectedIndex].value;">';

	#We opened a drop-down list. Now, we'll fill it.
	for ( my $i = 1; $i < $#images+2; $i++) 
	{
		if ($i eq $pagenum) #If the option we'll print is our current page, we should make it the selected choice.
		{$pagesel = $pagesel.'<option selected="selected" value="./reader.pl?id='.$id.'&page='.$i.'">Page '.$i.'</option>';}
		else
		{$pagesel = $pagesel.'<option value="./reader.pl?id='.$id.'&page='.$i.'">Page '.$i.'</option>';}
	}		

	#We close the drop-down list and add a help dialog.
	$pagesel = $pagesel.'</select></form>

						<div class="menu dropit" style="display:inline;font-size:12pt">
							<span class="dropit-trigger">
								<a href="#"><i class="fa fa-paperclip fa-2x" style="padding-right: 10px;"></i></a>

								<div style="width: 200px; left: -160px; font-size: 10pt;" class="dropit-submenu">
								<span>You can navigate between pages in different ways : 
										<ul style=""> 
										<li>The arrow icons</li> 
										<li>The keyboard arrows</li> 
										<li>Touching the left/right side of the image.</li>
										</ul>
								</span>

								</div>
							</span>
						</div>

	</div>';
	
	
	#Outputs something like "0001.png :: 1052 x 1500 :: 996.6 KB".
	my $size = (int((-s (@images[$pagenum-1]) )/ 1024*10)/10 ) ;
	
	my $imgwidth = $info->{width}; 
	my $imgheight = $info->{height}; 
	my $imgmapwidth = int($imgwidth/2 + 0.5);

	my $fileinfo ='<div id = "fileinfo">'. $namet.$suffixt .' :: '. $imgwidth .' x '. $imgheight .' :: '. $size .'KBs</div>';
	
	#We need to sanitize the image's path, in case the folder contains illegal characters, but uri_escape would also nuke the / needed for navigation.
	#Let's solve this with a quick regex search&replace.
	#First, we sanitize it all...
	@images[$pagenum-1] = escapeHTML(@images[$pagenum-1]);
	
	#Then we bring the slashes back.
	@images[$pagenum-1] =~ s!%2F!/!g;
	
	print '<div id="i1" class="sni" style="max-width: 1200px">
			<h1>'.$arcname.'</h1>
			
			<div id="i2">'.$pagesel.$arrows.$fileinfo.'</div>
			
			<div id ="i3">
			
			<a id ="display">
			<img id="img" style="max-width:100%; height: auto; width: auto; " src="'.@images[$pagenum-1].'" usemap="#Map" />
			<map name="Map" id="Map">
			    <area alt="" title="" href="./reader.pl?id='.$id.'&page='.($pagenum-1).'" shape="rect" coords="0,0,'.$imgmapwidth.','.$imgheight.'" />
			    <area alt="" title="" href="./reader.pl?id='.$id.'&page='.($pagenum+1).'" shape="rect" coords="'.($imgmapwidth+1).',0,'.$imgwidth.','.$imgheight.'" />
			</map>
			</a>
	
			</div>
			
			<div id = "i4">'.$fileinfo.$pagesel.$arrows.'</div>
			
			<div id="i5">
			<div class="sb">
			<a href="./">
			<i class="fa fa-angle-down fa-4x"></i>
			</a>
			</div>
			</div>
			
			<div id="i6" class="if">
			<i class="fa fa-caret-right fa-lg"></i>
			<a href="./reader.pl?id='.$id.'&page='.$pagenum.'&force-reload=1">Garbled image? (Clean Archive Cache)</a>
			<i class="fa fa-caret-right fa-lg"></i>
			<a href="./">Go back to library </a>
			</div>
			
			<div id="i7" class="if">
			<i class="fa fa-caret-right fa-lg"></i>
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

print $qedit->end_html;