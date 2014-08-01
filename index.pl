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
$table->addRow("","Title","Artist","Series","Language","Tags");

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
		#Parse function is in edit.pl
		($event,$artist,$title,$series,$language,$tags) = &parseName($name);
		
		#WHAT THE FUCK AM I DOING
		my $icons = "<a href=\"".&get_dirname."/$file\"><img src=\"save.png\"><a/> <a href=\"./edit.pl?file=$name\"><img src=\"edit.gif\"><a/> ";
		$table->addRow($icons,"<a href=\"./reader.pl?file=$name$suffix\">$title</a>",$artist,$series,$language,$event." ".$tags)
		
		#TODO: if thumbnail (and variable set to 1), add hover: thumbnail to the entire row.
		
		}	
}
closedir(DIR);

print header,start_html
	(
	-title=>&get_htmltitle,
    -author=>'lanraragi-san',
    -style=>{'src'=>'./styles/mayoi.css'},
	-script=>{-type=>'JAVASCRIPT',
			  -src=>'./search.js'}
	);

	
#TODO: print motd and search box here

$table->print;#print our finished table

print end_html; #close html
