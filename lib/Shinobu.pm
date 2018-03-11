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

BEGIN {
    unshift @INC, "$FindBin::Bin/../lib";
}    #As this is a new process, reloading the LRR libs into INC is needed.

use Mojolicious;
use File::Find::utf8;
use File::Basename;
use File::stat;
use File::Path qw(make_path remove_tree);
use Encode;

use LANraragi::Model::Config;
use LANraragi::Model::Utils;

sub initialize_from_new_process {

    my $interval = LANraragi::Model::Config::get_interval;
    my $logger = LANraragi::Model::Utils::get_logger( "Shinobu", "lanraragi" );

    $logger->info(
        "Shinobu Background Worker started -- Running every $interval seconds."
    );
    $logger->info( "Working dir is " . cwd );

    while (1) {

        eval {
            &workload;
        };
        if ($@) {
            $logger->error($@);
        }

        sleep($interval);
    }

}

sub workload {

    my $logger = LANraragi::Model::Utils::get_logger( "Shinobu", "lanraragi" );

    #$logger->debug("Parsing Archive Directory...");

    my @archives = &get_archive_list;
    my $redis    = LANraragi::Model::Config::get_redis;

    my $cachecount = 0;
    my $newcount   = scalar @archives;

    #$logger->debug("Done - Found $newcount files.");

    my $force = 0;
    if ( $redis->hexists( "LRR_JSONCACHE", "force_refresh" ) ) {

        #Force flag, usually set when metadata has been modified by the user.
        $force = $redis->hget( "LRR_JSONCACHE", "force_refresh" );
    }

    if ( $redis->hexists( "LRR_JSONCACHE", "archive_count" ) ) {
        $cachecount = $redis->hget( "LRR_JSONCACHE", "archive_count" );
    }

    #$logger->debug("Checking for new archives...");

    if ( $newcount != $cachecount ) {
        #Enable force flag to indicate other parts of the system that we're rebuilding the DB cache
        $redis->hset( "LRR_JSONCACHE", "force_refresh", 1 );
        &new_archive_check(@archives);
    }

    #say ("Building JSON cache from Redis...");
    if ( $newcount != $cachecount || $force ) {
        $logger->info( "Archive count ($newcount) has changed since last cached value ($cachecount)" . 
            " OR rebuild has been forced (flag value = $force), rebuilding..."
        );
        &build_json_cache();
        $logger->info("Done!");
    }

    #say ("Checking Temp Folder Size...");
    if ( -e "$FindBin::Bin/../public/temp" ) { &autoclean_temp_folder; }

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
    my $logger = LANraragi::Model::Utils::get_logger( "Shinobu", "lanraragi" );

    my $id;

    #As the workload loops, we need to inform the user about the state of the archive importation -- 
    #which means generating a JSON every now and then.

    #While this isn't important for small uploads, when processing 1000+ files, 
    #the user is left in front of an empty index page for quite a while.

    #Even more so with autotagging enabled.
    #Limiting new archive addition to 20 files per loop allows for the index page to progressively fill up.
    my $processed_archives             = 0;
    my $maximum_archives_per_iteration = 20;

    foreach my $file (@dircontents) {

        #ID of the archive, used for storing data in Redis.
        $id = LANraragi::Model::Utils::compute_id($file);

        if ( $processed_archives >= $maximum_archives_per_iteration ) {
            $logger->debug( "Processed $maximum_archives_per_iteration Archives, " . 
                "bailing out to build JSON."
            );
            return;
        }

        #Duplicate file detector
        if ($redis->hexists($id,"title")) {
        	my $cachefile = $redis->hget($id,"file");
        	my $filet = LANraragi::Model::Utils::redis_decode($file);
        	$cachefile = LANraragi::Model::Utils::redis_decode($cachefile);
        	if ($cachefile ne $filet) {
        		$logger->warn("This ID exists in the Redis Database but doesn't have the same file! You might be having duplicate files!");
        		$logger->warn("Our file: $filet");
        		$logger->warn("Cached file: $cachefile");
        	}
        } else {
            #Trigger archive addition if title isn't in Redis
            $logger->info("Adding new file $file with ID $id");
            LANraragi::Model::Utils::add_archive_to_redis( $id, $file, $redis );

            #AutoTagging using enabled plugins goes here!
            if (LANraragi::Model::Config::enable_autotag) {
                LANraragi::Model::Plugins::exec_enabled_plugins_on_file($id);
            }
            $processed_archives++;
        }
    }
}

sub autoclean_temp_folder {

    my $logger = LANraragi::Model::Utils::get_logger( "Shinobu", "lanraragi" );

    my $size = 0;
    find( sub { $size += -s if -f }, "$FindBin::Bin/../public/temp" );
    $size = int( $size / 1048576 * 100 ) / 100;

    my $maxsize = LANraragi::Model::Config::get_tempmaxsize;

    if ( $size > $maxsize ) {
        $logger->info( "Current temporary folder size is $size MBs, " . 
            "Maximum size is $maxsize MBs. Cleaning."
        );

        #Remove all folders in /public/temp except the most recent one
        #For this, we use Perl's ctime, which uses inode last modified time on Unix and Win32 creation time on Windows.
        my $dir_name = "$FindBin::Bin/../public/temp";

        #Wipe thumb temp folder first
        if ( -e $dir_name . "/thumb" ) { unlink( $dir_name . "/thumb" ); }

        opendir( my $dir_fh, $dir_name );

        my @folder_list;
        while ( my $file = readdir $dir_fh ) {

            next unless -d $dir_name . '/' . $file;
            next if $file eq '.' or $file eq '..';

            push @folder_list, "$dir_name/$file";
        }
        closedir $dir_fh;

        @folder_list = sort {
            my $a_stat = stat($a);
            my $b_stat = stat($b);
            $a_stat->ctime <=> $b_stat->ctime;
        } @folder_list;

        #Remove all folders in folderlist except the last one
        my $survivor = pop @folder_list;
        $logger->debug("Deleting all folders in /temp except $survivor");

        remove_tree( @folder_list, { error => \my $err } );

        if (@$err) {
            for my $diag (@$err) {
                my ( $file, $message ) = %$diag;
                if ( $file eq '' ) {
                    $logger->error("General error: $message\n");
                }
                else {
                    $logger->error("Problem unlinking $file: $message\n");
                }
            }
        }

        $logger->info("Done!");
    }
}

sub build_json_cache {

    my $redis   = LANraragi::Model::Config::get_redis;
    my $dirname = LANraragi::Model::Config::get_userdir;
    my $logger  = LANraragi::Model::Utils::get_logger( "Shinobu", "lanraragi" );

    #Enable force flag to indicate other parts of the system that we're rebuilding the DB cache
    $redis->hset( "LRR_JSONCACHE", "force_refresh", 1 );

    my $json = "[";

    #SHA-1 IDs are 40 characters long.
    my @keys = $redis->keys('????????????????????????????????????????');    
    my $archivecount = scalar @keys;
    my $treated      = 0;

    #Iterate on hashes to get their tags
    foreach my $id (@keys) {
        my $path = $redis->hget( $id, "file" );
        $path = LANraragi::Model::Utils::redis_decode($path);

        if ( -e $path ) {
            $json .= &build_archive_JSON( $id, $path );
        }
        else {
            #Delete leftover IDs
            $logger->warn("Deleting ID $id - File $path cannot be found.");
            $redis->del($id);    
        }

        $treated++;
        $logger->debug("Treated $treated archives out of $archivecount .");

    }

    $json .= "]";

    #Write JSON to cache
    $redis->hset( "LRR_JSONCACHE", "archive_list", encode_utf8($json) );

    #Write the current archive count too
    $redis->hset( "LRR_JSONCACHE", "archive_count", $treated );

    #Clean force flag
    $redis->hset( "LRR_JSONCACHE", "force_refresh", 0 );

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
    ( $_ = LANraragi::Model::Utils::redis_decode($_) )
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
        $title = "<i class='fa fa-exclamation-circle'></i> Untitled archive, please edit metadata.";
    }

    #Clean up trailing commas in tags
    chomp $tags;
    if (substr $tags, -1 eq ",") {
        chop $tags;
    }

    my $finaljson = qq(
		{
			"arcid": "$id",
			"title": "$title",
			"tags": "$tags",
			"isnew": "$isnew"
		},
	);

    return $finaljson;
}

__PACKAGE__->initialize_from_new_process unless caller;

1;
