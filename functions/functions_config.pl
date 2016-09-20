#Functions for reading the configuration settings off the database... 
#And a few extra things I didn't port to the DB because nearly no-one is going to modify those anyway. 
use Switch;
use Redis;
use utf8;
use Encode;

####### FUCKING IMPORTANT : 
#Address and port of your redis instance.
#Normally doesn't need to be changed unless you know what you're doing.
my $redisaddress = "127.0.0.1:6379";
sub get_redisad { return $redisaddress };

#Database that'll be used by LANraragi. Redis databases are numbered, default is 0.
my $redisdatabase = 0;
sub get_redisdb { return $redisdatabase };


######## Sorta-advanced Configuration Shit - Edit if you can handle it ############

#Assign a name to the css file passed. You can add names by adding cases.
#Note: CSS files added to the /styles folder will ALWAYS be pickable by the users no matter what. (except lrr.css because of quality software engineering)
#All this sub does is give .css files prettier names in the dropdown. Files without a name here will simply show as their filename to the users.
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

#Default CSS file to load. Must be in the /styles folder.
my $css = "modern.css";
sub get_style { return $css };

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


#\(°_°))/ 
# Do not go further, mortal. #

#getRedisConnection
#Create a redis object with the parameters defined at the start of this file and return it
sub getRedisConnection
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


#getConfigParameter(parameter, default)
#Gets a parameter from the Redis database. If it doesn't exist, we return the default given as a second parameter.
sub getConfigParameter
 {
	my $param = $_[0]; 
	my $default = $_[1];

	my $redis = Redis->new(server => &get_redisad, 
							reconnect => 100,
							every     => 3000);

	if ($redis->hexists("LRR_CONFIG",$param)) 
		{ 
			my $value = decode_utf8($redis->hget("LRR_CONFIG",$param));

			unless ($value =~ /^\s*$/ ) #failsafe against blank config values
				{ return $value; }
		}
	
	return $default; 
 }


#Functions that return the config variables stored in Redis, or default values if they don't exist. Descriptions for each one of these can be found in the web configuration page.
#Those functions are named with a different standard to specify the fact they're user-controlled in the code.
#Totally not because I made them way back when I started the project. Nah.
sub get_htmltitle { return encode('utf-8',&getConfigParameter("htmltitle", "LANraragi")) }; #enforcing unicode to make sure it doesn't fuck up the templates by appearing in some other encoding
sub get_motd { return encode('utf-8',&getConfigParameter("motd", "Welcome to this Library running LANraragi !")) };
sub get_dirname  { return &getConfigParameter("dirname", "./content") };
sub get_pagesize { return &getConfigParameter("pagesize", "100") };
sub get_readorder { return &getConfigParameter("readorder", "0") };
sub enable_pass { return &getConfigParameter("enablepass", "1") };
sub get_password { return &getConfigParameter("password", '{CRYPT}$2a$08$4AcMwwkGXnWtFTOLuw/hduQlRdqWQIBzX3UuKn.M1qTFX5R4CALxy') }; #bcrypt hash for "kamimamita"
sub enable_resize { return &getConfigParameter("enableresize", "0") };
sub get_threshold { return &getConfigParameter("sizethreshold", "1000") };
sub get_quality { return &getConfigParameter("readerquality", "50") };



