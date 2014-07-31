#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use Cwd;
use HTML::Table;
use File::Basename;

#Require other .pl's to be present 
BEGIN { require 'config.pl'; }
#BEGIN { require 'reader.pl'; }

my $q = CGI->new;  #our html 
my $table = new HTML::Table(0,6);
$table->addRow("","Title","Artist","Series","Language","Tags");

my $dirname = "./content";
my $file = "";
my $path = "";
my $suffix = "";
my $name = "";
#define variables
my ($event,$artist,$title,$series,$language,$tags) = (" "," "," "," "," "," ");

opendir(DIR, $dirname) or die "can't opendir $dirname: $!";
while (defined($file = readdir(DIR))) {
    # do something with "$dirname/$file"
	
	($name,$path,$suffix) = fileparse("$dirname/$file", qr/\.[^.]*/);
	#Is it a zip archive?
	if ($suffix eq ".zip")
		{
		#Check for Thumbnail presence and create it if needed
		
		
		my @values=(" "," ");
		my $temp=$name;
		#Split up the filename
		#Is the field present? If not, skip it.
		if (substr($temp, 0, 1)eq'(') 
			{
			@values = split('\)', $name, 2); # (Event)
			$event = substr($values[0],1);
			$temp = $values[1];
			}
			
		if (substr($temp, 0, 1)eq"[") 
			{
			@values = split(']', $temp, 2); # [Artist (Pseudonym)]
			$artist = substr($values[0],1);
			$temp = $values[1];
			}
			
		#Always needs something in title, so it can't be empty
		@values = split('\(', $temp, 2); #Title. If there's no following (Series), the entire filename is taken and other variables are emptied by default. ┐(￣ー￣)┌
		$title = $values[0];
		$temp = $values[1];
		
		@values = split('\)', $temp, 2); #Series
		$series = $values[0];
		$temp = $values[1];
		
		@values = split(']', $temp, 2); #Language
		$language = substr($values[0],1);
		$temp = $values[1];
		
		#does the filename contain tags?
		if (substr($temp, 0, 1)eq"%") 
		{
			$tags = substr($temp,1); #only tags left
		}
		
		#WHAT THE FUCK AM I DOING
		my $icons = "<a href=\"./content/$file\"><img src=\"save.png\"><a/> <a href=\"./edit.pl?file=$name$suffix\"><img src=\"edit.gif\"><a/> ";
		$table->addRow($icons,"<a href=\"./reader.pl?file=$name$suffix\">$title</a>",$artist,$series,$language,$event." ".$tags)
		
		#TODO: if thumbnail (and variable set to 1), add hover: thumbnail to the entire row.
		}
		
		
}
closedir(DIR);

print header,start_html
	(
	-title=>'LANraragi Library Page',
    -author=>'lanraragi-san',
    -style=>{'src'=>'/styles/mayoi.css'},
	-script=>{-type=>'JAVASCRIPT',
			  -src=>'/search.js'}
	);

	
#TODO: print motd and search box here

$table->print;#print our finished table

print end_html; #close html