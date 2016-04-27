use strict;
use Redis;
use Encode;

require 'functions/functions_config.pl';

#deleteArchive($id)
#Deletes the archive with the given id from redis, and the matching archive file.
sub deleteArchive
	{

	my $id = $_[0];

	my $redis = Redis->new(server => &get_redisad, 
						reconnect => 100,
						every     => 3000);	

	my $filename = $redis->hget($id, "name");
	my $filename2 = $redis->hget($id, "file");
	$filename = decode_utf8($filename);
	$filename2 = decode_utf8($filename2);

	my $filepath = &get_dirname.'/'.$filename;
	#print $filepath;
	$redis->del($id);

	#print $delcmd;
	$redis->quit();

	unlink $filename2;

	if (-e $filename2)
		{ return "0"; }
	else
		{ return $filename2; }
	}