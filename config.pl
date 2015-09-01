#Default config variables. Change as you see fit.
use Switch;

#Title of the html page.
my $htmltitle = "LANraragi"; 

#Text that appears on top of the page. Empty for no text. (look at me ma i'm versioning)
my $motd = "Welcome to this Library running LANraragi v.0.1.87!"; 

#Whether or not you load thumbnails when hovering over a title. Requires an imagemagick install. (Just imagemagick, none of these perlmagick thingamabobs)
my $thumbnails = 1; 

#Password-protect edit and upload modes. You'd do well to enable this if you're making the library available online.
my $enablepass = 1;

#Password for editing and uploading titles. You should probably change this, even though it's not "admin".
my $password = "kamimamita"; 
#Directory of the zip archives. Make sure your web server can serve what's inside this directory. (Write rights would help too.)
my $dirname = "./content"; 

#Resize images in reader when the original is heavier than this size. (in KBs.) (0 for no resizing)
my $sizethreshold = 900;

#Quality of the converted images if resized.
my $readerquality = 90; 

#Number of archives shown on a page. 0 for no pages.
my $pagesize = 100;

#Adress and port of redis instance.
my $redisaddress = "127.0.0.1:6379";

#Syntax of an archive's filename. Used in editing.
my $syntax = "(%RELEASE) [%ARTIST] %TITLE (%SERIES) [%LANGUAGE]";

#CSS file to load. Must be in the styles folder.
my $css = "modern.css";

#Assign a name to the css file passed. You can add names by adding cases.
sub cssNames{

	switch($_[0]){
		case "g.css" {return "Old School"}
		case "modern.css" {return "Hachikuji"}
		case "modern_clear.css" {return "Yotsugi"}
		case "modern_red.css" {return "Nadeko"}
		case "ex.css" {return "Sad Panda"}
		else {return $_[0]}
	} 

}

#Functions that return the local config variables. Avoids fuckups if you happen to create a $motd variable in your own code, for example.
sub get_htmltitle { return $htmltitle };
sub get_motd { return $motd };
sub enable_thumbs { return $thumbnails };
sub enable_pass { return $enablepass };
sub get_password { return $password };
sub get_dirname  { return $dirname };
sub get_quality { return $readerquality };
sub get_syntax { return $syntax };
sub get_threshold { return $sizethreshold };
sub get_pagesize { return $pagesize };
sub get_thumbpref { return $generateonindex };
sub get_redisad { return $redisaddress };
sub get_style { return $css };

#This sub defines which numbered variables from the regex selection are taken for display. In order:
# [release, artist, title, series, language]
sub regexsel { return ($2,$4,$5,$7,$9)};

#Regular Expression matching the above syntax. Used in parsing. Stuff that's between unescaped ()s is put in a numbered variable: $1,$2,etc
	#This regex autoparses the given string according to the exhentai standard convention: (Release) [Artist] TITLE (Series) [Language]
	#Parsing is only done the first time the file is found. The parsed info is then stored into Redis. 
	#Change this regex if you wish to use a different parsing for mass-addition of archives.
	
	#()? indicates the field is optional.
	#(\(([^([]+)\))? returns the content of (Release). Optional.
	#(\[([^]]+)\])? returns the content of [Artist]. Optional.
	#([^([]+) returns the title. Mandatory.
	#(\(([^([)]+)\))? returns the content of (Series). Optional.
	#(\[([^]]+)\])? returns the content of [Language]. Optional.
	#\s* indicates zero or more whitespaces.
my $regex = qr/(\(([^([]+)\))?\s*(\[([^]]+)\])?\s*([^([]+)\s*(\(([^([)]+)\))?\s*(\[([^]]+)\])?/;
sub get_regex { return $regex};


