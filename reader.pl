#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use Redis;

require 'config.pl';
require 'functions/functions_generic.pl';
require 'functions/functions_reader.pl';


	my $qreader = new CGI;

	if ($qreader->param()) 
	{
	    # We got a file name, let's get crackin'.
		my $id = $qreader->param('id');

		#Quick Redis check to see if the ID exists:
		my $redis = Redis->new(server => &get_redisad, 
					reconnect => 100,
					every     => 3000);

		unless ($redis->hexists($id,"title"))
			{
				print &redirectToPage($qreader,"index.pl");
				exit;
			}

		#Get a computed archive name if the archive exists
		my $arcname = $redis->hget($id,"title")." by ".$redis->hget($id,"artist");
		$arcname = decode_utf8($arcname);


		print $qreader->header(-type => 'text/html',
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
		
		my $force = $qreader->param('force-reload');
		my $thumbreload = $qreader->param('reload_thumbnail');
		my $imgpath = "";
		my $arcpages = 0;

		if ($qreader->param('page')) 
			{ 
				($imgpath, $arcpages) = &getImage($id,$force,$thumbreload,$qreader->param('page'));
				print &printReaderHTML($id,$imgpath,$arcname,$arcpages,$qreader->param('page'));  #$imgpath is the path to the image we want to display, $arcpages is the total number of pages in the archive.
			}
		else
		 	{ 
		 		($imgpath, $arcpages) = &getImage($id,$force,$thumbreload); 
		 		print &printReaderHTML($id,$imgpath,$arcname,$arcpages);
		 	}
		
	} 
	else 
	{
	    # No parameters back the fuck off
	    print &redirectToPage($qreader,"index.pl");
	}

	print $qreader->end_html;





	#printReaderHTML(id,extractedImage,archiveName,archiveTotalPages, pagenum)
	#HTML printout. Pretty dirty, should be replaced by templates one day.
	sub printReaderHTML
	 {

		my $html = "";

		my ( $id, $imgpath, $arcname, $arcpages, $pagenum) = @_;

		unless (defined $pagenum)
			{$pagenum = 1;}

		if ($pagenum >= $arcpages)
			{$pagenum = $arcpages;}

		#Let's get more precise info on the image to display. 
		my $info = image_info($imgpath);
			
		#gonna reuse those variables.
		my ($namet,$patht,$suffixt) = fileparse($imgpath, qr/\.[^.]*/);

		#The numbers of the pages we direct the reader to for the right/left arrows.
		#We print a hidden link with the "next" id for the reader JS to properly direct to the next page on spacebar press.
		my $leftpage=1;
		my $rightpage=1;

		if (&get_readorder==1)
			{
				$leftpage = $pagenum+1;
				$rightpage = $pagenum-1;
				$html.='<a id="next" href="./reader.pl?id='.$id.'&page='.($leftpage).'" style="display:none"></a>';
			}
			else
			{
				$leftpage = $pagenum-1;
				$rightpage = $pagenum+1;
				$html.='<a id="next" href="./reader.pl?id='.$id.'&page='.($rightpage).'" style="display:none"></a>';
			}

			
		$html.=&printCssDropdown(0);
		$html.='<script>set_style_from_storage();</script>';
		$html.='<script src="./js/reader.js"></script>';
		#These are the pretty arrows you use to switch pages.
		my $arrows = '<div class="sn">
						<a href="./reader.pl?id='.$id.'&page=1"> <i class="fa fa-angle-double-left fa-2x"></i> </a> 
						<a id="left" href="./reader.pl?id='.$id.'&page='.($leftpage).'"> <i class="fa fa-angle-left fa-2x"></i> </a>
						<div class="pagecount"><span id ="current">'.$pagenum.'</span> / <span id ="max">'.$arcpages.'</span> </div>
						<a id="right" href="./reader.pl?id='.$id.'&page='.($rightpage).'"> <i class="fa fa-angle-right fa-2x"></i> </a>
						<a href="./reader.pl?id='.$id.'&page='.$arcpages.'"> <i class="fa fa-angle-double-right fa-2x"></i> </a></div>';
						
		#generate the floating div containing the help popup and the page dropdown
		my $pagesel = '<div style="position: absolute; right: 20px; z-index:20" class="page_dropdown" >
					<form style="float: right;"><select size="1"  onChange="location = this.options[this.selectedIndex].value;">';

		#We opened a drop-down list. Now, we'll fill it.
		for ( my $i = 1; $i < $arcpages+1; $i++) 
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
		
		#This is our output.
		$html.='<div id="i1" class="sni" style="max-width: 1200px">
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

		return $html;

	 }