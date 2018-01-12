package LANraragi::Model::Config;

use strict;
use warnings;
use utf8;
use Switch;
use Redis;
use Encode;

use Mojolicious::Plugin::Config;
use Mojo::Home;

# Find the project root directory to load the conf file
my $home = Mojo::Home->new;
$home->detect;

my $config = Mojolicious::Plugin::Config->register(Mojolicious->new, {file => $home.'/lrr.conf'});

#Address and port of your redis instance.
sub get_redisad { return $config->{redis_address} };

#Database that'll be used by LANraragi. Redis databases are numbered, default is 0.
sub get_redisdb { return $config->{redis_database} };

#Default CSS file to load.
sub get_style { return $config->{default_theme} };


#get_redis
#Create a redis object with the parameters defined at the start of this file and return it
sub get_redis
 {

 	#Default redis server location is localhost:6379. 
	#Auto-reconnect on, one attempt every 100ms up to 2 seconds. Die after that.
 	my $redis = Redis->new(server => &get_redisad, 
						reconnect => 100,
						every     => 3000);

 	#Database switch if it's not 0
 	if (&get_redisdb != 0)
 		{ $redis -> select(&get_redisdb); }

 	return $redis;
 }


#getRedisParameter(parameter, default)
#Gets a parameter from the Redis database. If it doesn't exist, we return the default given as a second parameter.
sub getRedisParameter
 {
	my $param = $_[0]; 
	my $default = $_[1];

	my $redis = &get_redis;

	if ($redis->hexists("LRR_CONFIG",$param)) 
		{ 
			my $value = decode_utf8($redis->hget("LRR_CONFIG",$param));

			unless ($value =~ /^\s*$/ ) #failsafe against blank config values
				{ return $value; }
		}
	
	return $default; 
 }

#Functions that return the config variables stored in Redis, or default values if they don't exist. Descriptions for each one of these can be found in the web configuration page.
sub get_htmltitle { return encode('utf-8',&getRedisParameter("htmltitle", "LANraragi")) }; #enforcing unicode to make sure it doesn't fuck up the templates by appearing in some other encoding
sub get_motd { return encode('utf-8',&getRedisParameter("motd", "Welcome to this Library running LANraragi !")) };
sub get_userdir  { return &getRedisParameter("dirname", "./content") };
sub get_pagesize { return &getRedisParameter("pagesize", "100") };
sub get_readorder { return &getRedisParameter("readorder", "0") };
sub enable_pass { return &getRedisParameter("enablepass", "1") };
sub get_password { return &getRedisParameter("password", '{CRYPT}$2a$08$4AcMwwkGXnWtFTOLuw/hduQlRdqWQIBzX3UuKn.M1qTFX5R4CALxy') }; #bcrypt hash for "kamimamita"
sub get_tagblacklist { return &getRedisParameter("blacklist", "already uploaded, translated, english, russian, chinese, portuguese, french") };

#Assign a name to the css file passed. You can add names by adding cases.
#Note: CSS files added to the /themes folder will ALWAYS be pickable by the users no matter what.
#All this sub does is give .css files prettier names in the dropdown. Files without a name here will simply show as their filename to the users.
#TODO - Keep this as default names for provided CSS and add a /theme page to the app to configure user themes
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