package LANraragi::Model::Config;

use strict;
use warnings;
use utf8;


#Assign a name to the css file passed. You can add names by adding cases.
#Note: CSS files added to the /themes folder will ALWAYS be pickable by the users no matter what. (except lrr.css because of quality software engineering)
#All this sub does is give .css files prettier names in the dropdown. Files without a name here will simply show as their filename to the users.
#TODO: Move this to Redis and add a page to configure themes
sub cssNames
 {
	switch($_[0]){
		case "g.css" {return "HentaiVerse"}
		case "modern.css" {return "Hachikuji"}
		case "modern_clear.css" {return "Yotsugi"}
		case "modern_red.css" {return "Nadeko"}
		case "ex.css" {return "Sad Panda"}
		else {return $_[0]}
	} 

 }

#This sub defines which numbered variables from the regex selection are taken as metadata. In order:
# [release, artist, title, series, language]
sub select_from_regex { return ($2,$4,$5,$7,$9)};

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

1;