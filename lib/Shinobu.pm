package Shinobu;

#LANraragi Background Worker.
#  Uses inotify watches to keep track of filesystem happenings.
#  My main tasks are:
#
#    Tracking all files in the content folder and making sure they're synched with the database
#    Building the JSON cache used to display the Archive Index
#    Automatically cleaning the temporary folder when it reaches a certain size
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
use Encode;

use LANraragi::Utils::Generic;
use LANraragi::Utils::Archive;
use LANraragi::Utils::Database;
use LANraragi::Utils::TempFolder;

use LANraragi::Model::Config;
use LANraragi::Model::Plugins;

# Filemap hash, global to all subs
my %filemap;

# Logger and Database objects
my $logger = LANraragi::Utils::Generic::get_logger( "Shinobu", "lanraragi" );
my $redis = LANraragi::Model::Config::get_redis;

# Almightly inotify interface
my $inotify = new Linux::Inotify2
  or die "unable to create inotify object: $!";

#Subroutine for new and deleted files that takes inotify events
my $inotifysub = sub {
    my $e    = shift;
    my $name = $e->fullname;
    my $mask = $e->mask;
    $logger->debug("Received inotify event $mask on $name");

    if ( $e->IN_MOVED_TO || $e->IN_CREATE ) {
        new_file_callback( $e->fullname );
    }

    if ( $e->IN_DELETE ) {
        deleted_file_callback($name);
    }

};

sub initialize_from_new_process {

    my $userdir = LANraragi::Model::Config::get_userdir;

    $logger->info("Shinobu Background Worker started.");
    $logger->info( "Working dir is " . cwd );

    build_filemap();
    build_json_cache();

    $logger->info("Adding inotify watches to content folder $userdir");

    # add watches to content directory
    $inotify->watch( $userdir, IN_ALL_EVENTS, $inotifysub );

    # add watches to all subdirectories
    find(
        {
            wanted => sub {
                return unless -d $_;    #Directories only
                return
                  if $_ eq "thumb"
                  || $_ eq ".";         #excluded subdirs
                $logger->debug("Adding inotify watches to subdirectory $_");
                $inotify->watch( $File::Find::name, IN_ALL_EVENTS,
                    $inotifysub );
            },
            follow_fast => 1
        },
        $userdir
    );

    # add a watch to the temp folder on created folders
    # Check the current folder size and clean it if necessary
    $inotify->watch( LANraragi::Utils::TempFolder::get_temp,
        IN_CREATE, LANraragi::Utils::TempFolder::clean_temp_partial );

    # Create a .shinobu-nudge file and add a watch to it
    my $nudge = cwd . "/.shinobu-nudge";
    open my $fileHandle, ">", $nudge
      or $logger->warn( "The nudge file couldn't be created! "
          . "You might not be able to manually refresh the JSON cache." );
    print $fileHandle "donut";
    close $fileHandle;

    # This file can then be touched to trigger a JSON cache refresh.
    $inotify->watch( $nudge, IN_ATTRIB, sub { build_json_cache() } );

    # manual event loop
    $logger->info("All done! Now dutifully watching your files. ");
    $inotify->poll while 1;

}

#Build the filemap hash from scratch. This acts as a masterlist of what's in the content directory.
#This computes IDs for all archives and henceforth is rather expensive !
sub build_filemap {

    $logger->info("Building filemap...This might take some time.");

    #Clear hash
    %filemap = ();
    my $dirname = LANraragi::Model::Config::get_userdir;

    #Get all files in content directory and subdirectories.
    find(
        {
            wanted => sub {
                return if -d $_;    #Directories are excluded on the spot
                add_to_filemap($_);
            },
            no_chdir    => 1,
            follow_fast => 1
        },
        $dirname
    );
}

sub add_to_filemap {

    my ($file) = shift;

    if ( $file =~ /^.+\.(?:zip|rar|7z|tar|tar\.gz|lzma|xz|cbz|cbr)$/ ) {

        $logger->debug("Adding $file to Shinobu filemap.");

        #Freshly created files might not be complete yet.
        #We have to wait before doing any form of calculation.
        while (1) {
            last if open( my $handle, '<', $file );
            $logger->debug("Waiting for file to be openable");
            sleep(1);
        }

        #Compute the ID of the archive and add it to the hash
        my $id = "";
        eval { $id = LANraragi::Utils::Database::compute_id($file); };

        if ($@) {
            $logger->error("Couldn't open $file for ID computation: $@");
            $logger->error("Giving up on adding it to the filemap.");
            return;
        }

        #If the hash already exists, throw a warning about duplicates
        if ( exists( $filemap{$id} ) ) {
            $logger->warn( "$file is a duplicate of the existing file "
                  . $filemap{$id}
                  . ". You should delete it." );
        }
        else {
            $filemap{$id} = $file;
        }
    }

}

#Build the JSON cache that is later spat by the API.
#This cross-checks the filemap with the Redis database.
#Files that aren't in the filemap are ignored (potentially deleted archives)
#Files that aren't in the database are added to it.
sub build_json_cache {

    $logger->info("Building JSON cache...This might take some time.");
    $redis->hset( "LRR_JSONCACHE", "refreshing", "1" );

    my $dirname = LANraragi::Model::Config::get_userdir;

    my $json = "[";

    #Iterate on the filemap's keys
    for my $id ( keys %filemap ) {

        my $file = $filemap{$id};

        #Trigger archive addition if title isn't in Redis
        unless ( $redis->exists($id) ) {
            add_new_file( $id, $file );
        }

        $json .= build_archive_JSON( $id, $file );
        $json .= ",";

    }

    #Remove trailing comma if there's one
    if ( length $json > 1 ) {
        chop $json;
    }

    $json .= "]";

    #Write JSON to cache and remove refreshing flag
    $redis->hset( "LRR_JSONCACHE", "archive_list", encode_utf8($json) );
    $redis->hset( "LRR_JSONCACHE", "refreshing",   "0" );

}

#When a new subdirectory is added, we add all its files.
#And if there are subdirectories in there we gotta add a watch
sub new_file_callback {
    my $name = shift;

    unless ( -d $name ) {
        add_to_filemap($name);
    }
    else {    #Oh bother

        $logger->info("Subdirectory $name was added to the content folder!");

        #Add watches to this subdirectory first
        $inotify->watch( $name, IN_ALL_EVENTS, $inotifysub );

        #Just do a big find call to add watches in potential subdirs
        find(
            {
                wanted => sub {
                    if ( -d $_ ) {
                        $logger->debug(
                            "Adding inotify watches to subdirectory $_");
                        $inotify->watch( $File::Find::name,
                            IN_ALL_EVENTS, $inotifysub );
                        return;
                    }

                    #Just call add_to_filemap on files
                    add_to_filemap($File::Find::name);
                },
                follow_fast => 1
            },
            $name
        );
    }

    build_json_cache();
}

#Deleted files are simply dropped from the filemap.
#Deleted subdirectories just trigger a filemap rebuild (most hopeless case)
sub deleted_file_callback {
    my $name = shift;
    $logger->info("$name was deleted from the content folder!");

    unless ( -d $name ) {

        #Lookup the file in the filemap and prune it
        #As it's a lookup by value it looks kinda ugly...
        delete( $filemap{$_} )
          foreach grep { $filemap{$_} eq $name } keys %filemap;
    }
    else {
        build_filemap();
    }

    build_json_cache();
}

sub add_new_file {

    my ( $id, $file ) = @_;

    $logger->info("Adding new file $file with ID $id");

    eval {
        LANraragi::Utils::Database::add_archive_to_redis( $id, $file, $redis );

        #AutoTagging using enabled plugins goes here!
        if (LANraragi::Model::Config::enable_autotag) {
            LANraragi::Model::Plugins::exec_enabled_plugins_on_file($id);
        }
    };

    if ($@) {
        $logger->error("Error while adding file: $@");
    }
}

#build_archive_JSON(id, file)
#Builds a JSON object for an archive already registered in the Redis database and returns it.
sub build_archive_JSON {
    my ( $id, $file ) = @_;

    my $redis   = LANraragi::Model::Config::get_redis;
    my $dirname = LANraragi::Model::Config::get_userdir;

    #Extra check in case we've been given a bogus ID
    return "" unless $redis->exists($id);

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
