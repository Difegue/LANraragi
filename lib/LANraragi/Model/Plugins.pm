package LANraragi::Model::Plugins;

use strict;
use warnings;
use utf8;

#Plugin system ahoy
use Module::Pluggable require =>1, search_path => ['LANraragi::Plugin'];
 
use Redis;
use Encode;

use Mojo::Log;

use LANraragi::Model::Utils;
use LANraragi::Model::Config;


sub exec_enabled_plugins_on_file {

	my $self = shift;
	my $id = shift;

	my $redis = LANraragi::Model::Config::get_redis;

	foreach my $plugin ($self::plugins) {

		#Check Redis to see if plugin is enabled and get the custom argument
		my %pluginfo = $plugin->plugin_info();
        my $name = $pluginfo{namespace};
        my $namerds = "LRR_PLUGIN_".uc($name);

        if ($redis->exists($namerds)) {

        	my %plugincfg = $redis->hgetall($namerds);
        	my ($enabled, $arg) = @plugincfg{qw(enabled arg)};
			($_ = LANraragi::Model::Utils::redis_decode($_)) for ($enabled, $arg);

			if ($enabled) {
				&exec_plugin_on_file($plugin, $id, $arg, ""); #No oneshot arguments here
			}

        }

    }

}

#Execute a specified plugin on a file, described through its Redis ID. 
sub exec_plugin_on_file {

	my ($plugin, $id, $arg, $oneshotarg) = @_;
	my $redis = LANraragi::Model::Config::get_redis;

	#Customize log file location and minimum log level
	my $log = Mojo::Log->new(path => 'plugins.log', level => 'info');
	my %pluginfo = $plugin->plugin_info();

	#Copy logged messages to STDOUT with the plugin name
	$log->on(message => sub {
	  my ($time, $level, @lines) = @_;
	  print join("\n", @lines);
	});

	$log->format(sub {
     my ($time, $level, @lines) = @_;
     my $pgname = $pluginfo{name};
     return "[$pgname] - $level: " . join("\n", @lines) . "\n";
 	});

	#If the plugin has the method "get_tags", catch all the required data and feed it to the plugin
	if ($plugin->can('get_tags')) {

		my %hash = $redis->hgetall($id);					
		my ($name,$title,$tags,$file,$thumbhash) = @hash{qw(name event artist title series language tags file thumbhash)};
		($_ = LANraragi::Model::Utils::redis_decode($_)) for ($name, $title, $tags, $file);

		#Hand it off to the plugin here.
		my %newmetadata = $plugin->get_tags($title, $tags, $thumbhash, $file, $arg, $oneshotarg, $log);

		my @blacklist = LANraragi::Model::Config::get_tagblacklist;
		#TODO: Insert new metadata in Redis
		#foreach my $tag (@blacklist) 
		#{ $tags =~ s/\Q$tag\E,//ig; } #Remove all occurences of $tag in $tags
		#We got the tags, let's strip out the ones in the blacklist.

		return ""; 
	}
}

1;