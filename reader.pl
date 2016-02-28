#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use Redis;
use File::Basename;
use File::Path qw(remove_tree);
use Image::Info qw(image_info dim);
use File::Find qw(find);
use Encode;
use IPC::Cmd qw[can_run run];

#Require config 
require 'config.pl';
require 'functions/functions_generic.pl';

my $path;
my $qreader = new CGI;

if ($qreader->param()) 
{
    # We got a file name, let's get crackin'.
	my $id = $qreader->param('id');
	
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
	
	my $force = $qreader->param('force-reload');
	my $thumbreload = $qreader->param('reload_thumbnail');
	
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

	#Now, has our file been extracted to the temporary directory recently?
	#If it hasn't, we call unar to do it.
	unless(-e $path) #If the file hasn't been extracted, or if force-reload =1
		{

		 	my $unarcmd = "unar -D -o $path \"$zipFile\" "; #Extraction using unar without creating extra folders.

		 	my( $success, $error_message, $full_buf, $stdout_buf, $stderr_buf ) =
	            run( command => $unarcmd, verbose => 0 ); 

		 	#Has the archive been extracted ?
				unless (-e $path) {
					    # @$full_buf contains err message if error occurs
						print $qreader->header(-type    => 'text/html',
                   				-charset => 'utf-8');
						print $qreader->start_html
							(
							-title=>"LANraragi - Reader Error",
							-author=>'lanraragi-san',
							-style=>{'src'=>'./styles/ex.css'},					
							-head=>[Link({-rel=>'icon',-type=>'image/png',-href=>'favicon.ico'})],			
							);

						print "<img src='./img/flubbed.gif'/><br/>
								<h2>I flubbed it while trying to open the archive ".$filename.".</h2>It's likely the archive contains a folder with unicode characters.<br/> No real way around that for now besides modifying your archive, sorry !<br/>";

						print "<h3>Some more info below :</h3> <br/>";
						print decode_utf8(join "<br/>", @$full_buf);

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
    
	
	if ($qreader->param('page')) #Has a specific page been mentioned? If so, that's the one we'll need to display.
		{
		$pagenum = $qreader->param('page');
		
		if ($pagenum <= 0)
			{$pagenum = 1;}
			
		if ($pagenum >= $#images+1)
			{$pagenum = $#images+1;}
		
		}
		else #We're on page 1: we can convert it into a thumbnail for the main reader index if it's not been done already(Or if it fucked up for some reason).
		{
			my $thumbname = &get_dirname."/thumb/".$id.".jpg";

			unless (-e $thumbname && $thumbreload eq "0")
			{
				my $path = @images[$pagenum-1];
				$redis->hset($id,"thumbhash", encode_utf8(shasum($path)));
				`convert -strip -thumbnail 200x "$path" $thumbname`;

			}

		}

	my $imgpath = @images[$pagenum-1]; #This is the page we'll display.
	
	#convert to a cheaper on bandwidth format if the option is enabled.
	if (&get_threshold != 0)
	{
			#Is the file size higher than the threshold?
			#print (int((-s @images[$pagenum-1] )/ 1024*10)/10 );
			if ( (int((-s $imgpath )/ 1024*10)/10 ) > &get_threshold)
			{
				#print "mogrify -geometry 1064x -quality $quality $i";
				`mogrify -scale 1064x -quality $quality "$imgpath"`; 
			}
			#since we're operating on the extracted file, the original, tucked away in the .zip, isn't harmed. Downloading the zip grants the highest quality.
	}
	
	#At this point, @images contains paths to the images extracted from the archive, in numeric order. 
	#We also have the page number that needs to be displayed.
	
	#Let's get more precise info on the image to display. 

	my $info = image_info($imgpath);
	if (my $error = $info->{error}) 
		{
		die "Can't parse image info: $error\n";
		}	
		
	#gonna reuse those variables.
	($namet,$patht,$suffixt) = fileparse($imgpath, qr/\.[^.]*/);
	

	#HTML printout.
	print $qreader->header(-type    => 'text/html',
                   -charset => 'utf-8');
	print $qreader->start_html
		(
		-title=>$arcname,
		-author=>'lanraragi-san',	
		-script=>[{-type=>'JAVASCRIPT',
							-src=>'./js/css.js'},
				  {-type=>'JAVASCRIPT',
							-src=>'./bower_components/jquery/dist/jquery.min.js'},
				  {-type=>'JAVASCRIPT',
							-src=>'./bower_components/jQuery-rwdImageMaps/jquery.rwdImageMaps.min.js'}],				
		-head=>[Link({-rel=>'icon', -type=>'image/png', -href=>'favicon.ico'}),
				meta({-name=>'viewport', -content=>'width=device-width'})],		
		-encoding => "utf-8",
		-style=>[{'src'=>'./styles/lrr.css'},
				{'src'=>'./bower_components/font-awesome/css/font-awesome.min.css'}],
		-onload=> "
					//dynamic html imagemap magic
					\$('img[usemap]').rwdImageMaps();

					set_style_from_storage();

					",
		);

	#The numbers of the pages we direct the reader to for the right/left arrows.
	#We print a hidden link with the "next" id for the reader JS to properly direct to the next page on spacebar press.
	my $leftpage=1;
	my $rightpage=1;

	if (&get_readorder==1)
		{
			$leftpage = $pagenum+1;
			$rightpage = $pagenum-1;
			print '<a id="next" href="./reader.pl?id='.$id.'&page='.($leftpage).'" style="display:none"></a>';
		}
		else
		{
			$leftpage = $pagenum-1;
			$rightpage = $pagenum+1;
			print '<a id="next" href="./reader.pl?id='.$id.'&page='.($rightpage).'" style="display:none"></a>';
		}

		
	print &printCssDropdown(0);
	print '<script>set_style_from_storage();</script>';
	print '<script src="./js/reader.js"></script>';
	#These are the pretty arrows you use to switch pages.
	my $arrows = '<div class="sn">
					<a href="./reader.pl?id='.$id.'&page=1"> <i class="fa fa-angle-double-left fa-2x"></i> </a> 
					<a id="left" href="./reader.pl?id='.$id.'&page='.($leftpage).'"> <i class="fa fa-angle-left fa-2x"></i> </a>
					<div class="pagecount"><span id ="current">'.$pagenum.'</span> / <span id ="max">'.($#images+1).'</span> </div>
					<a id="right" href="./reader.pl?id='.$id.'&page='.($rightpage).'"> <i class="fa fa-angle-right fa-2x"></i> </a>
					<a href="./reader.pl?id='.$id.'&page='.($#images+1).'"> <i class="fa fa-angle-double-right fa-2x"></i> </a></div>';
					
	#generate the floating div containing the help popup and the page dropdown
	my $pagesel = '<div style="position: absolute; right: 20px; z-index:20" class="page_dropdown" >
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

						<a href="#" onclick="alert(\'You can navigate between pages in different ways : \n* The arrow icons\n* Your keyboard arrows\n* Touching the left/right side of the image.\n\n To return to the archive index, touch the arrow pointing down.\')">
							<i class="fa fa-3x" style="padding-right: 10px; margin-top: -5px">?</i></a>	

				</div>';
	
	
	#Outputs something like "0001.png :: 1052 x 1500 :: 996.6 KB".
	my $size = (int((-s ($imgpath) )/ 1024*10)/10 ) ;
	
	my $imgwidth = $info->{width}; 
	my $imgheight = $info->{height}; 
	my $imgmapwidth = int($imgwidth/2 + 0.5);

	my $fileinfo ='<div id = "fileinfo">'. $namet.$suffixt .' :: '. $imgwidth .' x '. $imgheight .' :: '. $size .'KBs</div>';
	
	#We need to sanitize the image's path, in case the folder contains illegal characters, but uri_escape would also nuke the / needed for navigation.
	#Let's solve this with a quick regex search&replace.
	#First, we sanitize it all...
	$imgpath = escapeHTML($imgpath);
	
	#Then we bring the slashes back.
	$imgpath =~ s!%2F!/!g;
	
	print '<div id="i1" class="sni" style="max-width: 1200px">
			<h1>'.$arcname.'</h1>
			
			<div id="i2">'.$pagesel.$arrows.$fileinfo.'</div>
			
			<div id ="i3">
			
			<a id ="display">
			<img id="img" style="max-width:100%; height: auto; width: auto; " src="'.$imgpath.'" usemap="#Map" />
			<map name="Map" id="Map">
			    <area alt="" title="" href="./reader.pl?id='.$id.'&page='.($leftpage).'" shape="rect" coords="0,0,'.$imgmapwidth.','.$imgheight.'" />
			    <area alt="" title="" href="./reader.pl?id='.$id.'&page='.($rightpage).'" shape="rect" coords="'.($imgmapwidth+1).',0,'.$imgwidth.','.$imgheight.'" />
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
			<a href="./reader.pl?id='.$id.'&page='.$pagenum.'&force-reload=1">Clean Archive Cache</a>
			<i class="fa fa-caret-right fa-lg"></i>
			<a href="./reader.pl?id='.$id.'&reload_thumbnail=1">Regenerate Archive Thumbnail </a>
			</div>
			
			<div id="i7" class="if">
			<i class="fa fa-caret-right fa-lg"></i>
			<a href="'.$imgpath.'">View full-size image</a>
			</div>
			
		</div>';
} 
else 
{
    # No parameters back the fuck off
	print $qreader->header;
	print $qreader->start_html
		(
		-title=>&get_htmltitle,
		-author=>'lanraragi-san',
		-style=>{'src'=>'./styles/ex.css'},					
		-head=>[Link({-rel=>'icon',-type=>'image/png',-href=>'favicon.ico'})],			
		);
	
    print $qreader->redirect('./');
}

print $qreader->end_html;