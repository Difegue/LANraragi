#!/usr/bin/perl

use strict;
use CGI qw/:standard/;
use Redis;

#Require config 
require 'config.pl';
require 'functions/functions_generic.pl';
require 'functions/functions_index.pl';
require 'functions/functions_login.pl';


	my $dirname = &get_dirname;

	#Get all files in content directory.
	#This should be enough supported file extensions, right? The old lsar method was hacky and took too long.
	my @filez = glob("$dirname/*.zip $dirname/*.rar $dirname/*.7z $dirname/*.tar $dirname/*.tar.gz $dirname/*.lzma $dirname/*.xz $dirname/*.cbz $dirname/*.cbr");

	#Default redis server location is localhost:6379. 
	#Auto-reconnect on, one attempt every 100ms up to 2 seconds. Die after that.
	my $redis = Redis->new(server => &get_redisad, 
							reconnect => 100,
							every     => 3000);

	remove_tree($dirname.'/temp'); #Remove temp dir.

	my $table;
	#From the file tree, generate the HTML table
	if (@filez)
	{ $table = &generateTableJSON(@filez); }
	else
	{ $table = "[]"}
	$redis->quit();


	#Actual HTML output
	my $cgi = new CGI;

	#We print the html we generated.
	print $cgi->header(-type    => 'text/html',
                   -charset => 'utf-8');

	print &printPage($table,$cgi);





	# BIG PRINTS		   
	sub printPage {

		my $table = $_[0];
		my $cgi = $_[1];
		my $pagesize = &get_pagesize;
		my $title = &get_htmltitle;
		my $html = qq(
		<html>
			<head>
				<title>$title</title>

				<meta name="viewport" content="width=device-width" />
				<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
				
				<link type="image/png" rel="icon" href="./img/favicon.ico" />
				<link rel="stylesheet" type="text/css" href="./styles/lrr.css" />
				<link rel="stylesheet" type="text/css" href="./bower_components/font-awesome/css/font-awesome.min.css" />

				<script src="./bower_components/jquery/dist/jquery.min.js" type="text/JAVASCRIPT"></script>
				<script src="./bower_components/datatables/media/js/jquery.dataTables.min.js" type="text/JAVASCRIPT"></script>
				<script src="./bower_components/dropit/dropit.js" type="text/JAVASCRIPT"></script>
				<script src="./js/ajax.js" type="text/JAVASCRIPT"></script>
				<script src="./js/index.js" type="text/JAVASCRIPT"></script>
				<script src="./js/css.js" type="text/JAVASCRIPT"></script>
				
			</head>);


		$html.=qq(<body onload ="initIndex($pagesize,archiveJSON);">);

		if (&isUserLogged($cgi))
		{
			$html.='<p id="nb">
			<i class="fa fa-caret-right"></i>
			<a href="./upload.pl">Upload Archive</a>
			<span style="margin-left:5px"></span>
			<i class="fa fa-caret-right"></i>
			<a href="./tags.pl">Batch Tagging</a>
			<span style="margin-left:5px"></span>
			<i class="fa fa-caret-right"></i>
			<a href="./config.pl">Configuration</a>
			</p>';
		}
		else
		{
			$html.='<p id="nb">
			<i class="fa fa-caret-right"></i>
			<a href="./login.pl">Admin Login</a>
			</p>';	
		}
		
			
		$html.="<div class='ido'>
		<div id='toppane'>
		<h1 class='ih'>".&get_motd."</h1> 
		<div class='idi'>";
			
		#Search field (stdinput class in panda css)
		$html.="<input type='text' id='srch' class='search stdinput' size='90' placeholder='Search Title, Artist, Series, Language or Tags' /> <input id='clrsrch' class='stdbtn' type='button' value='Clear Filter'/></div>";

		#Dropdown list for changing CSSes on the fly.
		my $CSSsel = &printCssDropdown(1);

		#Random button + CSS dropdown with dropit. These can't be generated in JS, the styles need to be loaded asap.
		$html.="<p id='cssbutton' style='display:inline'><input class='stdbtn' type='button' onclick=\"var win=window.open('random.pl','_blank'); win.focus();\" value='Give me a random archive'/>".$CSSsel."</p>";

		#$html.="$table"; #print our finished table

		$html.=qq(<table class="itg">
					<thead>
					<tr>
					<th></th>
						<th id="titleheader"><a>Title</a></th>
						<th id="artistheader"><a>Artist/Group</a></th>
						<th id="seriesheader"><a>Series</a></th>
						<th id="langheader"><a>Language</a></th>
						<th id="tagsheader"><a>Tags</a></th>
					</tr>
					</thead>
					<tbody class="list">
					</tbody></table>);

		$html.="</div></div>"; #close errything

		$html.='		<p class="ip">
					<a href="https://github.com/Difegue/LANraragi">
						Sorry, I stuttered.
					</a>
				</p>';
				
		$html.=qq(
			<script>
			//Set the correct CSS from the user's localStorage.
			set_style_from_storage();

			//Init thumbnail hover
			showtrail('img/noThumb.png');

			archiveJSON = $table;

			</script>);


		$html.="</body></html>"; #close html
		return $html;
	}


