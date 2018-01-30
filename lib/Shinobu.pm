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

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../lib"; } #As this is a new process, reloading the LRR libs into INC is needed.

use Mojolicious;
use File::Find;
use File::Path qw(make_path remove_tree);
use Encode;

use LANraragi::Model::Config;
use LANraragi::Model::Utils;

sub initialize_from_new_process {

	my $interval = LANraragi::Model::Config::get_interval;

	say ("Shinobu Background Worker started -- Running every $interval seconds.");

	while (1) {
	
		&workload;
		say ("All Background Tasks done, sleeping $interval seconds.");
		sleep($interval);
	}

}

sub workload {

	say ("Parsing Archive Directory...");
	my $dirname = LANraragi::Model::Config::get_userdir;

	#Get all files in content directory and subdirectories.
	my @filez;
	find({ wanted => sub { 
						if ($_ =~ /^*.+\.(zip|rar|7z|tar|tar.gz|lzma|xz|cbz|cbr)$/ )
							{push @filez, $_ }
					 },
	   no_chdir => 1,
	   follow_fast => 1 }, 
	$dirname);
	
	say ("Checking for new archives...");
	&new_archive_check(@filez);

	say ("Building JSON cache from Redis...");
	&build_json_cache(@filez);

	say ("Checking Temp Folder Size...");
	&autoclean_temp_folder;

}

sub build_json_cache {

	my (@dircontents) = @_;
	my $redis = LANraragi::Model::Config::get_redis;
	my $dirname = LANraragi::Model::Config::get_userdir;

	my $json = "[";
	my ($file, $id);

	foreach $file (@dircontents) {
		#ID of the archive, used for storing data in Redis.
		$id = LANraragi::Model::Utils::sha256_hex($file);

		#Craft JSON if archive is in Redis
		if ($redis->hexists($id,"title")) {
				$json.=LANraragi::Model::Utils::build_archive_JSON($id, $file, $redis, $dirname); 
			}
	}

	$json.="]";

	#Write JSON to cache
	$redis->set("LRR_JSONCACHE",encode_utf8($json));

}

sub new_archive_check {

	my (@dircontents) = @_;
	my $redis = LANraragi::Model::Config::get_redis;

	my ($file, $id);

	foreach $file (@dircontents) {
		#ID of the archive, used for storing data in Redis.
		$id = LANraragi::Model::Utils::sha256_hex($file);

		#Trigger archive addition if title isn't in Redis
		unless ($redis->hexists($id,"title")) {
				say ("Adding new file $file");
				LANraragi::Model::Utils::add_archive_to_redis($id,$file,$redis);

				#TODO: AutoTagging using enabled plugins goes here!
			}
	}
}

sub autoclean_temp_folder {

	my $size = 0;
	find(sub { $size += -s if -f }, "$FindBin::Bin/../public/temp");
	$size = int($size/1048576*100)/100;

	my $maxsize = LANraragi::Model::Config::get_tempmaxsize;
	say ("Current size is $size MBs, Maximum size is $maxsize MBs.");

	if ($size > $maxsize) {
		say ("Cleaning.");
		remove_tree('$FindBin::Bin/../public/temp', {error => \my $err}); 

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

__PACKAGE__->initialize_from_new_process unless caller;

1;