package LANraragi::Model::Plugins;

use strict;
use warnings;
use utf8;

#Plugin system ahoy
use Module::Pluggable require =>1, search_path => ['LANraragi::Plugin'];
 
use Redis;
use Encode;

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
				&exec_plugin_on_file($plugin, $id, $arg);
			}

        }

    }

}

#Execute a specified plugin on a file, described through its Redis ID. The custom argument isn't mandatory.
sub exec_plugin_on_file {

	my ($plugin, $id, $arg) = @_;
	my $redis = LANraragi::Model::Config::get_redis;

	#If the plugin has the method "get_tags", catch all the required data and feed it to the plugin
	if ($plugin->can('get_tags')) {

		my %hash = $redis->hgetall($id);					
		my ($name,$title,$tags,$file,$thumbhash) = @hash{qw(name event artist title series language tags file thumbhash)};
		($_ = LANraragi::Model::Utils::redis_decode($_)) for ($name, $title, $tags, $file);

		my %newmetadata = $plugin->get_tags($title, $tags, $thumbhash, $file, $arg);

		my @blacklist = LANraragi::Model::Config::get_tagblacklist;
		#TODO: Insert new metadata in Redis
		#foreach my $tag (@blacklist) 
		#{ $tags =~ s/\Q$tag\E,//ig; } 
	}


}

1;