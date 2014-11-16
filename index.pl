#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use HTML::Table;
use File::Path qw(make_path remove_tree);
use File::Basename;
use URI::Escape;
use Capture::Tiny qw(tee_stdout); 
use utf8;
use File::Find qw(find);

#Require config 
require 'config.pl';

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
my $count;
my @dircontents;
my $dirname = &get_dirname;

remove_tree($dirname.'/temp'); #Remove temp dir.

#print("Opening and reading files in content directory.. (".(time() - $^T)." seconds)\n");

my @filez = glob("$dirname/*.zip $dirname/*.rar $dirname/*.7z $dirname/*.tar $dirname/*.tar.gz $dirname/*.lzma $dirname/*.xz $dirname/*.cbz $dirname/*.cbr");

foreach $file (@filez) 
	{	
	push(@dircontents, $file);
	}
closedir(DIR);

#print("Parsing contents and making thumbnails...(".(time() - $^T)." seconds)\n");

foreach $file (@dircontents)
{
	#bis repetita
	#$fullfile = $dirname."/".$file;
	($name,$path,$suffix) = fileparse($file, qr/\.[^.]*/);
	
	#parseName function is in config.pl
	($event,$artist,$title,$series,$language,$tags,$id) = &parseName($name.$suffix);
		
	#sanitize we must.
	$name = uri_escape($name);
		
	my $icons = qq(<a href="$dirname/$name$suffix" title="Download this archive."><img src="./img/save.png"><a/> <a href="./edit.pl?file=$name$suffix" title="Edit this archive's tags and data."><img src="./img/edit.gif"><a/>);
	#WHAT THE FUCK AM I DOING
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
		my $zawa = &getThumb($id,$name.$suffix);
		$table->addRow($icons,qq(<span style="display: none;">$title</span><a href="./reader.pl?file=$name$suffix" onmouseover="showtrail('$zawa');" onmouseout="hidetrail();">$title</a>),$artist,$series,$language,$printedtags);
	}
	else #version without, ezpz
	{
		#add row to table
		$table->addRow($icons,qq(<span style="display: none;">$title</span><a href="./reader.pl?file=$name$suffix">$title</a>),$artist,$series,$language,$printedtags);
	}
		
	$table->setSectionClass ('tbody', -1, 'list' );
	
}


$table->setColClass(1,'itdc');
$table->setColClass(2,'title itd');
$table->setColClass(3,'artist itd');
$table->setColClass(4,'series itd');
$table->setColClass(5,'language itd');
$table->setColClass(6,'tags itu');
$table->setColWidth(1,36);

#print("Printing HTML...(".(time() - $^T)." seconds)");

#Everything printed in the following will be printed into index.html, effectively creating a cache. wow!
if (-e "index.html")
{
	unlink("index.html");
}

open(my $fh, ">", "index.html");

(my $stdout, $fh) = tee_stdout {
     # BIG PRINTS
	 
	print header,start_html
		(
		-title=>&get_htmltitle,
		-author=>'lanraragi-san',
		-style=>[{'src'=>'./styles/ex.css'},
					{'src'=>'./styles/lrr.css'}],
		-script=>[{-type=>'JAVASCRIPT',
						-src=>'https://raw.githubusercontent.com/javve/list.js/v1.1.1/dist/list.min.js'},
					{-type=>'JAVASCRIPT',
						-src=>'https://raw.githubusercontent.com/javve/list.pagination.js/v0.1.1/dist/list.pagination.min.js'},	
					{-type=>'JAVASCRIPT',
						-src=>'./js/thumb.js'}],	
		-head=>[Link({-rel=>'icon',-type=>'image/png',-href=>'favicon.ico'}),],
		-encoding => "utf-8",
		#on Load, initialize list.js and pages.
		-onLoad => "var table = document.getElementsByTagName('tbody');   
								var rows = table[0].getElementsByTagName('tr');
								
								var paginationTopOptions = {
										name: 'paginationTop',
										paginationClass: 'paginationTop', 
										}
								var paginationBottomOptions = {
										name: 'paginationBottom',
										paginationClass: 'paginationBottom', 
										}
								var options = {
												valueNames: ['title', 'artist', 'series', 'language', 'tags'], 
												page:".&get_pagesize.", outerWindow: 1, innerWindow:5,
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
					#empty the cached filter, while we're at it.
		);
	
	print '<p id="nb">

		<img alt="" src="./img/mr.gif"></img>
		<a href="./index.pl">Rebuild Front Page</a>
		<img alt="" src="./img/mr.gif"></img>
		<a href="./upload.pl">Upload Archive</a>
		<img alt="" src="./img/mr.gif"></img>
		<a href="./torrent.pl">Get Torrent</a>
		<img alt="" src="./img/mr.gif"></img>
		<a href="./tags.pl">Import/Export Tags</a>
	</p>';
		
	print "<div class='ido'>
	<div id='toppane'>
	<h1 class='ih'>".&get_motd."</h1> 
	<div class='idi'>";
		
	#Search field (stdinput class in panda css)
	print "<input type='text' id='srch' class='search stdinput' size='90' placeholder='Search Title, Artist, Series, Language or Tags' /> <input class='stdbtn' type='button' onclick=\"window.location.reload();\" value='Clear Filter'/></div>";

	#Paging and Archive Count
	print "<p class='ip' style='margin-top:5px'> Serving a total of ".(scalar @dircontents)." chinese lithographies. </p>";
	print "<ul class='paginationTop' style='margin:2px auto 0px; text-align:center; border-top:0;' ></ul>";

	$table->print; #print our finished table

	print "<ul class='paginationBottom' style='margin:0px auto 10px; text-align:center; border-bottom:0;' ></ul></div></div>";

	print '		<p class="ip">
				[
				<a href="https://github.com/Difegue/LANraragi">
					Spread da word, yo.
				</a>
				]
			</p>';
			
	print end_html; #close html
} stdout => $fh;
	
#clean up our index.html a bit. 
#With straight STDOUT to file, "Content-Type: text/html; charset=ISO-8859-1 " is added at the beginning.
#Remove the first line with code ripped from stackoverflow (again):
use Tie::File;
my @array;
tie @array, 'Tie::File', './index.html' or die $!;
shift @array;
shift @array;
untie @array;
