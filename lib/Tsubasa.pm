package Tsubasa;

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

use local::lib;

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
use File::Basename;
use File::Spec;
use Encode;
use UUID::Tiny ':std';
use Unicode::Normalize qw(NFC);

use LANraragi::Utils::Archive    qw(extract_thumbnail);
use LANraragi::Utils::Database   qw(invalidate_cache compute_id change_archive_id get_arcsize add_timestamp_tag add_archive_to_redis add_arcsize add_pagecount add_chapter_to_redis set_pagecount);
use LANraragi::Utils::Logging    qw(get_logger);
use LANraragi::Utils::Generic    qw(is_image is_chapter exec_with_lock_pure);
use LANraragi::Utils::Redis      qw(redis_encode);
use LANraragi::Utils::Path       qw(create_path open_path find_path get_archive_path);

use LANraragi::Model::Config;
use LANraragi::Model::Plugins;
use LANraragi::Model::Metrics;
use LANraragi::Utils::Plugins;    # Needed here since Tsubasa doesn't inherit from the main LRR package
use LANraragi::Model::Search;     # idem

use constant IS_UNIX => ( $Config{osname} ne 'MSWin32' );

# Logger and Database objects
my $logger = get_logger( "Tsubasa", "tsubasa" );

#Subroutine for new and deleted files that takes inotify events
my $inotifysub = sub {
    my $e    = shift;
    my $name = create_path( $e->path );
    my $type = $e->type;

    $logger->debug("Received inotify event $type on $name");

    if ( $type eq "create" || $type eq "modify" ) {
        new_file_callback($name);
    }

    if ( $type eq "delete" ) {
        deleted_file_callback($name);
    }

};

sub initialize_from_new_process {

    if ( !IS_UNIX ) {
        # Enable autoflush
        $| = 1;
    }

    my $userdir = LANraragi::Model::Config->get_userdir;
    my $metrics_enabled = LANraragi::Model::Config->enable_metrics;

    $logger->info("Tsubasa File Watcher started.");
    $logger->info("Content folder is $userdir.");

    my $local_folder_exists = check_local_folder($userdir, "local");

    if ( $local_folder_exists ) {
        update_filemap();
    } else {
        $logger->info("Folder doesn't exist");
    }

    #update_filemap();
    #$logger->info("Initial scan complete! Adding watcher to content folder to monitor for further file edits.");
}

sub check_local_folder ( $path, $folder_name ) {
    # Verify the base path is a directory
    return 0 unless defined $path && -d $path;

    opendir(my $dh, $path)
        or return 0;

    while (my $entry = readdir($dh)) {
        next if $entry eq '.' || $entry eq '..';

        if ($entry eq $folder_name && -d "$path/$entry") {
            closedir($dh);
            return 1;
        }
    }

    closedir($dh);
    return 0;
}

sub count_files ($path) {
    return 0 unless defined $path && -d $path;

    opendir(my $dh, $path)
        or return 0;

    my $count = 0;

    while (my $entry = readdir($dh)) {
        next if $entry eq '.' || $entry eq '..';

        my $full_path = "$path/$entry";
        $count++ if -f $full_path;
    }

    closedir($dh);

    return $count;
}

sub get_manga_identifiers ( $path ) {
    my $dirname = LANraragi::Model::Config->get_userdir . "/local";
    $path =~ s/$dirname//;

    my @parts = File::Spec->splitdir(
        File::Spec->canonpath($path)
    );
    my $depth = scalar @parts;

    if ( $depth == 3 ) {
        return (1, $parts[1], $parts[2]);
    } else {
        return (0, "", "");
    }
}

sub get_random_UUID ( $prefix=undef ) {
    my $v4_rand_UUID_2  = create_uuid(UUID_RANDOM);
    my $str_appendix = uuid_to_string($v4_rand_UUID_2);

    if ( defined($prefix) ) {
        return $prefix . "_" . $str_appendix;
    } else {
        return $str_appendix;
    }
}

sub print_files(@files) {
    my $remove = LANraragi::Model::Config->get_userdir . "/local/";
    foreach my $file (@files) {
        $file =~ s/$remove//; 
        $logger->info("$file");
    }
}

sub is_second_level( $file, $remove ) {
    $file =~ s/$remove//;

    my @parts = File::Spec->splitdir(
        File::Spec->canonpath($file)
    );
    my $depth = scalar @parts;

    return $depth == 3
}

# Update the filemap. This acts as a masterlist of what's in the content directory.
# This computes IDs for all new archives and henceforth can get rather expensive!
sub update_filemap {

    $logger->info("Scanning content folder for changes...");
    my $redis = LANraragi::Model::Config->get_redis_config;

    # Clear hash
    my $dirname = LANraragi::Model::Config->get_userdir . "/local";
    my @files;

    # Get all files in content directory and subdirectories.
    find_path(
        sub {
            $_ = create_path($_);
            return unless is_chapter($_);
            return unless is_second_level($_, $dirname);
            push @files, $_;    #Push files to array
        },
        $dirname
    );

    print_files(@files);

    # Cross-check with filemap to get recorded files that aren't on the FS, and new files that aren't recorded.
    my @filemapfiles = $redis->exists("LRR_LOCALFILEMAP") ? $redis->hkeys("LRR_LOCALFILEMAP") : ();

    my %filemaphash = map { $_ => 1 } @filemapfiles;
    my %fshash      = map { $_ => 1 } @files;

    my @newfiles     = grep { !$filemaphash{$_} } @files;
    my @deletedfiles = grep { !$fshash{$_} } @filemapfiles;

    $logger->info( "Found " . scalar @newfiles . " new files." );
    $logger->info( scalar @deletedfiles . " files were found on the filemap but not on the filesystem." );

    # Delete old files from filemap
    foreach my $deletedfile (@deletedfiles) {
        $logger->debug("Removing $deletedfile from filemap.");
        $redis->hdel( "LRR_LOCALFILEMAP", $deletedfile ) || $logger->warn("Couldn't delete previous filemap data.");
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

sub add_to_filemap ( $redis_cfg, $chapter, $manga_id ) {

    my $redis_arc = LANraragi::Model::Config->get_redis;
    if ( is_chapter($chapter) ) {

        $logger->debug("Adding $chapter to Tsubasa filemap.");

        #Compute the ID of the archive and add it to the hash
        # TODO: Check if folder has an LRR.json with the ID, otherwise create a new ID.
        my $chapter_id = get_random_UUID("CHAPTER");
        # Add the id to the folder as a LRR.json

        # Acquire exclusive metadata and file write access for archive by ID with 1m timeout
        my ($acquired, $is_new) = exec_with_lock_pure(
            [ "archive-write:$chapter_id" ],
            sub { update_filemap_entry( $logger, $chapter_id, $chapter, $redis_cfg, $redis_arc ) },
            undef, 60
        );

        if ( !$acquired ) {
            $logger->warn("Write lock already acquired for archive $chapter with ID $chapter_id, skipping.");
        }

        # New file handling runs outside the lock so auto-plugin can acquire its own lock.
        if ( $acquired && $is_new ) {
            add_new_file( $chapter_id, $chapter );
            invalidate_cache();
        }

        # Add Chapter to the manga Tank

    } else {
        $logger->debug("$chapter not recognized as archive, skipping.");
    }
    $redis_arc->quit;
}

sub update_filemap_entry ( $logger, $id, $file, $redis_cfg, $redis_arc ) {

    $logger->debug("Computed ID is $id.");
    unless ( -e $file ) {
        # A race condition check, if the file was deleted after ID computation but before a lock was acquired.
        $logger->warn("Folder does not exist; giving up on adding it to the filemap: $file");
        return;
    }

    # If the id already exists on the server, throw a warning about duplicates
    if ( $redis_cfg->hexists( "LRR_LOCALFILEMAP", $file ) ) {

        my $filemap_id = $redis_cfg->hget( "LRR_LOCALFILEMAP", $file );

        $logger->debug("$file was logged but is already in the filemap!");

        if ( $filemap_id ne $id ) {
            $logger->debug("$file has a different ID than the one in the filemap! ($filemap_id)");
            $logger->info("$file has been modified, updating its ID from $filemap_id to $id.");

            # Note: The logic here is technically different than the one in Upload.pm.
            # Upload.pm checks replace_duplicates and wipes the previous ID/metadata. 
            # Tsubasa just updates the ID in the database and leaves the old metadata in place.
            # There's no way to assess user intent just from a filewatcher though, so we act non-destructively.
            # -------------------------------------------------------------------------------
            # change_chapter_id( $filemap_id, $id );
            # -------------------------------------------------------------------------------

            # Don't forget to update the filemap, later operations will behave incorrectly otherwise
            $redis_cfg->hset( "LRR_LOCALFILEMAP", $file, $id );
        } else {
            $logger->debug(
                "$file has the same ID as the one in the filemap. Duplicate inotify events? Cleaning cache just to make sure");
            invalidate_cache();
        }

        return;

    } else {
        $redis_cfg->hset( "LRR_LOCALFILEMAP", $file, $id );    # raw FS path so no encoding/decoding whatsoever
    }

    # Filename sanity check
    if ( $redis_arc->exists($id) ) {

        my $filecheck = get_archive_path( $redis_arc, $id );

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

        # Set pagecount in case it's not already there
        unless ( $redis_arc->hget( $id, "pagecount" ) ) {
            $logger->debug("Pagecount not calculated for $id, doing it now!");
            my $num_files = count_files($file);
            set_pagecount( $redis_arc, $id, $num_files );
        }

    } else {

        # Signal that this is a new file; caller will handle add_new_file outside the lock.
        return 1;
    }

    return 0;
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
        $redis->hdel( "LRR_LOCALFILEMAP", $name );

        eval { invalidate_cache(); };

        $redis->quit();
    }
}

sub add_new_files (@files) {
    my $redis = LANraragi::Model::Config->get_redis_config;
    my $current_manga = "";

    foreach my $file (@files) {
        $logger->debug("Processing $file");

        my ( $found, $name, $chapter ) = get_manga_identifiers( $file );
        my $manga_id;

        if ($name ne $current_manga) {
            # TODO: Check if folder has an LRR.json with the ID, otherwise create a new ID.

            $manga_id = get_random_UUID("MANGA");

            # Validate if the ID exists in the DB, otherwise create a new "Tank"

            # Add the id to the folder as an LRR.json
        }

        # Individual files are also eval'd so we can keep scanning
        eval { add_to_filemap( $redis, $file, $manga_id ); };

        if ($@) {
            $logger->error("Error scanning $file: $@");
        }
    }

    $redis->quit();
}


sub add_new_file ( $id, $file ) {

    my $redis        = LANraragi::Model::Config->get_redis;
    my $redis_search = LANraragi::Model::Config->get_redis_search;
    $logger->info("Adding new file $file with ID $id");

    eval {
        add_chapter_to_redis( $id, $file, $redis, $redis_search );
        add_timestamp_tag( $redis, $id );
        my $num_files = count_files($file);
        set_pagecount( $redis, $id, $num_files );

        # Generate thumbnail
        # Same idea as archives thumbnail, but we can skip uncompress step.
        #my $thumbdir = LANraragi::Model::Config->get_thumbdir;
        #extract_thumbnail( $thumbdir, $id, 1, 1, 1 );

        # No plugins compatible
    };

    if ($@) {
        $logger->error("Error while adding file: $@");
    }
    $redis->quit;
    $redis_search->quit;
}

__PACKAGE__->initialize_from_new_process unless caller;

1;
