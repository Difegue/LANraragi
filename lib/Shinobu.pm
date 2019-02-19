package Shinobu;

#LANraragi Background Worker.
#  While the Webapp is active, executes a workload every X seconds.
#  This workload currently is:
#
#    Automatic detection/indexing of new archives without visiting the main page
#    Automatic tagging of new archives using enabled plugins
#    Automatic cleaning of the temporary folder when it reaches a certain size
#

use strict;
use warnings;
use utf8;
use feature qw(say);
use Cwd;

use FindBin;
use Mojo::JSON qw(to_json);

BEGIN {
    unshift @INC, "$FindBin::Bin/../lib";
}    #As this is a new process, reloading the LRR libs into INC is needed.

use Mojolicious;
use Linux::Inotify2;
use File::Find::utf8;
use File::Basename;
use File::Path qw(make_path remove_tree);
use Encode;

use LANraragi::Utils::Generic;
use LANraragi::Utils::Archive;
use LANraragi::Utils::Database;
use LANraragi::Utils::TempFolder;

use LANraragi::Model::Config;
use LANraragi::Model::Plugins;

sub initialize_from_new_process {

    my $logger =
      LANraragi::Utils::Generic::get_logger( "Shinobu", "lanraragi" );

    my $userdir = LANraragi::Model::Config::get_userdir;

    $logger->info("Shinobu Background Worker started.");
    $logger->info( "Working dir is " . cwd );
    $logger->info("Adding inotify watches to content folder $userdir");

    # create a new object
    my $inotify = new Linux::Inotify2
      or die "unable to create new inotify object: $!";

    # add watches to content directory and all subdirectories
    $inotify->watch(
        $userdir,
        IN_CREATE | IN_MOVED_TO,
        sub {
            my $e    = shift;
            my $name = $e->fullname;
            print "$name was accessed\n"              if $e->IN_ACCESS;
            print "$name is no longer mounted\n"      if $e->IN_UNMOUNT;
            print "$name is gone\n"                   if $e->IN_IGNORED;
            print "events for $name have been lost\n" if $e->IN_Q_OVERFLOW;

            # cancel this watcher: remove no further events
            $e->w->cancel;
        }
    );

    # except the "thumb" subdirectory

    # add a watch to the temp folder on created folders
    # Check the current folder size and clean it if necessary
    $inotify->watch( LANraragi::Utils::TempFolder::get_temp,
        IN_CREATE, LANraragi::Utils::TempFolder::clean_temp_partial );

    # manual event loop
    $inotify->poll while 1;

}

sub workload {

    my $logger =
      LANraragi::Utils::Generic::get_logger( "Shinobu", "lanraragi" );
    my $redis = LANraragi::Model::Config::get_redis;

    my $force       = $_[0];
    my $redis_force = 0;

    if ( $redis->hexists( "LRR_JSONCACHE", "force_refresh" ) ) {

        #Force flag, usually set when metadata has been modified by the user.
        $redis_force = $redis->hget( "LRR_JSONCACHE", "force_refresh" );
    }

#Content folder is parsed if we reached interval or if the force flag is set to 1 in Redis
    if ( $force || $redis_force ) {

        $redis->hset( "LRR_JSONCACHE", "force_refresh", 1 );

        my @archives   = &get_archive_list;
        my $cachecount = 0;
        my $newcount   = scalar @archives;

        if ( $redis->hexists( "LRR_JSONCACHE", "archive_count" ) ) {
            $cachecount = $redis->hget( "LRR_JSONCACHE", "archive_count" );
        }

        if ( $newcount != $cachecount ) {
            &new_archive_check(@archives);
        }

        if ( $redis_force || $newcount != $cachecount ) {

            $logger->info( "Archive count ($newcount) has changed "
                  . "since last cached value ($cachecount) "
                  . "OR rebuild has been forced (flag value = $redis_force), rebuilding..."
            );

            &build_json_cache();
            $logger->info("Done!");
        }

        #Clean force flag
        $redis->hset( "LRR_JSONCACHE", "force_refresh", 0 );

    }

    if ( -e LANraragi::Utils::TempFolder::get_temp ) { &autoclean_temp_folder; }

}

sub get_archive_list {

    my $dirname = LANraragi::Model::Config::get_userdir;

    #Get all files in content directory and subdirectories.
    my @filez;
    find(
        {
            wanted => sub {

                return if -d $_;    #Directories are excluded on the spot
                if ( $_ =~ /^.+\.(?:zip|rar|7z|tar|tar\.gz|lzma|xz|cbz|cbr)$/ )
                {
                    push @filez, $_;
                }
            },
            no_chdir    => 1,
            follow_fast => 1
        },
        $dirname
    );
    return @filez;

}

sub new_archive_check {

    my (@dircontents) = @_;
    my $redis = LANraragi::Model::Config::get_redis;
    my $logger =
      LANraragi::Utils::Generic::get_logger( "Shinobu", "lanraragi" );

    my $processed_archives             = 0;
    my $maximum_archives_per_iteration = 20;

    foreach my $file (@dircontents) {

        #ID of the archive, used for storing data in Redis.
        my $id = LANraragi::Utils::Database::compute_id($file);

#As the workload loops, we need to inform the user about the state of the archive importation --
#which means generating a JSON every now and then.
        if ( $processed_archives >= $maximum_archives_per_iteration ) {
            $logger->debug(
                    "Processed $maximum_archives_per_iteration Archives, "
                  . "building JSON." );

            $processed_archives = 0;
            &build_json_cache();
        }

        #Duplicate file detector
        if ( $redis->hexists( $id, "title" ) ) {
            my $cachefile = $redis->hget( $id, "file" );
            my $filet = LANraragi::Utils::Database::redis_decode($file);
            $cachefile = LANraragi::Utils::Database::redis_decode($cachefile);
            if ( $cachefile ne $filet ) {
                $logger->warn( "This ID exists in the Redis Database but "
                      . "doesn't have the same file! You might be having duplicate files!"
                );
                $logger->warn("Our file: $filet");
                $logger->warn("Cached file: $cachefile");

  #Increment the processed count to account for the dupe file for the time being
                $processed_archives++;
            }
        }
        else {
            #Trigger archive addition if title isn't in Redis
            $logger->info("Adding new file $file with ID $id");
            LANraragi::Utils::Database::add_archive_to_redis( $id, $file,
                $redis );

            #AutoTagging using enabled plugins goes here!
            if (LANraragi::Model::Config::enable_autotag) {
                LANraragi::Model::Plugins::exec_enabled_plugins_on_file($id);
            }
            $processed_archives++;
        }
    }
}

sub build_json_cache {

    my $redis   = LANraragi::Model::Config::get_redis;
    my $dirname = LANraragi::Model::Config::get_userdir;
    my $logger =
      LANraragi::Utils::Generic::get_logger( "Shinobu", "lanraragi" );

    my $json = "[";

    #SHA-1 IDs are 40 characters long.
    my @keys         = $redis->keys('????????????????????????????????????????');
    my $archivecount = scalar @keys;
    my $treated      = 0;

    #Iterate on hashes to get their tags
    foreach my $id (@keys) {
        my $path = $redis->hget( $id, "file" );
        $path = LANraragi::Utils::Database::redis_decode($path);

        if ( -e $path ) {
            $json .= &build_archive_JSON( $id, $path );
            $json .= ",";
        }
        else {
            #Delete leftover IDs
            $logger->warn("Deleting ID $id - File $path cannot be found.");
            $redis->del($id);
        }

        $treated++;
        $logger->debug("Treated $treated archives out of $archivecount .");

    }

    #Remove trailing comma if there's one
    if ( length $json > 1 ) {
        chop $json;
    }

    $json .= "]";

    #Write JSON to cache
    $redis->hset( "LRR_JSONCACHE", "archive_list", encode_utf8($json) );

    #Write the current archive count too
    $redis->hset( "LRR_JSONCACHE", "archive_count", $treated );

}

#build_archive_JSON(id, file, redis, userdir)
#Builds a JSON object for an archive already registered in the Redis database and returns it.
sub build_archive_JSON {
    my ( $id, $file ) = @_;

    my $redis   = LANraragi::Model::Config::get_redis;
    my $dirname = LANraragi::Model::Config::get_userdir;

    my %hash = $redis->hgetall($id);
    my ( $path, $suffix );

    #It's not a new archive, but it might have never been clicked on yet,
    #so we'll grab the value for $isnew stored in redis.
    my ( $name, $title, $tags, $filecheck, $isnew ) =
      @hash{qw(name title tags file isnew)};

    #Parameters have been obtained, let's decode them.
    ( $_ = LANraragi::Utils::Database::redis_decode($_) )
      for ( $name, $title, $tags, $filecheck );

    #Update the real file path and title if they differ from the saved one
    #...just in case the file got manually renamed or some weird shit
    unless ( $file eq $filecheck ) {
        ( $name, $path, $suffix ) = fileparse( $file, qr/\.[^.]*/ );
        $redis->hset( $id, "file", encode_utf8($file) );
        $redis->hset( $id, "name", encode_utf8($name) );
        $redis->wait_all_responses;
    }

    #Workaround if title was incorrectly parsed as blank
    if ( $title =~ /^\s*$/ ) {
        $title =
            "<i class='fa fa-exclamation-circle'></i> "
          . "Untitled archive, please edit metadata.";
    }

    my $arcdata = {
        arcid => $id,
        title => $title,
        tags  => $tags,
        isnew => $isnew
    };

    #to_json automatically escapes JSON-critical characters.
    return to_json($arcdata);

}

__PACKAGE__->initialize_from_new_process unless caller;

1;
