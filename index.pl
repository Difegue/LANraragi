#!/usr/bin/perl

use strict;
use CGI qw/:standard/;
use HTML::Table;
use File::Path qw(make_path remove_tree);
use File::Basename;
use Capture::Tiny qw(tee_stdout); 
use Encode;
use File::Find qw(find);
use Redis;
use Digest::SHA qw(sha256_hex);

#Require config 
require 'config.pl';
require 'functions.pl';

#print("Setting up main table..\n");

#my $q = CGI->new;  #our html 
#my $table = new HTML::Table(0,6);
my $table = new HTML::Table(-rows=>0,
                            -cols=>6,
                            -class=>'itg'
                            );

$table->addSectionRow ( 'thead', 0, "",'<a class="sort desc" data-sort="title">Title</a>','<a class="sort desc" data-sort="artist">Artist/Group</a>','<a class="sort desc" data-sort="series">Series</a>'," Language"," Tags");
$table->setSectionRowHead('thead', -1, -1, 1);

#Special parameters for list.js implementation (i want to die)
$table->setSectionCellAttr('thead', 0, 1, 2, 'data-sort="title" id="titleheader"');
$table->setSectionCellAttr('thead', 0, 1, 3, 'data-sort="artist" id="artistheader"');
$table->setSectionCellAttr('thead', 0, 1, 4, 'data-sort="series" id="seriesheader"');
$table->setSectionCellAttr('thead', 0, 1, 5, 'data-sort="language" id="langheader"');
$table->setSectionCellAttr('thead', 0, 1, 6, 'data-sort="tags" id="tagsheader"');

#define variables
my $file = "";
my $path = "";
my $suffix = "";
my $name = "";
my $thumbname = "";
my ($event,$artist,$title,$series,$language,$tags,$id) = (" "," "," "," "," "," ");
my $fullfile="";
my $isnew = "none";
my $count;
my @dircontents;
my $dirname = &get_dirname;

#Default redis server location is localhost:6379. 
#Auto-reconnect on, one attempt every 100ms up to 2 seconds. Die after that.
my $redis = Redis->new(server => &get_redisad, 
						reconnect => 100,
						every     => 3000);

remove_tree($dirname.'/temp'); #Remove temp dir.

#print("Opening and reading files in content directory.. (".(time() - $^T)." seconds)\n");

#This should be enough supported file extensions, right? The old lsar method was hacky and took too long.
my @filez = glob("$dirname/*.zip $dirname/*.rar $dirname/*.7z $dirname/*.tar $dirname/*.tar.gz $dirname/*.lzma $dirname/*.xz $dirname/*.cbz $dirname/*.cbr");

foreach $file (@filez) 
	{	
	push(@dircontents, $file);
	}
closedir(DIR);

#print("Parsing contents and making thumbnails...(".(time() - $^T)." seconds)\n");

foreach $file (@dircontents)
{
	#ID of the archive, used for storing data in Redis.
	$id = sha256_hex($file);

	#Let's check out the Redis cache first! It might already have the info we need.
	if ($redis->hexists($id,"title"))
		{
			#bingo, no need for expensive file parsing operations.
			my %hash = $redis->hgetall($id);

			#It's not a new archive, though. But it might have never been clicked on yet, so we'll grab the value for $isnew stored in redis.

			#Hash Slice! I have no idea how this works.
			($name,$event,$artist,$title,$series,$language,$tags,$isnew) = @hash{qw(name event artist title series language tags isnew)};
		}
	else	#can't be helped. Do it the old way, and add the results to redis afterwards.
		{
			#This means it's a new archive, though! We can notify the user about that later on, and specify it in the hash.
			$isnew="block";
			
			($name,$path,$suffix) = fileparse($file, qr/\.[^.]*/);
			
			#parseName function is in config.pl
			($event,$artist,$title,$series,$language,$tags,$id) = &parseName($name.$suffix,$id);
			
			#jam this shit in redis
			#prepare the hash which'll be inserted.
			my %hash = (
				name => encode_utf8($name),
				event => encode_utf8($event),
				artist => encode_utf8($artist),
				title => encode_utf8($title),
				series => encode_utf8($series),
				language => encode_utf8($language),
				tags => encode_utf8($tags),
				file => encode_utf8($file),
				isnew => encode_utf8($isnew),
				);
				
			#for all keys of the hash, add them to the redis hash $id with the matching keys.
			$redis->hset($id, $_, $hash{$_}, sub {}) for keys %hash; 
			$redis->wait_all_responses;
		}
		
	#Parameters have been obtained, let's decode them.
	($_ = decode_utf8($_)) for ($name, $event, $artist, $title, $series, $language, $tags, $file);
	
	my $icons = qq(<div style="font-size:14px"><a href="$dirname/$name$suffix" title="Download this archive."><i class="fa fa-save"></i><a/> 
					<a href="./edit.pl?id=$id" title="Edit this archive's tags and data."><i class="fa fa-pencil"></i><a/></div>);
			#<a href="./tags.pl?id=$id" title="E-Hentai Tag Import (Unfinished)."><i class="fa fa-server"></i><a/>
			
	#When generating the line that'll be added to the table, user-defined options have to be taken into account.
	#Truncated tag display. Works with some hella disgusting CSS shit.
	my $printedtags = $event." ".$tags;
	if (length $printedtags > 50)
	{
		$printedtags = qq(<a class="tags" style="text-overflow:ellipsis;">$printedtags</a><div class="caption" style="position:absolute;">$printedtags</div>); 
	}
	
	#version with hover thumbnails 
	if (&enable_thumbs)
	{
		#ajaxThumbnail makes the thumbnail for that album if it doesn't already exist. 
		#(If it fails for some reason, it won't return an image path, triggering the "no thumbnail" image on the JS side.)
		my $thumbname = $dirname."/thumb/".$id.".jpg";

		my $row = qq(<span style="display: none;">$title</span>
								<a href="./reader.pl?id=$id" );

		if (-e $thumbname)
		{
			$row.=qq(onmouseover="thumbTimeout = setTimeout(showtrail, 200,'$thumbname')" );
		}
		else
		{
			$row.=qq(onmouseover="thumbTimeout = setTimeout(ajaxThumbnail, 200,'$id')" );
		}
									
		$row.=qq(onmouseout="hidetrail(); clearTimeout(thumbTimeout);">
								$title
								</a>
								<img src="img/n.gif" style="float: right; margin-top: -15px; z-index: -1; display: $isnew">); #user is notified here if archive is new (ie if it hasn't been clicked on yet)

		#add row for this archive to table
		$table->addRow($icons.qq(<input type="text" style="display:none;" id="$id" value="$id"/>),$row,$artist,$series,$language,$printedtags);
	}
	else #version without, ezpz
	{
		#add row to table
		$table->addRow($icons,qq(<span style="display: none;">$title</span><a href="./reader.pl?id=$id" title="$title">$title</a>),$artist,$series,$language,$printedtags);
	}
		
	$table->setSectionClass ('tbody', -1, 'list' );
	
}


$table->setColClass(1,'itdc');
$table->setColClass(2,'title itd');
$table->setColClass(3,'artist itd');
$table->setColClass(4,'series itd');
$table->setColClass(5,'language itd');
$table->setColClass(6,'tags itu');
$table->setColWidth(1,30);

	#print("Printing HTML...(".(time() - $^T)." seconds)");
	my $cgi = new CGI;

	# BIG PRINTS		   
	sub printPage {
		my $html = start_html
			(
			-title=>&get_htmltitle,
			-author=>'lanraragi-san',
			-style=>[{'src'=>'./styles/lrr.css'},
					{'src'=>'//maxcdn.bootstrapcdn.com/font-awesome/4.3.0/css/font-awesome.min.css'}],
			-script=>[{-type=>'JAVASCRIPT',
							-src=>'./js/list.min.js'},
						{-type=>'JAVASCRIPT',
							-src=>'./js/list.pagination.min.js'},	
						{-type=>'JAVASCRIPT',
							-src=>'./js/jquery-2.1.4.min.js'},
						{-type=>'JAVASCRIPT',
							-src=>'./js/dropit.js'},
						{-type=>'JAVASCRIPT',
							-src=>'./js/ajax.js'},	
						{-type=>'JAVASCRIPT',
							-src=>'./js/thumb.js'},
						{-type=>'JAVASCRIPT',
							-src=>'./js/css.js'}],	
			-head=>[Link({-rel=>'icon',-type=>'image/png',-href=>'favicon.ico'}),
					meta({-name=>'viewport', -content=>'width=device-width'})],
			-encoding => "UTF-8",
			#on Load, initialize list.js and pages.
			-onLoad => "var table = document.getElementsByTagName('tbody');   

									var thumbTimeout = null;

									var rows = table[0].getElementsByTagName('tr');
									
									var paginationTopOptions = {
											name: 'paginationTop',
											paginationClass: 'paginationTop', 
											innerWindow:5,
											outerWindow:2,
											}
									var paginationBottomOptions = {
											name: 'paginationBottom',
											paginationClass: 'paginationBottom', 
											innerWindow:5,
											outerWindow:2,
											}
									var options = {
													valueNames: ['title', 'artist', 'series', 'language', 'tags'], 
													page:".&get_pagesize.",
													plugins: [ 
													ListPagination(paginationTopOptions),
													ListPagination(paginationBottomOptions) 
													]
												};
									var mangoList = new List('toppane', options);
									mangoList.sort('title', { order: 'asc' });
									
									mangoList.on('updated',function(){
										for (i = 0; i < rows.length; i++){           
											if(i % 2 == 0)
												{rows[i].className = 'gtr0'; } 
											else {rows[i].className = 'gtr1'; }      
										}
										});
									
									for (i = 0; i < rows.length; i++){           
										if(i % 2 == 0)
											{rows[i].className = 'gtr0'; } 
										else {rows[i].className = 'gtr1'; }      
									}
									
						document.getElementById('srch').value = ''; 

						//Set the correct CSS from the user's localStorage.
						set_style_from_storage();

						//Initialize CSS dropdown with dropit
						\$('.menu').dropit();

						"
			);
		

		#Dropdown list for changing CSSes on the fly.
		my $CSSsel = &printCssDropdown(1);
		
		$html = $html.'<p id="nb">

			<i class="fa fa-caret-right"></i>
			<a href="./upload.pl">Upload Archive</a>
			<span style="margin-left:5px"></span>
			<i class="fa fa-caret-right"></i>
			<a href="./stats.pl">Statistics</a>
			<span style="margin-left:5px"></span>
			<i class="fa fa-caret-right"></i>
			<a href="./tags.pl">Import/Export Tags</a>
		</p>';
			
		$html = $html."<div class='ido'>
		<div id='toppane'>
		<h1 class='ih'>".&get_motd."</h1> 
		<div class='idi'>";
			
		#Search field (stdinput class in panda css)
		$html = $html."<input type='text' id='srch' class='search stdinput' size='90' placeholder='Search Title, Artist, Series, Language or Tags' /> <input class='stdbtn' type='button' onclick=\"window.location.reload();\" value='Clear Filter'/></div>";

		#Random button + CSS dropdown with popr
		$html = $html."<p class='ip' style='display:inline'><input class='stdbtn' type='button' onclick=\"window.location='random.pl';\" value='Give me a random archive'/>".$CSSsel."</p>";
		
		#Paging and Archive Count
		$html = $html."<p class='ip'> Serving a total of ".(scalar @dircontents)." chinese lithographies. </p>";
		$html = $html."<ul class='paginationTop' style=' text-align:center; border-top:0;' ></ul>";

		$html = $html.($table->getTable); #print our finished table

		$html = $html."<ul class='paginationBottom' style=' text-align:center; border-bottom:0;' ></ul></div></div>";

		$html = $html.'		<p class="ip">
					<a href="https://github.com/Difegue/LANraragi">
						Sorry, I stuttered.
					</a>
				</p>';
				
		$html = $html.end_html; #close html
		return $html;
	}
	
	$redis->quit();

	#We print the html we generated.
	print $cgi->header(-type    => 'text/html',
                   -charset => 'utf-8');
	print &printPage;
