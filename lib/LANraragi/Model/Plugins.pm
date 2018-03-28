package LANraragi::Model::Plugins;

use strict;
use warnings;
use utf8;
use feature 'fc';

#Plugin system ahoy
use Module::Pluggable require => 1, search_path => ['LANraragi::Plugin'];

use Redis;
use Encode;

use LANraragi::Model::Utils;
use LANraragi::Model::Config;

sub exec_enabled_plugins_on_file {

    my $id = shift;
    my $logger =
      LANraragi::Model::Utils::get_logger( "Auto-Tagger", "lanraragi" );

    $logger->info("Executing enabled plugins on archive with id $id.");
    my $redis = LANraragi::Model::Config::get_redis;

    my $successes = 0;
    my $failures  = 0;

    foreach my $plugin (LANraragi::Model::Plugins::plugins) {

        #Check Redis to see if plugin is enabled and get the custom argument
        my %pluginfo = $plugin->plugin_info();
        my $name     = $pluginfo{namespace};
        my $namerds  = "LRR_PLUGIN_" . uc($name);

        if ( $redis->exists($namerds) ) {

            my %plugincfg = $redis->hgetall($namerds);
            my ( $enabled, $arg ) = @plugincfg{qw(enabled arg)};
            
            ( $_ = LANraragi::Model::Utils::redis_decode($_) )
              for ( $enabled, $arg );

            if ($enabled) {

                eval { #Every plugin execution is eval'd separately

                    my %plugin_result =
                      &exec_plugin_on_file( $plugin, $id, $arg, "" )
                      ;    #No oneshot arguments on batch execution

                    unless ( exists $plugin_result{error} )
                    {   #If the plugin exec returned metadata, add it

                        my $oldtags = $redis->hget( $id, "tags" );
                        $oldtags =
                          LANraragi::Model::Utils::redis_decode($oldtags);

                        my $newtags = $plugin_result{new_tags};
                        $logger->debug("Adding $newtags to $oldtags.");

                        if ($oldtags ne "") {
                            $newtags = $oldtags . "," . $newtags;
                        }

                        $redis->hset( $id, "tags",
                            encode_utf8( $newtags ) );
                    }
                };

                if ($@) {
                    $failures++;
                    $logger->error("$@");
                }
                else {
                    $successes++;
                }

            }

        }

    }

    return ( $successes, $failures );
}

#Execute a specified plugin on a file, described through its Redis ID.
sub exec_plugin_on_file {

    my ( $plugin, $id, $arg, $oneshotarg ) = @_;
    my $redis = LANraragi::Model::Config::get_redis;

    my $logger =
      LANraragi::Model::Utils::get_logger( "Auto-Tagger", "lanraragi" );

    #If the plugin has the method "get_tags", 
    #catch all the required data and feed it to the plugin
    if ( $plugin->can('get_tags') ) {

        my %hash = $redis->hgetall($id);
        my ( $name, $title, $tags, $file, $thumbhash ) =
          @hash{qw(name title tags file thumbhash)};
        ( $_ = LANraragi::Model::Utils::redis_decode($_) )
          for ( $name, $title, $tags, $file );

        #Hand it off to the plugin here.
        my %newmetadata =
          $plugin->get_tags( $title, $tags, $thumbhash, $file, $arg,
            $oneshotarg );

        #Error checking
        if ( exists $newmetadata{error} ) {
            return %newmetadata; 
            #Return the hash as-is -- It already has an "error" key, which will be read by the client. No need for more processing.
        }

        my @tagarray = split( ",", $newmetadata{tags} );
        my $newtags = "";

        #Process new metadata, 
        #stripping out blacklisted tags and tags that we already have in Redis
        my $blist = LANraragi::Model::Config::get_tagblacklist;
        my @blacklist = split(',', $blist); # array-ize the blacklist string

        foreach my $tagtoadd (@tagarray) {

            LANraragi::Model::Utils::remove_spaces($tagtoadd);
            LANraragi::Model::Utils::remove_newlines($tagtoadd);

            unless ( index( uc($tags), uc($tagtoadd) ) != -1 )
            {   
                #Only proceed if the tag isnt already in redis
                my $good = 1;

                foreach my $black (@blacklist) {
                    LANraragi::Model::Utils::remove_spaces($black);

                    if ( index( uc($tagtoadd), uc($black) ) != -1 ) {
                        $logger->info("Tag $tagtoadd is blacklisted, not adding.");
                        $good = 0;
                    }
                }

                if ( $good ) {
                    #This tag is processed and good to go
                    $newtags .= " $tagtoadd,";
                }
            }
        }

        #Strip last comma and return processed tags in a hash
        chop($newtags);
        return ( new_tags => $newtags );
    }
}

1;
