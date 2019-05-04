package LANraragi::Model::Plugins;

use strict;
use warnings;
use utf8;
use feature 'fc';

#Plugin system ahoy - this makes the LANraragi::Model::Plugins::plugins method available
use Module::Pluggable require => 1, search_path => ['LANraragi::Plugin'];

use Redis;
use Encode;
use Mojo::JSON qw(decode_json encode_json);

use LANraragi::Utils::Generic;
use LANraragi::Utils::Archive;
use LANraragi::Utils::Database;

use LANraragi::Model::Config;

sub exec_enabled_plugins_on_file {

    my $id = shift;
    my $logger =
      LANraragi::Utils::Generic::get_logger( "Auto-Tagger", "lanraragi" );

    $logger->info("Executing enabled plugins on archive with id $id.");
    my $redis = LANraragi::Model::Config::get_redis;

    my $successes = 0;
    my $failures  = 0;

    foreach my $plugin (LANraragi::Model::Plugins::plugins) {

        #Check Redis to see if plugin is enabled and get the custom arguments
        my %pluginfo = $plugin->plugin_info();
        my $name     = $pluginfo{namespace};
        my $namerds  = "LRR_PLUGIN_" . uc($name);

        if ( $redis->exists($namerds) ) {

            my @args     = ();
            my $enabled  = $redis->hget( $namerds, "enabled" );
            my $argsjson = $redis->hget( $namerds, "customargs" );

            ( $_ = LANraragi::Utils::Database::redis_decode($_) )
              for ( $enabled, $argsjson );

            #Mojo::JSON works with array references by default,
            #so we need to dereference here as well
            if ($argsjson) {
                @args = @{ decode_json($argsjson) };
            }

            if ($enabled) {

                my %plugin_result;

                #Every plugin execution is eval'd separately
                eval {
                    %plugin_result =
                      &exec_plugin_on_file( $plugin, $id, "", @args );
                };

                if ($@) {
                    $failures++;
                    $logger->error("$@");
                }
                else {
                    $successes++;
                }

                #If the plugin exec returned metadata, add it
                unless ( exists $plugin_result{error} ) {
                    LANraragi::Utils::Database::add_tags( $id,
                        $plugin_result{new_tags} );

                    if ( exists $plugin_result{title} ) {
                        LANraragi::Utils::Database::set_title( $id,
                            $plugin_result{title} );
                    }

                }

            }

        }

    }

    return ( $successes, $failures );
}

#Execute a specified plugin on a file, described through its Redis ID.
sub exec_plugin_on_file {

    my ( $plugin, $id, $oneshotarg, @args ) = @_;
    my $redis = LANraragi::Model::Config::get_redis;

    my $logger =
      LANraragi::Utils::Generic::get_logger( "Auto-Tagger", "lanraragi" );

    #If the plugin has the method "get_tags",
    #catch all the required data and feed it to the plugin
    if ( $plugin->can('get_tags') ) {

        my %hash = $redis->hgetall($id);
        my ( $name, $title, $tags, $file, $thumbhash ) =
          @hash{qw(name title tags file thumbhash)};

        ( $_ = LANraragi::Utils::Database::redis_decode($_) )
          for ( $name, $title, $tags, $file );

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

        #Hand it off to the plugin here.
        my %newmetadata = $plugin->get_tags( $title, $tags, $thumbhash, $file, $oneshotarg,
                @args );

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
}

1;
