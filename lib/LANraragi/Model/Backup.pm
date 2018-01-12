package LANraragi::Model::Backup;

use strict;
use warnings;
use Redis;
use Encode;
use utf8;
use JSON::Parse 'parse_json';

use LANraragi::Model::Config;

#buildBackupJSON()
#Goes through the Redis archive IDs and builds a JSON string containing their metadata.
sub buildBackupJSON
 {
 	my $redis = &get_redis();
 	my $json = "[ ";
 	my $id;

 	#Fill the list with archives by looking up in redis
	my @keys = $redis->keys( '????????????????????????????????????????????????????????????????' ); #64-character long keys only => Archive IDs 

	#Parse the archive list and add them to JSON.
	foreach $id (@keys)
	{

		my %hash = $redis->hgetall($id);

		my ($event,$artist,$title,$series,$language,$tags) = @hash{qw(event artist title series language tags)};
		($_ = decode_utf8($_)) for ($event, $artist, $title, $series, $language, $tags);

		$json.=qq(
				{
					"arcid": "$id",
					"artist": "$artist",
					"title": "$title",
					"series": "$series",
					"language": "$language",
					"event": "$event",
					"tags": "$tags"
				},);
	}

	#remove last comma for json compliance
	chop($json);

	$json.="]";

	$redis->quit();

	return $json;

 }

#restoreFromJSON(backupJSON)
#Restores metadata from a JSON to the Redis archive, for existing IDs.
sub restoreFromJSON
 {
 	my $archive;
  	my $redis = &get_redis();

  	my $json = parse_json($_[0]);

	foreach $archive (@$json)
	{
		my $id = $archive->{"arcid"};

		#If the archive exists, restore metadata.
		if ($redis->hexists($id,"title"))
		{
			#jam this shit in redis
			#prepare the hash which'll be inserted.
			my %hash = (
				event => encode_utf8($archive->{"event"}),
				artist => encode_utf8($archive->{"artist"}),
				title => encode_utf8($archive->{"title"}),
				series => encode_utf8($archive->{"series"}),
				language => encode_utf8($archive->{"language"}),
				tags => encode_utf8($archive->{"tags"}),
				);
								
			#for all keys of the hash, add them to the redis hash $id with the matching keys.
			$redis->hset($id, $_, $hash{$_}, sub {}) for keys %hash; 
			$redis->wait_all_responses;

		}
	}

	$redis->quit();

 }