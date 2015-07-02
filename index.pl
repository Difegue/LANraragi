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
use CGI::Ajax

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
$table->setSectionCellAttr('thead', 0, 1, 2, 'data-sort="title"');
$table->setSectionCellAttr('thead', 0, 1, 3, 'data-sort="artist"');
$table->setSectionCellAttr('thead', 0, 1, 4, 'data-sort="series"');
$table->setSectionCellAttr('thead', 0, 1, 5, 'data-sort="language"');
$table->setSectionCellAttr('thead', 0, 1, 6, 'data-sort="tags"');

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

			#It's not a new archive, though.
			$isnew="none";
			
			#Hash Slice! I have no idea how this works.
			($name,$event,$artist,$title,$series,$language,$tags) = @hash{qw(name event artist title series language tags)};
		}
	else	#can't be helped. Do it the old way, and add the results to redis afterwards.
		{
			#This means it's a new archive, though! We can notify the user about that later on.
			$isnew="block";
			
			($name,$path,$suffix) = fileparse($file, qr/\.[^.]*/);
			
			#parseName function is in config.pl
			($event,$artist,$title,$series,$language,$tags,$id) = &parseName($name.$suffix,$id);
			
			#jam dis shit in redis
			#prepare the hash which'll be inserted.
			my %hash = (
				name => encode_utf8($name),
				event => encode_utf8($event),
				artist => encode_utf8($artist),
				title => encode_utf8($title),
				series => encode_utf8($series),
				language => encode_utf8($language),
				tags => encode_utf8($tags),
				file => encode_utf8($file)
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
		$printedtags = qq(<a class="tags" style="text-overflow:ellipsis;">$printedtags</a><div class="ido caption" style="position:absolute;">$printedtags</div>); 
	}
	
	#version with hover thumbnails 
	if (&enable_thumbs)
	{
		#add row to table
		#ajaxThumbnail makes the thumbnail for that album if it doesn't already exist.
		my $thumbname = $dirname."/thumb/".$id.".jpg";
		$table->addRow($icons.qq(<input type="text" style="display:none;" id="$id" value="$id"/>),
						qq(<span style="display: none;">$title</span>
								<a href="./reader.pl?id=$id" 
									onmouseover="checkImage( '$thumbname', 
														function(){ showtrail('$thumbname') }, 
														function(){ showtrail('$thumbname'); ajaxThumbnail(['$id'],[]); } );" 
									onmouseout="hidetrail();">
								$title
								</a>
								<img src="img/n.gif" style="float: right; margin-top: -15px; z-index: -1; display: $isnew">
							),
						$artist,$series,$language,$printedtags);
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
	
	#Bind the ajax function to the getThumb subroutine.
	my $pjx = new CGI::Ajax( 'ajaxThumbnail' => \&getThumb );

	# BIG PRINTS		   
	sub printPage {
		my $html = start_html
			(
			-title=>&get_htmltitle,
			-author=>'lanraragi-san',
			-style=>[{'src'=>'./styles/lrr.css'},
					{'src'=>'//maxcdn.bootstrapcdn.com/font-awesome/4.3.0/css/font-awesome.min.css'}],
			-script=>[{-type=>'JAVASCRIPT',
							-src=>'https://raw.githubusercontent.com/javve/list.js/v1.1.1/dist/list.min.js'},
						{-type=>'JAVASCRIPT',
							-src=>'https://raw.githubusercontent.com/javve/list.pagination.js/v0.1.1/dist/list.pagination.min.js'},	
						{-type=>'JAVASCRIPT',
							-src=>'./js/thumb.js'},
						{-type=>'JAVASCRIPT',
							-src=>'./js/css.js'}],	
			-head=>[Link({-rel=>'icon',-type=>'image/png',-href=>'favicon.ico'}),],
			-encoding => "UTF-8",
			#on Load, initialize list.js and pages.
			-onLoad => "var table = document.getElementsByTagName('tbody');   
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
						"
			);
		

		#Dropdown list for changing CSSes on the fly.
		my $CSSsel = &printCssDropdown(1);
		
		$html = $html.'<p id="nb">

			<img alt="" src="./img/mr.gif"></img>
			<a href="./upload.pl">Upload Archive</a>
			<!--img alt="" src="./img/mr.gif"></img>
			<a href="./torrent.pl">Get Torrent</a>--!>
			<img alt="" src="./img/mr.gif"></img>
			<a href="./tags.pl">Import/Export Tags</a>
		</p>';
			
		$html = $html."<div class='ido' style='min-width: 1250px;'>
		<div id='toppane'>
		<h1 class='ih'>".&get_motd."</h1> 
		<div class='idi'>";

		#Adding CSS dropdown here!
		$html=$html.$CSSsel;

		$html = $html.'<script>
				//Set the correct CSS from the cookie on the users machine.
						set_style_from_cookie();
				</script>';
			
		#Search field (stdinput class in panda css)
		$html = $html."<input type='text' id='srch' class='search stdinput' size='90' placeholder='Search Title, Artist, Series, Language or Tags' /> <input class='stdbtn' type='button' onclick=\"window.location.reload();\" value='Clear Filter'/></div>";

		#Random button
		$html = $html."<p class='ip'><input class='stdbtn' type='button' onclick=\"window.location='random.pl';\" value='Give me a random archive'/></p>";
		
		#Paging and Archive Count
		$html = $html."<p class='ip' style='margin-top:-5px'> Serving a total of ".(scalar @dircontents)." chinese lithographies. </p>";
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
	#We let CGI::Ajax print the HTML we specified in the printPage sub, with the header options specified (utf-8)
	print $pjx->build_html($cgi, \&printPage,{-type => 'text/html', -charset => 'utf-8'});

