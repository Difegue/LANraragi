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
BEGIN { unshift @INC, "$FindBin::Bin/../lib"; } #As this is a new process, reloading the LRR libs into INC is needed.

use Mojolicious;
use File::Find;
use File::Basename;
use File::stat;
use File::Path qw(make_path remove_tree);
use Encode;

use LANraragi::Model::Config;
use LANraragi::Model::Utils;

sub initialize_from_new_process {

	my $interval = LANraragi::Model::Config::get_interval;

	say ("Shinobu Background Worker started -- Running every $interval seconds.");
	say ("Working dir is ".cwd);

	while (1) {
	
		&workload;
		#say ("All Background Tasks done, sleeping $interval seconds.");
		sleep($interval);
	}

}

sub workload {

	#say ("Parsing Archive Directory...");
	my @archives = LANraragi::Model::Utils::get_archive_list;
	my $redis = LANraragi::Model::Config::get_redis;

	my $cachecount = 0;
	my $force = 0;
	if ($redis->exists("LRR_JSONCACHE")) {
		$cachecount = $redis->hget("LRR_JSONCACHE","archive_count");
		$force = $redis->hget("LRR_JSONCACHE","force_refresh"); #Force flag, usually set when metadata has been modified by the user.
	}

	#say ("Checking for new archives...");
	if ( scalar @archives != $cachecount ) {
		&new_archive_check(@archives);
	}

	#say ("Building JSON cache from Redis...");
	if ( scalar @archives != $cachecount || $force ) {
		say ("Archive count has changed since last cached value ($cachecount) OR rebuild has been forced (flag value = $force), rebuilding...");
		&build_json_cache(@archives);
		say ("Done!");
	}

	#say ("Checking Temp Folder Size...");
	if (-e "$FindBin::Bin/../public/temp")
		{ &autoclean_temp_folder; }


}

sub new_archive_check {

	my (@dircontents) = @_;
	my $redis = LANraragi::Model::Config::get_redis;

	my ($file, $id);

	#As the workload loops, we need to inform the user about the state of the archive importation -- which means generating a JSON every now and then.
	#While this isn't important for small uploads, when processing 1000+ files, the user is left in front of an empty index page for quite a while.
	#Even more so with autotagging enabled.
	#Limiting new archive addition to 20 files per loop allows for the index page to progressively fill up.
	my $processed_archives = 0;
	my $maximum_archives_per_iteration = 20;

	foreach $file (@dircontents) {
		#ID of the archive, used for storing data in Redis.
		$id = LANraragi::Model::Utils::shasum($file,256);

		if ($processed_archives >= $maximum_archives_per_iteration) {
			return;
		}

		#Trigger archive addition if title isn't in Redis
		unless ($redis->hexists($id,"title")) {
				say ("Adding new file $file");
				say ("ID is $id");
				LANraragi::Model::Utils::add_archive_to_redis($id,$file,$redis);

				#AutoTagging using enabled plugins goes here!
				if (LANraragi::Model::Config::get_autotag) {
					LANraragi::Model::Plugins::exec_enabled_plugins_on_file($id);
				}
				$processed_archives++;
			}
	}
}

sub autoclean_temp_folder {

	my $size = 0;
	find(sub { $size += -s if -f }, "$FindBin::Bin/../public/temp");
	$size = int($size/1048576*100)/100;

	my $maxsize = LANraragi::Model::Config::get_tempmaxsize;

	if ($size > $maxsize) {
		say ("Current temporary folder size is $size MBs, Maximum size is $maxsize MBs. Cleaning.");

		#Remove all folders in /public/temp except the most recent one
		#For this, we use Perl's ctime, which uses inode last modified time on Unix and Win32 creation time on Windows.
		my $dir_name = "$FindBin::Bin/../public/temp";

		#Wipe thumb temp folder first
		if (-e $dir_name."/thumb") { unlink ($dir_name."/thumb"); }
		
		opendir(my $dir_fh, $dir_name);

		my @folder_list;
		while ( my $file = readdir $dir_fh) {

			next unless -d $dir_name . '/' . $file;
		    next if $file eq '.' or $file eq '..';

		    push @folder_list, "$dir_name/$file";
		}
		closedir $dir_fh;

		@folder_list = sort {
					        my $a_stat = stat($a);
					        my $b_stat = stat($b);
					        $a_stat->ctime <=> $b_stat->ctime;
				    	}  @folder_list ;

		#Remove all folders in folderlist except the last one
		my $survivor = pop @folder_list;
		say "Deleting all folders in /temp except $survivor";

		remove_tree(@folder_list, {error => \my $err}); 

		if (@$err) {
	  		for my $diag (@$err) {
		      my ($file, $message) = %$diag;
		      if ($file eq '') {
		          say "General error: $message\n";
		      }
		      else {
		          say "Problem unlinking $file: $message\n";
		      }
  			}
  		}
	}
}

sub build_json_cache {

	my (@dircontents) = @_;
	my $redis = LANraragi::Model::Config::get_redis;
	my $dirname = LANraragi::Model::Config::get_userdir;

	#Enable force flag to indicate other parts of the system that we're rebuilding the DB cache
	$redis->hset("LRR_JSONCACHE","force_refresh", 1);

	my $json = "[";
	my ($file, $id);

	foreach $file (@dircontents) {
		#ID of the archive, used for storing data in Redis.
		$id = LANraragi::Model::Utils::shasum($file,256);

		#Craft JSON if archive is in Redis
		if ($redis->hexists($id,"title")) {
				$json.=&build_archive_JSON($id, $file, $redis, $dirname); 
			}

		#TODO: Override to shutdown cache building?
	}

	$json.="]";

	#Write JSON to cache
	$redis->hset("LRR_JSONCACHE","archive_list",encode_utf8($json));

	#Write the current archive count too
	$redis->hset("LRR_JSONCACHE","archive_count", scalar @dircontents);

	#Clean force flag
	$redis->hset("LRR_JSONCACHE","force_refresh", 0);

}

#build_archive_JSON(id, file, redis, userdir)
#Builds a JSON object for an archive already registered in the Redis database and returns it.
sub build_archive_JSON {
	my ($id, $file, $redis, $dirname) = @_;

	my %hash = $redis->hgetall($id);
	my ($path, $suffix);

	#It's not a new archive, but it might have never been clicked on yet, so we'll grab the value for $isnew stored in redis.
	my ($name,$title,$tags,$filecheck,$isnew) = @hash{qw(name title tags file isnew)};

	#Parameters have been obtained, let's decode them.
	( eval { $_ = LANraragi::Model::Utils::redis_decode($_) } ) for ($name, $title, $tags, $filecheck);

	#Update the real file path and title if they differ from the saved one just in case the file got manually renamed or some weird shit
	unless ($file eq $filecheck)
	{
		($name,$path,$suffix) = fileparse($file, qr/\.[^.]*/);
		$redis->hset($id, "file", encode_utf8($file));
		$redis->hset($id, "name", encode_utf8($name));
		$redis->wait_all_responses;
	}	
			
	#Tag display. Simple list separated by hyphens which expands into a caption div with nicely separated tags on hover.
	my $printedtags = "";
	
	if ($title =~ /^\s*$/) #Workaround if title was incorrectly parsed as blank
		{ $title = "<i class='fa fa-exclamation-circle'></i> Untitled archive, please edit metadata.";}

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