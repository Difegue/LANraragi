use strict;
use Redis;
use Encode;
use utf8;

require 'functions/functions_config.pl';

#deleteArchive($id)
#Deletes the archive with the given id from redis, and the matching archive file.
sub deleteArchive
	{

	my $id = $_[0];

	my $redis = Redis->new(server => &get_redisad, 
						reconnect => 100,
						every     => 3000);	


	my $filename = $redis->hget($id, "file");
	$filename = decode_utf8($filename);

	#print $filepath;
	$redis->del($id);

	#print $delcmd;
	$redis->quit();

	if (-e $filename)
	{ 
		unlink $filename; 
		return $filename; 
	}

	return "0";

	}