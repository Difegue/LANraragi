package LANraragi::Model::Config;

use strict;
use warnings;
use utf8;
use Cwd 'abs_path';

use Mojo::Util qw(xml_escape);
use Minion;
use Mojolicious;
use Mojolicious::Plugin::Config;
use Mojo::Home;
use Mojo::JSON qw(decode_json);

# Be very careful about importing LANraragi stuff; this file is used almost everywhere and it's easy to introduce dependency cycles!
use LANraragi::Utils::Redis      qw(redis_decode);

# Find the project root directory to load the conf file
my $home = Mojo::Home->new;
$home->detect;

my $config = Mojolicious::Plugin::Config->register( Mojolicious->new, { file => $home . '/lrr.conf' } );
if ( $ENV{LRR_REDIS_ADDRESS} ) {
    $config->{redis_address} = $ENV{LRR_REDIS_ADDRESS};
}

# Address and port of your redis instance.
sub get_redisad { return $config->{redis_address} }

# Optional password of your redis instance.
sub get_redispassword { return $config->{redis_password} }

# LANraragi uses 4 Redis Databases. Redis databases are numbered, default is 0.

# Database used for archive data and tag indexes
sub get_archivedb { return $config->{redis_database} }

# Database used by Minion
sub get_miniondb { return $config->{redis_database_minion} }

# Database used to store config keys
sub get_configdb { return $config->{redis_database_config} }

# Database used to store search index and cache
sub get_searchdb { return $config->{redis_database_search} }

# Base URL for deployment under a path prefix
sub get_baseurl { return "$config->{base_url_path}" }

# Create a Minion object connected to the Minion database.
sub get_minion {
    my $miniondb = get_redisad . "/" . get_miniondb;
    my $password = get_redispassword;

    # If the password is non-empty, add the required delimiters
    if ($password) { $password = "x:" . $password . "@"; }

    return Minion->new( Redis => "redis://$password$miniondb" );
}

sub get_redis {
    return get_redis_internal(&get_archivedb);
}

sub get_redis_config {
    return get_redis_internal(&get_configdb);
}

sub get_redis_search {
    return get_redis_internal(&get_searchdb);
}

sub get_redis_internal {

    my $db = $_[0];

    # Default redis server location is localhost:6379.
    # Auto-reconnect on, one attempt every 2ms up to 3 seconds. Die after that.
    # Auth if password is set
    my $redis = Redis->new(
        server    => &get_redisad,
        debug     => $ENV{LRR_DEVSERVER} ? "1" : "0",
        reconnect => 3,
        &get_redispassword ? ( password => &get_redispassword ) : ()
    );

    # Switch to specced database
    $redis->select($db);
    return $redis;
}

#get_redis_conf(parameter, default)
#Gets a parameter from the Redis database. If it doesn't exist, we return the default given as a second parameter.
sub get_redis_conf {
    my $param   = $_[0];
    my $default = $_[1];

    my $redis = get_redis_config();

    if ( $redis->hexists( "LRR_CONFIG", $param ) ) {

        my $value = redis_decode( $redis->hget( "LRR_CONFIG", $param ) );

        # Failsafe against blank config values
        unless ( $value =~ /^\s*$/ ) {
            $redis->quit();
            return $value;
        }
    }
    $redis->quit();
    return $default;
}

# Functions that return the config variables stored in Redis, or default values if they don't exist.
# Descriptions for each one of these can be found in the web configuration page.
sub get_userdir {

    # Content path can be overriden by LRR_DATA_DIRECTORY
    my $dir = &get_redis_conf( "dirname", "./content" );

    if ( $ENV{LRR_DATA_DIRECTORY} ) {
        $dir = $ENV{LRR_DATA_DIRECTORY};
    }

    # Try to create userdir if it doesn't already exist
    unless ( -e $dir ) {
        mkdir $dir;
    }

    # Return full path if it's relative, using the /lanraragi directory as a base
    return abs_path($dir);
}

sub get_thumbdir {

    # Content path can be overriden by LRR_THUMB_DIRECTORY
    my $dir = &get_redis_conf( "thumbdir", "./thumb" );

    if ( $ENV{LRR_THUMB_DIRECTORY} ) {
        $dir = $ENV{LRR_THUMB_DIRECTORY};
    }

    # Try to create userdir if it doesn't already exist
    unless ( -e $dir ) {
        mkdir $dir;
    }

    #Return full path if it's relative, using the /lanraragi directory as a base
    return abs_path($dir);
}

sub enable_devmode {

    if ( $ENV{LRR_FORCE_DEBUG} ) {
        return 1;
    }

    return &get_redis_conf( "devmode", "0" );
}

sub get_password {

    #bcrypt hash for "kamimamita"
    return &get_redis_conf( "password", '{CRYPT}$2a$08$4AcMwwkGXnWtFTOLuw/hduQlRdqWQIBzX3UuKn.M1qTFX5R4CALxy' );
}

sub get_tagrules {
    return &get_redis_conf( "tagrules",
        "-already uploaded;-forbidden content;-incomplete;-ongoing;-complete;-various;-digital;-translated;-russian;-chinese;-portuguese;-french;-spanish;-italian;-vietnamese;-german;-indonesian"
    );
}

sub get_htmltitle        { return xml_escape( &get_redis_conf( "htmltitle", "LANraragi" ) ) }
sub get_motd             { return xml_escape( &get_redis_conf( "motd",      "Welcome to this Library running LANraragi!" ) ) }
sub get_tempmaxsize      { return &get_redis_conf( "tempmaxsize",     "500" ) }
sub get_pagesize         { return &get_redis_conf( "pagesize",        "100" ) }
sub enable_pass          { return &get_redis_conf( "enablepass",      "1" ) }
sub enable_nofun         { return &get_redis_conf( "nofunmode",       "0" ) }
sub enable_cors          { return &get_redis_conf( "enablecors",      "0" ) }
sub get_apikey           { return &get_redis_conf( "apikey",          "" ) }
sub enable_localprogress { return &get_redis_conf( "localprogress",   "0" ) }
sub enable_authprogress  { return &get_redis_conf( "authprogress",    "0" ) }
sub enable_tagrules      { return &get_redis_conf( "tagruleson",      "1" ) }
sub enable_resize        { return &get_redis_conf( "enableresize",    "0" ) }
sub get_threshold        { return &get_redis_conf( "sizethreshold",   "1000" ) }
sub get_readquality      { return &get_redis_conf( "readerquality",   "50" ) }
sub get_style            { return &get_redis_conf( "theme",           "modern.css" ) }
sub enable_dateadded     { return &get_redis_conf( "usedateadded",    "1" ) }
sub use_lastmodified     { return &get_redis_conf( "usedatemodified", "0" ) }
sub enable_cryptofs      { return &get_redis_conf( "enablecryptofs",  "0" ) }
sub get_hqthumbpages     { return &get_redis_conf( "hqthumbpages",    "0" ) }
sub get_jxlthumbpages    { return &get_redis_conf( "jxlthumbpages",   "0" ) }
sub get_replacedupe      { return &get_redis_conf( "replacedupe",     "0" ) }
sub can_replacetitles    { return &get_redis_conf( "replacetitles",   "1" ) }

1;
