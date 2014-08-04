#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use HTML::Table;
use File::Basename;

use Archive::Zip qw/ :ERROR_CODES :CONSTANTS /;

#Require config 
require 'config.pl';

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
my ($event,$artist,$title,$series,$language,$tags,$id) = (" "," "," "," "," "," ");

opendir(DIR, &get_dirname) or die "Can't open the content directory ".&get_dirname.": $!";
while (defined($file = readdir(DIR))) 
{
    # let's do something with "&get_dirname/$file"
	($name,$path,$suffix) = fileparse("&get_dirname/$file", qr/\.[^.]*/);
	
	#Is it a zip archive?
	if ($suffix eq ".zip")
		{
		
		#parseName function is in edit.pl
		($event,$artist,$title,$series,$language,$tags,$id) = &parseName($name);
		
		my $thumbname = &get_dirname."/thumb/".$id.".jpg";
		#print $thumbname;
		
		#Has a thumbnail already been made? And is it enabled in config?
		unless (-e $thumbname)
		{ #if it doesn't, let's create it!
			my $zipFile = &get_dirname."/".$file;
			my $zip = Archive::Zip->new();
			
			unless ( $zip->read( $zipFile ) == AZ_OK ) 
			{  # Make sure archive got read
				die 'Archive parsing error!';
			}
			my @files = $zip->memberNames();  # Lists all members in archive. We'll extract the first one and resize it.
			
			@files = sort @files;
			
			my $filefullsize = &get_dirname."/thumb/".@files[0];
			$zip->extractMember( @files[0], $filefullsize);
			
			# use ImageMagick to make the thumbnail. I tried using PerlMagick but it's a piece of ass, can't get it to build :s
			#These lines fuck up with strict refs somehow... Might wanna fix that.
			
			#print $filefullsize $thumbname;
			print `convert -size 200x -geometry 200x -quality 75 $filefullsize $thumbname`;
			`rm $filefullsize`;
			
		}
		my $test = substr($thumbname,1);
		
		#WHAT THE FUCK AM I DOING
		#version with hover thumbnails
		my $icons = qq(<a href="&get_dirname/$file"><img src="./img/save.png"><a/> <a href="./edit.pl?file=$name"><img src="./img/edit.gif"><a/>);
		$table->addRow($icons,qq(<a href="./reader.pl?file=$name$suffix" onmouseover="showtrail(200,'$thumbname'.height,'$thumbname');" onmouseout="hidetrail();">$title</a>),$artist,$series,$language,$event." ".$tags);
		
		$table->setSectionClass ('tbody', -1, 'list' );
		#TODO: if thumbnail (and variable set to 1), add hover: thumbnail to the entire row.
		
		}	
}
closedir(DIR);

$table->setColClass(1,'itdc');
$table->setColClass(2,'title itd');
$table->setColClass(3,'artist itd');
$table->setColClass(4,'series itd');
$table->setColClass(5,'language itd');
$table->setColClass(6,'tags itu');
$table->setColWidth(1,36);

print header,start_html
	(
	-title=>&get_htmltitle,
    -author=>'lanraragi-san',
    -style=>{'src'=>'./styles/ex.css'},
	-script=>[{-type=>'JAVASCRIPT',
					-src=>'https://cdnjs.cloudflare.com/ajax/libs/list.js/1.1.1/list.min.js'},			
				{-type=>'JAVASCRIPT',
					-src=>'./js/thumb.js'}],	
	-head=>[Link({-rel=>'icon',-type=>'image/png',-href=>'favicon.ico'}),],
	
	#on Load, initialize list.js.
	-onLoad => "javascript:var options = {valueNames: ['title', 'artist', 'series', 'language', 'tags']};
							var mangoList = new List('toppane', options);
				document.getElementById('srch').value = '';" #and empty cached filter.
	);
	

	
print "<div class='ido'>
<div id='toppane'>
<h1 class='ih'>".&get_motd."</h1> 
<div class='idi'>";
	
#Search field (stdinput class in panda css)
print "<input type='text' id='srch' class='search stdinput' size='90' placeholder='Search Title, Artist, Series, Language or Tags' /> <input class='stdbtn' type='button' onclick=\"window.location.reload();\" value='Clear Filter'/></div>";

$table->print; #print our finished table

print "</div></div>";

print end_html; #close html
