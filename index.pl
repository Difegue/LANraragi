#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use HTML::Table;
use File::Path qw(make_path remove_tree);
use File::Basename;
use URI::Escape;
use File::Tee qw(tee);
use Image::Info qw(image_info dim);
use utf8;
use File::Find qw(find);

#Require config 
require 'config.pl';

remove_tree(&get_dirname.'/temp'); #Remove temp dir.

my $q = CGI->new;  #our html 
my $table = new HTML::Table(0,6);
my $table = new HTML::Table(-rows=>0,
                            -cols=>6,
                            #-align=>'center',
                            #-rules=>'rows',
                            #-border=>0,
                            #-bgcolor=>'blue',
                            #-width=>'50%',
                            #-spacing=>0,
                            #-padding=>0,
                            #-style=>'color: blue',
                            -class=>'itg',
                            -evenrowclass=>'gtr0',
                            -oddrowclass=>'gtr1');
							

$table->addSectionRow ( 'thead', 0, ""," Title"," Artist/Group"," Series"," Language"," Tags");
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

opendir(DIR, &get_dirname) or die "Can't open the content directory ".&get_dirname.": $!";

while (defined($file = readdir(DIR))) 
	{
	$fullfile = &get_dirname."/".$file;
	
	#print $fullfile."/n";
    # let's do something with "&get_dirname/$file"
	($name,$path,$suffix) = fileparse($fullfile, qr/\.[^.]*/);
	
	#We need to test if it's an archive unar can handle.
	#For this, we use lsar. lsar prints at least two lines upon a successful detection. it's kinda hacky, but it works. Even on Windows!
	
	my $filez = "lsaroutput";
	unlink $filez;
	`lsar "$fullfile" >> $filez`;
	
	open(FILE, "< $filez") or die "can't open $filez: $!"; 
	for ($count=0; <FILE>; $count++) { } #counts line through a for statement. the iterator is our line number.
	
	if ($count >1)
		{push(@dircontents, $file);}
	
	}

@dircontents = &parseSort(@dircontents);

foreach $file (@dircontents)
{
	#bis repetita
	$fullfile = &get_dirname."/".$file;
	($name,$path,$suffix) = fileparse($fullfile, qr/\.[^.]*/);
	
	my $dirname = &get_dirname; #calling the function in strings doesn't work too well.
	#parseName function is in edit.pl
	($event,$artist,$title,$series,$language,$tags,$id) = &parseName($name.$suffix);
		
	#sanitize we must.
	$name = uri_escape($name);
	
	if (&enable_thumbs)
	{
			$thumbname = $dirname."/thumb/".$id.".jpg";
			#print $thumbname;
			
			#Has a thumbnail already been made? And is it enabled in config?
			unless (-e $thumbname)
			{ #if it doesn't, let's create it!
			
				my $zipFile = $dirname."/".$file;
				
				my $path = $dirname."/thumb/temp";		
				
				`unar -D -o $path "$zipFile"`; #Extract the archive with unar. 
				#In case you're wondering why I extract it all instead of only extracting the first file, the -i 0 option doesn't always return the first image.
				#So I extract them all and sort before picking the first. I could work with lsar but fuck that shit it's too bothersome, extracting is far from being the longest task in this anyway (that award goes to convert)
								
				#gotta find the image..
				my @extracted;
				find({ wanted => sub { 
										if ($_ =~ /^(.*\/)*.+\.(png|jpg|gif|bmp|jpeg|PNG|JPG|GIF|BMP)$/ ) #is it an image? readdir tends to read folder names too...
											{push @extracted, $_ }
									} , no_chdir => 1 }, $path); #find () does exactly that. 
		
				@extracted = sort { lc($a) cmp lc($b) } @extracted;
				
				#use ImageMagick to make the thumbnail. I tried using PerlMagick but it's a piece of ass, can't get it to build :s
				`convert -size 200x -geometry 200x -quality 75 "@extracted[0]" $thumbname`;
				
				#Delete the previously extracted files.
				foreach (@extracted)
					{unlink $_};
			}
	}
		
	my $icons = qq(<a href="$dirname/$file" title="Download this archive."><img src="./img/save.png"><a/> <a href="./edit.pl?file=$name$suffix" title="Edit this archive's tags and data."><img src="./img/edit.gif"><a/>);
	#WHAT THE FUCK AM I DOING
	#When generating the line that'll be added to the table, user-defined options have to be taken into account.
		
	#version with hover thumbnails 
	if (&enable_thumbs)
	{
		my $height = image_info($thumbname);
		$height = $height->{height};
		
		$table->addRow($icons,qq(<a href="./reader.pl?file=$name$suffix" onmouseover="showtrail(200,$height,'$thumbname');" onmouseout="hidetrail();">$title</a>),$artist,$series,$language,$event." ".$tags);
	}
	else #version without. ezpz
	{
		$table->addRow($icons,qq(<a href="./reader.pl?file=$name$suffix">$title</a>),$artist,$series,$language,$event." ".$tags);
	}
		
	$table->setSectionClass ('tbody', -1, 'list' );
	
}
closedir(DIR);

$table->setColClass(1,'itdc');
$table->setColClass(2,'title itd');
$table->setColClass(3,'artist itd');
$table->setColClass(4,'series itd');
$table->setColClass(5,'language itd');
$table->setColClass(6,'tags itu');
$table->setColWidth(1,36);

#let's print the HTML.

#Everything printed in the following will be printed into index.html, effectively creating a cache. wow!
if (-e "index.html")
{
	unlink("index.html");
}
tee(STDOUT, '>', 'index.html');

print header,start_html
	(
	-title=>&get_htmltitle,
    -author=>'lanraragi-san',
    -style=>{'src'=>'./styles/ex.css'},
	-script=>[{-type=>'JAVASCRIPT',
					-src=>'https://raw.githubusercontent.com/javve/list.js/v1.1.1/dist/list.min.js'},			
				{-type=>'JAVASCRIPT',
					-src=>'./js/thumb.js'}],	
	-head=>[Link({-rel=>'icon',-type=>'image/png',-href=>'favicon.ico'}),],
	-encoding => "utf-8",
	#on Load, initialize list.js.
	-onLoad => "javascript:var options = {valueNames: ['title', 'artist', 'series', 'language', 'tags']};
							var mangoList = new List('toppane', options);
				document.getElementById('srch').value = '';" #empty cached filter, while we're at it.
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

$table->print; #print our finished table

print "</div></div>";

print '		<p class="ip">
			[
			<a href="https://github.com/Difegue/LANraragi">
				Spread da word, yo.
			</a>
			]
		</p>';
		
print end_html; #close html

#clean up our index.html a bit. 
#With straight STDOUT to file, "Content-Type: text/html; charset=ISO-8859-1 " is added at the beginning.
#Remove the first line with code ripped from stackoverflow (again):
use Tie::File;
my @array;
tie @array, 'Tie::File', './index.html' or die $!;
shift @array;
shift @array;
untie @array;
