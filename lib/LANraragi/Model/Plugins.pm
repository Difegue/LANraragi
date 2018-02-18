package LANraragi::Model::Plugins;

use strict;
use warnings;
use utf8;
use feature 'say';
use feature 'fc';

#Plugin system ahoy
use Module::Pluggable require =>1, search_path => ['LANraragi::Plugin'];
 
use Redis;
use Encode;

use Mojo::Log;

use LANraragi::Model::Utils;
use LANraragi::Model::Config;

#Returns a Logger object, taking plugin info as argument to obtain the plugin name.
sub get_logger {

	#Customize log file location and minimum log level
	my $log = Mojo::Log->new(path => './plugins.log', level => 'info');
	my $pgname = $_[0];

	#Copy logged messages to STDOUT with the plugin name
	$log->on(message => sub {
	  my ($time, $level, @lines) = @_;
	  print "[$pgname] ";
	  say $lines[0];
	});

	$log->format(sub {
     my ($time, $level, @lines) = @_;
     return "[$pgname] - $level: " . join("\n", @lines) . "\n";
 	});

 	return $log;

}

sub exec_enabled_plugins_on_file {

	my $id = shift;

	say ("[Auto-Tagger] Executing enabled plugins on archive with id $id.");
	my $redis = LANraragi::Model::Config::get_redis;

	foreach my $plugin (LANraragi::Model::Plugins::plugins) {

		#Check Redis to see if plugin is enabled and get the custom argument
		my %pluginfo = $plugin->plugin_info();
        my $name = $pluginfo{namespace};
        my $namerds = "LRR_PLUGIN_".uc($name);

        if ($redis->exists($namerds)) {

        	my %plugincfg = $redis->hgetall($namerds);
        	my ($enabled, $arg) = @plugincfg{qw(enabled arg)};
			($_ = LANraragi::Model::Utils::redis_decode($_)) for ($enabled, $arg);

			eval { #Every plugin execution is eval'd separately 
				if ($enabled) {
					my %plugin_result = &exec_plugin_on_file($plugin, $id, $arg, ""); #No oneshot arguments here

					unless (exists $plugin_result{error}) { #If the plugin exec returned metadata, add it

						my $oldtags = $redis->hget($id, "tags");
						$oldtags = LANraragi::Model::Utils::redis_decode($oldtags);

						my $newtags = $plugin_result{new_tags};
						say ("[Auto-Tagger] Adding $newtags.");

						$redis->hset($id, "tags", $oldtags.",".$newtags);

					}
				}
			};

        }

    }

}

#Execute a specified plugin on a file, described through its Redis ID. 
sub exec_plugin_on_file {

	my ($plugin, $id, $arg, $oneshotarg) = @_;
	my $redis = LANraragi::Model::Config::get_redis;

	#If the plugin has the method "get_tags", catch all the required data and feed it to the plugin
	if ($plugin->can('get_tags')) {

		my %hash = $redis->hgetall($id);
		my ($name,$title,$tags,$file,$thumbhash) = @hash{qw(name title tags file thumbhash)};
		($_ = LANraragi::Model::Utils::redis_decode($_)) for ($name, $title, $tags, $file);

		#Hand it off to the plugin here.
		my %newmetadata = $plugin->get_tags($title, $thumbhash, $file, $arg, $oneshotarg);

		#Error checking 
		if (exists $newmetadata{error}) {
			return %newmetadata #Return the hash as-is -- It already has an "error" key, which will be read by the client. No need for more processing.
		}

		my @tagarray = split(",",$newmetadata{tags});
		my $newtags = "";

		#Process new metadata, stripping out blacklisted tags and tags that we already have in Redis
		my @blacklist = LANraragi::Model::Config::get_tagblacklist;

		foreach my $tagtoadd (@tagarray) {

			unless (index(fc($tags), fc($tagtoadd)) != -1) { #Only proceed if the tag isnt already in redis

				my $good = 1;

				foreach my $black (@blacklist) { 

					if (index($tagtoadd, $black) != -1) {
						$good = 0;
					}
				}

				if ($good == 1) {
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