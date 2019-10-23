package LANraragi::Model::Config;

use strict;
use warnings;
use utf8;
use feature "switch";
no warnings 'experimental';
use Cwd 'abs_path';

use Redis;
use Encode;

use Mojolicious::Plugin::Config;
use Mojo::Home;

# Find the project root directory to load the conf file
my $home = Mojo::Home->new;
$home->detect;

my $config = Mojolicious::Plugin::Config->register( Mojolicious->new,
    { file => $home . '/lrr.conf' } );

#Address and port of your redis instance.
sub get_redisad { return $config->{redis_address} }

#Database that'll be used by LANraragi. Redis databases are numbered, default is 0.
sub get_redisdb { return $config->{redis_database} }

#Default CSS file to load.
sub get_style { return $config->{default_theme} }

#get_redis
#Create a redis object with the parameters defined at the start of this file and return it
sub get_redis {

    my $dir = "./";
    if ($ENV{BREWMODE}) {
      $dir = $ENV{HOME} . "/Library/Application Support/LANraragi/";
    }

    #Default redis server location is localhost:6379.
    #Auto-reconnect on, one attempt every 2ms up to 3 seconds. Die after that.
    my $redis = Redis->new(
        server    => &get_redisad,
        reconnect => 3,
        dir       => $dir
    );

    #Database switch if it's not 0
    if ( &get_redisdb != 0 ) { $redis->select(&get_redisdb); }

    return $redis;
}

#get_redis_conf(parameter, default)
#Gets a parameter from the Redis database. If it doesn't exist, we return the default given as a second parameter.
sub get_redis_conf {
    my $param   = $_[0];
    my $default = $_[1];

    my $redis = &get_redis;

    if ( $redis->hexists( "LRR_CONFIG", $param ) ) {
        my $value = LANraragi::Utils::Database::redis_decode(
            $redis->hget( "LRR_CONFIG", $param ) );

        #failsafe against blank config values
        unless ( $value =~ /^\s*$/ ) {
            return $value;
        }
    }
    $redis->quit();
    return $default;
}

#Functions that return the config variables stored in Redis, or default values if they don't exist. Descriptions for each one of these can be found in the web configuration page.
sub get_htmltitle {
    return encode( 'utf-8', &get_redis_conf( "htmltitle", "LANraragi" ) );
}; #enforcing unicode to make sure it doesn't fuck up the templates by appearing in some other encoding

sub get_motd {
    return encode(
        'utf-8',
        &get_redis_conf(
            "motd", "Welcome to this Library running LANraragi!"
        )
    );
}

sub get_userdir {
    my $default_dir = "./content";
    if ($ENV{BREWMODE}) {
        $default_dir = $ENV{HOME} . "/Library/Application Support/LANraragi/content";
    }

    my $dir = &get_redis_conf( "dirname", $default_dir );

    #Try to create userdir if it doesn't already exist
    unless ( -e $dir ) {
        mkdir $dir;
    }

    #Return full path if it's relative, using the /lanraragi directory as a base
    return abs_path($dir);
}

sub get_password {
    return &get_redis_conf( "password",
        '{CRYPT}$2a$08$4AcMwwkGXnWtFTOLuw/hduQlRdqWQIBzX3UuKn.M1qTFX5R4CALxy' );
};    #bcrypt hash for "kamimamita"

sub get_tagblacklist {
    return &get_redis_conf( "blacklist",
"already uploaded, forbidden content, incomplete, ongoing, complete, various, digital, translated, russian, chinese, portuguese, french, spanish, italian, vietnamese, german, indonesian"
    );
}

sub get_tempmaxsize { return &get_redis_conf( "tempmaxsize", "500" ) }
sub get_pagesize    { return &get_redis_conf( "pagesize",    "100" ) }
sub enable_pass     { return &get_redis_conf( "enablepass",  "1" ) }
sub enable_nofun    { return &get_redis_conf( "nofunmode",   "0" ) }
sub enable_autotag  { return &get_redis_conf( "autotag",     "1" ) }
sub enable_devmode  { return &get_redis_conf( "devmode",     "0" ) }
sub get_apikey      { return &get_redis_conf( "apikey",      "" ) }
sub get_tagregex    { return &get_redis_conf( "tagregex",    "1" ) }

#Use the number of the favtag you want to get as a parameter to this sub.
sub get_favtag { return &get_redis_conf( "fav" . $_[1], "" ) }

#Assign a name to the css file passed. You can add names by adding cases.
#Note: CSS files added to the /themes folder will ALWAYS be pickable by the users no matter what.
#All this sub does is give .css files prettier names in the dropdown. Files without a name here will simply show as their filename to the users.
sub css_default_names {
    given ( $_[0] ) {
        when ("g.css")            { return "HentaiVerse" }
        when ("modern.css")       { return "Hachikuji" }
        when ("modern_clear.css") { return "Yotsugi" }
        when ("modern_red.css")   { return "Nadeko" }
        when ("ex.css")           { return "Sad Panda" }
        default                   { return $_[0] }
    }

}

#Regular Expression matching the E-Hentai standard: (Release) [Artist] TITLE (Series) [Language]
#Used in parsing.
#Stuff that's between unescaped ()s is put in a numbered variable: $1,$2,etc
#Parsing is only done the first time the file is found. The parsed info is then stored into Redis.
#Change this regex if you wish to use a different parsing for mass-addition of archives.

#()? indicates the field is optional.
#(\(([^([]+)\))? returns the content of (Release). Optional.
#(\[([^]]+)\])? returns the content of [Artist]. Optional.
#([^([]+) returns the title. Mandatory.
#(\(([^([)]+)\))? returns the content of (Series). Optional.
#(\[([^]]+)\])? returns the content of [Language]. Optional.
#\s* indicates zero or more whitespaces.
my $regex =
qr/(\(([^([]+)\))?\s*(\[([^]]+)\])?\s*([^([]+)\s*(\(([^([)]+)\))?\s*(\[([^]]+)\])?/;
sub get_regex { return $regex }

1;
