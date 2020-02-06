package LANraragi::Model::Plugins;

use strict;
use warnings;
use utf8;
use feature 'fc';

# Plugin system ahoy - this makes the LANraragi::Model::Plugins::plugins method available
# Don't call this method directly - Rely on LANraragi::Utils::Plugins::get_plugins instead
use Module::Pluggable require => 1, search_path => ['LANraragi::Plugin'];

use Redis;
use Encode;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::UserAgent;
use Data::Dumper;

use LANraragi::Utils::Generic;
use LANraragi::Utils::Archive;
use LANraragi::Utils::Database;
use LANraragi::Utils::Plugins;
use LANraragi::Utils::Logging;

use LANraragi::Model::Config;

# Sub used by Auto-Plugin.
sub exec_enabled_plugins_on_file {

    my $id = shift;
    my $logger =
      LANraragi::Utils::Logging::get_logger( "Auto-Plugin", "lanraragi" );

    $logger->info("Executing enabled plugins on archive with id $id.");

    my $successes = 0;
    my $failures  = 0;
    my $addedtags = 0;

    my @plugins = LANraragi::Utils::Plugins::get_enabled_plugins("metadata");

    foreach my $pluginfo (@plugins) {
        my $name   = $pluginfo->{namespace};
        my @args   = LANraragi::Utils::Plugins::get_plugin_parameters($name);
        my $plugin = LANraragi::Utils::Plugins::get_plugin($name);
        my %plugin_result;

        #Every plugin execution is eval'd separately
        eval {
            %plugin_result = exec_metadata_plugin( $plugin, $id, "", @args );
        };

        if ($@) {
            $failures++;
            $logger->error("$@");
        } elsif ( exists $plugin_result{error}) {
            $failures++;
            $logger->error($plugin_result{error});
        } else {
            $successes++;
        }

        #If the plugin exec returned metadata, add it
        unless ( exists $plugin_result{error} ) {
            LANraragi::Utils::Database::add_tags( $id,
                $plugin_result{new_tags} );

            # Sum up all the added tags for later reporting.
            # This doesn't take into account tags that are added twice
            # (e.g by different plugins), but since this is more meant to show 
            # if the plugins added any data at all it's fine.
            my @added_tags = split(',', $plugin_result{new_tags});
            $addedtags += @added_tags;

            if ( exists $plugin_result{title} ) {
                LANraragi::Utils::Database::set_title( $id,
                    $plugin_result{title} );

                # Increment added_tags if the title changed as well
                $addedtags++;
            }
        }
    }

    return ( $successes, $failures, $addedtags );
}

sub exec_login_plugin {
    my $logplugname = shift;
    my $ua = Mojo::UserAgent->new;
    my $logger =
      LANraragi::Utils::Logging::get_logger( "Plugin System", "lanraragi" );

    if ($logplugname) {
        $logger->info("Calling matching login plugin $loginplugin.");
        my $loginplugin = LANraragi::Utils::Plugins::get_plugin($logplugname);
        my @loginargs   = LANraragi::Utils::Plugins::get_plugin_parameters($logplugname);

        if ($loginplugin->can('do_login')) {
            my $loggedinua = $loginplugin->do_login(@loginargs);

            if (ref($loggedinua) eq "Mojo::UserAgent") {
                return $loggedinua;
            } else {
                $logger->error("Plugin did not return a Mojo::UserAgent object!");
            }
        } else {
            $logger->error("Plugin doesn't implement do_login!");
        }
    } else {
        $logger->info("No login plugin specified, returning empty UserAgent.");
    }

    return $ua;
}

# Execute a specified plugin on a file, described through its Redis ID.
sub exec_metadata_plugin {

    my ( $plugin, $id, $oneshotarg, @args ) = @_;
    my $logger =
      LANraragi::Utils::Logging::get_logger( "Plugin System", "lanraragi" );

    #If the plugin has the method "get_tags",
    #catch all the required data and feed it to the plugin
    if ( $plugin->can('get_tags') ) {

        my $redis = LANraragi::Model::Config::get_redis;
        my %hash  = $redis->hgetall($id);

        my ( $name, $title, $tags, $file, $thumbhash ) =
          @hash{qw(name title tags file thumbhash)};

        ( $_ = LANraragi::Utils::Database::redis_decode($_) )
          for ( $name, $title, $tags);

        # If the thumbnail hash is empty or undefined, we'll generate it here.
        unless ( length $thumbhash ) {
            $logger->info("Thumbnail hash invalid, regenerating.");
            my $dirname = LANraragi::Model::Config::get_userdir;

            #eval the thumbnail extraction as it can error out and die
            eval { LANraragi::Utils::Archive::extract_thumbnail( $dirname, $id ) };
            if ($@) { 
                $logger->warn("Error building thumbnail: $@");
                $thumbhash = "";
            } else {
                $thumbhash = $redis->hget( $id, "thumbhash" );
                $thumbhash = LANraragi::Utils::Database::redis_decode($thumbhash);
            }
        }          
        $redis->quit();

        #Hand it off to the plugin here.
        # If the plugin requires a login, execute that first to get a UserAgent
        my %pluginfo = $plugin->plugin_info();
        my $ua = exec_login_plugin($pluginfo{login_from});
        my %newmetadata = $plugin->get_tags( $title, $tags, $thumbhash, $file, $ua, $oneshotarg, @args );

        #Error checking
        if ( exists $newmetadata{error} ) {

            #Return the hash as-is.
            #It already has an "error" key, which will be read by the client.
            #No need for more processing.
            return %newmetadata;
        }

        my @tagarray = split( ",", $newmetadata{tags} );
        my $newtags = "";

        #Process new metadata,
        #stripping out blacklisted tags and tags that we already have in Redis
        my $blist = LANraragi::Model::Config::get_tagblacklist;
        my @blacklist = split( ',', $blist );   # array-ize the blacklist string

        foreach my $tagtoadd (@tagarray) {

            LANraragi::Utils::Generic::remove_spaces($tagtoadd);
            LANraragi::Utils::Generic::remove_newlines($tagtoadd);

            unless ( index( uc($tags), uc($tagtoadd) ) != -1 ) {

                #Only proceed if the tag isnt already in redis
                my $good = 1;

                foreach my $black (@blacklist) {
                    LANraragi::Utils::Generic::remove_spaces($black);

                    if ( index( uc($tagtoadd), uc($black) ) != -1 ) {
                        $logger->info(
                            "Tag $tagtoadd is blacklisted, not adding.");
                        $good = 0;
                    }
                }

                if ($good) {
                    #This tag is processed and good to go
                    $newtags .= " $tagtoadd,";
                }
            }
        }

        #Strip last comma and return processed tags in a hash
        chop($newtags);
        my %returnhash = ( new_tags => $newtags );

        #Indicate a title change, if the plugin reports one
        if ( exists $newmetadata{title} ) {

            my $newtitle = $newmetadata{title};
            LANraragi::Utils::Generic::remove_spaces($newtitle);
            $returnhash{title} = $newtitle;
        }
        return %returnhash;
    }
    return ( error => "Plugin doesn't implement get_tags" );
}

1;
