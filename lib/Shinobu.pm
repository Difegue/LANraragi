package Shinobu;

# LANraragi File Watcher.
#  Uses inotify watches to keep track of filesystem happenings.
#  My main tasks are:
#
#    Tracking all files in the content folder and making sure they're sync'ed with the database
#

use strict;
use warnings;
use utf8;
use feature qw(say signatures);
no warnings 'experimental::signatures';

use FindBin;
use MCE::Loop;
use Sys::CpuAffinity;
use Storable   qw(lock_store);
use Mojo::JSON qw(to_json);
use Config;

#As this is a new process, reloading the LRR libs into INC is needed.
BEGIN { unshift @INC, "$FindBin::Bin/../lib"; }

use Mojolicious;    # Needed by Model::Config to read the Redis address/port.
use File::ChangeNotify;
use File::Find;
use File::Basename;
use Encode;

use LANraragi::Utils::Archive    qw(extract_thumbnail);
use LANraragi::Utils::Database   qw(invalidate_cache compute_id change_archive_id get_arcsize add_timestamp_tag add_archive_to_redis add_arcsize add_pagecount);
use LANraragi::Utils::Logging    qw(get_logger);
use LANraragi::Utils::Generic    qw(is_archive);
use LANraragi::Utils::Redis      qw(redis_encode);

use LANraragi::Model::Config;
use LANraragi::Model::Plugins;
use LANraragi::Utils::Plugins;    # Needed here since Shinobu doesn't inherit from the main LRR package
use LANraragi::Model::Search;     # idem

use constant IS_UNIX => ( $Config{osname} ne 'MSWin32' );

BEGIN {
    if ( !IS_UNIX ) {
        require Win32;
        require Win32::FileSystemHelper;
    }
}

# Logger and Database objects
my $logger = get_logger( "Shinobu", "shinobu" );

#Subroutine for new and deleted files that takes inotify events
my $inotifysub = sub {
    my $e    = shift;
    my $name = $e->path;
    my $type = $e->type;

    # Filewatcher on Windows returns backward slashes, convert them to forward slash to match everything else
    if ( !IS_UNIX ) {
        $name =~ s/\\/\//g;

        # If this is a super long file convert it to short name
        if ( length($name) >= 260 ) {
            $name = Win32::GetShortPathName($name);
        }
    }

    $logger->debug("Received inotify event $type on $name");

    if ( $type eq "create" || $type eq "modify" ) {
        new_file_callback($name);
    }

    if ( $type eq "delete" ) {
        deleted_file_callback($name);
    }

};

sub initialize_from_new_process {

    my $userdir = LANraragi::Model::Config->get_userdir;

    $logger->info("Shinobu File Watcher started.");
    $logger->info("Content folder is $userdir.");

    update_filemap();
    $logger->info("Initial scan complete! Adding watcher to content folder to monitor for further file edits.");

    # Add watcher to content directory
    my $contentwatcher = File::ChangeNotify->instantiate_watcher(
        directories     => [$userdir],
        filter          => qr/\.(?:zip|rar|7z|tar|tar\.gz|lzma|xz|cbz|cbr|cb7|cbt|pdf|epub|tar\.zst|zst)$/i,
        follow_symlinks => 1,
        exclude         => [ 'thumb', '.' ],                                                                   #excluded subdirs
    );

    my $class = ref($contentwatcher);
    $logger->debug("Watcher class is $class");

    # manual event loop
    $logger->info("All done! Now dutifully watching your files. ");

    my $running = 1;

    while ($running) {
        local $SIG{INT} = sub { $running = 0 };

        # Check events on files
        for my $event ( $contentwatcher->new_events ) {
            $inotifysub->($event);
        }

        sleep 1;
    }

    if ( !IS_UNIX ) {
        # Cleanly shutdown filewatcher
        $contentwatcher->dispose;
    }
}

# Update the filemap. This acts as a masterlist of what's in the content directory.
# This computes IDs for all new archives and henceforth can get rather expensive!
sub update_filemap {

    $logger->info("Scanning content folder for changes...");
    my $redis = LANraragi::Model::Config->get_redis_config;

    # Clear hash
    my $dirname = LANraragi::Model::Config->get_userdir;
    my @files;

    # Get all files in content directory and subdirectories.
    find(
        {   wanted => sub {
                return if -d $_;    #Directories are excluded on the spot
                return unless is_archive($_);
                if ( !IS_UNIX ) {
                    # If this is a super long file convert it to short name
                    if ( length($_) >= 260 ) {
                        $_ = Win32::GetShortPathName($_);
                    }
                }
                push @files, $_;    #Push files to array
            },
            no_chdir    => 1,
            follow_fast => 1
        },
        $dirname
    );

    # Cross-check with filemap to get recorded files that aren't on the FS, and new files that aren't recorded.
    my @filemapfiles = $redis->exists("LRR_FILEMAP") ? $redis->hkeys("LRR_FILEMAP") : ();

    my %filemaphash = map { $_ => 1 } @filemapfiles;
    my %fshash      = map { $_ => 1 } @files;

    my @newfiles     = grep { !$filemaphash{$_} } @files;
    my @deletedfiles = grep { !$fshash{$_} } @filemapfiles;

    $logger->info( "Found " . scalar @newfiles . " new files." );
    $logger->info( scalar @deletedfiles . " files were found on the filemap but not on the filesystem." );

    # Delete old files from filemap
    foreach my $deletedfile (@deletedfiles) {
        $logger->debug("Removing $deletedfile from filemap.");
        $redis->hdel( "LRR_FILEMAP", $deletedfile ) || $logger->warn("Couldn't delete previous filemap data.");
    }

    $redis->quit();

    eval {
        if ( IS_UNIX ) {
            # Now that we have all new files, process them...with multithreading!
            mce_loop {
                add_new_files(@{ $_ });
            } \@newfiles;
            MCE::Loop->finish;
        } else {
            # libarchive does not support threading on Windows
            add_new_files(@newfiles);
        }
    };

    if ($@) {
        $logger->error("Error while scanning content folder: $@");
    }
}

sub add_to_filemap ( $redis_cfg, $file ) {

    my $redis_arc = LANraragi::Model::Config->get_redis;
    if ( is_archive($file) ) {

        $logger->debug("Adding $file to Shinobu filemap.");

        #Freshly created files might not be complete yet.
        #We have to wait before doing any form of calculation.
        while (1) {
            last unless -e $file;    # Sanity check to avoid sticking in this loop if the file disappears
            last if open( my $handle, '<', $file );
            $logger->debug("Waiting for file to be openable");
            sleep(1);
        }

        # Wait for file to be more than 512 KBs or bailout after 5s and assume that file is smaller
        my $cnt = 0;
        while (1) {
            last if ( ( ( -s $file ) >= 512000 ) || $cnt >= 5 );
            $logger->debug("Waiting for file to be fully written");
            sleep(1);
            $cnt++;
        }

        #Compute the ID of the archive and add it to the hash
        my $id = "";
        eval { $id = compute_id($file); };

        if ($@) {
            $logger->error("Couldn't open $file for ID computation: $@");
            $logger->error("Giving up on adding it to the filemap.");
            return;
        }

        $logger->debug("Computed ID is $id.");

        # If the id already exists on the server, throw a warning about duplicates
        if ( $redis_cfg->hexists( "LRR_FILEMAP", $file ) ) {

            my $filemap_id = $redis_cfg->hget( "LRR_FILEMAP", $file );

            $logger->debug("$file was logged but is already in the filemap!");

            if ( $filemap_id ne $id ) {
                $logger->debug("$file has a different ID than the one in the filemap! ($filemap_id)");
                $logger->info("$file has been modified, updating its ID from $filemap_id to $id.");

                change_archive_id( $filemap_id, $id );

                # Don't forget to update the filemap, later operations will behave incorrectly otherwise
                $redis_cfg->hset( "LRR_FILEMAP", $file, $id );
            } else {
                $logger->debug(
                    "$file has the same ID as the one in the filemap. Duplicate inotify events? Cleaning cache just to make sure");
                invalidate_cache();
            }

            return;

        } else {
            $redis_cfg->hset( "LRR_FILEMAP", $file, $id );    # raw FS path so no encoding/decoding whatsoever
        }

        # Filename sanity check
        if ( $redis_arc->exists($id) ) {

            my $filecheck = $redis_arc->hget( $id, "file" );

            #Update the real file path and title if they differ from the saved one
            #This is meant to always track the current filename for the OS.
            unless ( $file eq $filecheck ) {
                $logger->debug("File name discrepancy detected between DB and filesystem!");
                $logger->debug("Filesystem: $file");
                $logger->debug("Database: $filecheck");
                my ( $name, $path, $suffix ) = fileparse( $file, qr/\.[^.]*/ );
                $redis_arc->hset( $id, "file", $file );
                $redis_arc->hset( $id, "name", redis_encode($name) );
                $redis_arc->wait_all_responses;
                invalidate_cache();
            }

            unless ( get_arcsize( $redis_arc, $id ) ) {
                $logger->debug("arcsize is not set for $id, storing now!");
                add_arcsize( $redis_arc, $id );
            }

            # Set pagecount in case it's not already there
            unless ( $redis_arc->hget( $id, "pagecount" ) ) {
                $logger->debug("Pagecount not calculated for $id, doing it now!");
                add_pagecount( $redis_arc, $id );
            }

        } else {

            # Add to Redis if not present beforehand
            add_new_file( $id, $file );
            invalidate_cache();
        }
    } else {
        $logger->debug("$file not recognized as archive, skipping.");
    }
    $redis_arc->quit;
}

# Only handle new files. As per the ChangeNotify doc, it
# "handles the addition of new subdirectories by adding them to the watch list"
sub new_file_callback ($name) {

    $logger->debug("New file detected: $name");
    unless ( -d $name ) {

        my $redis = LANraragi::Model::Config->get_redis_config;
        eval { add_to_filemap( $redis, $name ); };
        $redis->quit();

        if ($@) {
            $logger->error("Error while handling new file: $@");
        }
    }
}

# Deleted files are simply dropped from the filemap.
# Deleted subdirectories trigger deleted events for every file deleted.
sub deleted_file_callback ($name) {

    $logger->info("$name was deleted from the content folder!");
    unless ( -d $name ) {

        my $redis = LANraragi::Model::Config->get_redis_config;

        # Prune file from filemap
        $redis->hdel( "LRR_FILEMAP", $name );

        eval { invalidate_cache(); };

        $redis->quit();
    }
}

sub add_new_files (@files) {
    my $redis = LANraragi::Model::Config->get_redis_config;

    foreach my $file (@files) {
        $logger->debug("Processing $file");

        # Individual files are also eval'd so we can keep scanning
        eval { add_to_filemap( $redis, $file ); };

        if ($@) {
            $logger->error("Error scanning $file: $@");
        }
    }

    $redis->quit();
}


sub add_new_file ( $id, $file_fs ) {

    my $redis        = LANraragi::Model::Config->get_redis;
    my $redis_search = LANraragi::Model::Config->get_redis_search;
    $logger->info("Adding new file $file_fs with ID $id");

    eval {
        my $file = $file_fs;
        if ( !IS_UNIX ) {
            $file = Win32::FileSystemHelper::get_full_path($file);
        }
        add_archive_to_redis( $id, $file, $file_fs, $redis, $redis_search );
        add_timestamp_tag( $redis, $id );
        add_pagecount( $redis, $id );

        # Generate thumbnail
        my $thumbdir = LANraragi::Model::Config->get_thumbdir;
        extract_thumbnail( $thumbdir, $id, 1, 1, 1 );

        # AutoTagging using enabled plugins goes here!
        LANraragi::Model::Plugins::exec_enabled_plugins_on_file($id);
    };

    if ($@) {
        $logger->error("Error while adding file: $@");
    }
    $redis->quit;
    $redis_search->quit;
}

__PACKAGE__->initialize_from_new_process unless caller;

1;
