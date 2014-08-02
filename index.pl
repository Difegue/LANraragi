#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use Cwd;
use HTML::Table;
use File::Basename;

#Require other .pl's to be present 
require 'config.pl';
require 'edit.pl';

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
							
$table->setSectionStyle ( 'thead', 0, 'font-weight:bold;' );
$table->addSectionRow ( 'thead', 0, ""," Title"," Artist/Group"," Series"," Language"," Tags");

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
my ($event,$artist,$title,$series,$language,$tags) = (" "," "," "," "," "," ");

opendir(DIR, &get_dirname) or die "can't opendir".&get_dirname.": $!";
while (defined($file = readdir(DIR))) 
{
    # let's do something with "&get_dirname/$file"
	($name,$path,$suffix) = fileparse("&get_dirname/$file", qr/\.[^.]*/);
	
	#Is it a zip archive?
	if ($suffix eq ".zip")
		{
		
		#parseName function is in edit.pl
		($event,$artist,$title,$series,$language,$tags) = &parseName($name);
		
		#WHAT THE FUCK AM I DOING
		my $icons = "<a href='".&get_dirname."/$file'><img src='./img/save.png'><a/> <a href='./edit.pl?file=$name'><img src='./img/edit.gif'><a/> ";
		$table->addRow($icons,"<a href='./reader.pl?file=$name$suffix'>$title</a>",$artist,$series,$language,$event." ".$tags);
		
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

print header,start_html
	(
	-title=>&get_htmltitle,
    -author=>'lanraragi-san',
    -style=>{'src'=>'./styles/ex.css'},
	-script=>{-type=>'JAVASCRIPT',
					-src=>'https://cdnjs.cloudflare.com/ajax/libs/list.js/1.1.1/list.min.js'},					
	-head=>[Link({-rel=>'icon',-type=>'image/png',-href=>'favicon.ico'}),],
	#onLoad, initialize list.js.
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
