package LANraragi::Model::Config;

use strict;
use warnings;
use utf8;
use Cwd 'abs_path';
use Redis;
use Encode;
use Minion;
use Mojolicious::Plugin::Config;
use Mojo::Home;
use Mojo::JSON qw(decode_json);

# Find the project root directory to load the conf file
my $home = Mojo::Home->new;
$home->detect;

my $config = Mojolicious::Plugin::Config->register( Mojolicious->new, { file => $home . '/lrr.conf' } );

# Address and port of your redis instance.
sub get_redisad { return $config->{redis_address} }

# Database that'll be used by LANraragi. Redis databases are numbered, default is 0.
sub get_redisdb { return $config->{redis_database} }

# Database that'll be used by Minion. Redis databases are numbered, default is 1.
sub get_miniondb { return $config->{redis_database_minion} }

# Create a Minion object connected to the Minion database.
sub get_minion {
    my $miniondb = get_redisad . "/" . get_miniondb;
    return Minion->new( Redis => "redis://$miniondb" );
}

#get_redis
#Create a redis object with the parameters defined at the start of this file and return it
sub get_redis {

    #Default redis server location is localhost:6379.
    #Auto-reconnect on, one attempt every 2ms up to 3 seconds. Die after that.
    my $redis = Redis->new(
        server    => &get_redisad,
        reconnect => 3
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

    my $redis = get_redis();

    if ( $redis->hexists( "LRR_CONFIG", $param ) ) {

        # Call Utils::Database directly as importing it with use; would cause circular dependencies...
        my $value = LANraragi::Utils::Database::redis_decode( $redis->hget( "LRR_CONFIG", $param ) );

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
    my $dir = &get_redis_conf( "thumbdir", get_userdir() . "/thumb" );

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

sub get_htmltitle        { return &get_redis_conf( "htmltitle",     "LANraragi" ) }
sub get_motd             { return &get_redis_conf( "motd",          "Welcome to this Library running LANraragi!" ) }
sub get_tempmaxsize      { return &get_redis_conf( "tempmaxsize",   "500" ) }
sub get_pagesize         { return &get_redis_conf( "pagesize",      "100" ) }
sub enable_pass          { return &get_redis_conf( "enablepass",    "1" ) }
sub enable_nofun         { return &get_redis_conf( "nofunmode",     "0" ) }
sub enable_cors          { return &get_redis_conf( "enablecors",    "0" ) }
sub get_apikey           { return &get_redis_conf( "apikey",        "" ) }
sub enable_localprogress { return &get_redis_conf( "localprogress", "0" ) }
sub enable_tagrules      { return &get_redis_conf( "tagruleson",    "1" ) }
sub enable_resize        { return &get_redis_conf( "enableresize",  "0" ) }
sub get_threshold        { return &get_redis_conf( "sizethreshold", "1000" ) }
sub get_readquality      { return &get_redis_conf( "readerquality", "50" ) }
sub get_style            { return &get_redis_conf( "theme", "modern.css" ) }

1;
