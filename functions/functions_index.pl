use strict;
use utf8;
use URI::Escape;
use Redis;
use Encode;
use File::Path qw(make_path remove_tree);
use File::Basename;

require 'functions/functions_config.pl';

#With a list of files, generate the HTML table that will be shown in the main index.
sub generateTableJSON
 {
		my @dircontents = @_;
		my $file = "";
		
		my $path = "";
		my $suffix = "";
		my ($name,$event,$artist,$title,$series,$language,$tags,$id,$isnew) = (" "," "," "," "," "," "," ","none");

		my $dirname = &get_dirname;

		my $redis = Redis->new(server => &get_redisad, 
							reconnect => 100,
							every     => 3000);

		#Start building JSON
		my $json = "[";

		foreach $file (@dircontents)
		{
			#ID of the archive, used for storing data in Redis.
			$id = sha256_hex($file);

			#Let's check out the Redis cache first to see if the archive has already been parsed
			if ($redis->hexists($id,"title"))
				{
					#bingo, no need for expensive file parsing operations.
					my %hash = $redis->hgetall($id);
					my $filecheck = "";

					#It's not a new archive, though. But it might have never been clicked on yet, so we'll grab the value for $isnew stored in redis.
					($name,$event,$artist,$title,$series,$language,$tags,$filecheck,$isnew) = @hash{qw(name event artist title series language tags file isnew)};

					#Parameters have been obtained, let's decode them.
					($_ = decode_utf8($_)) for ($name, $event, $artist, $title, $series, $language, $tags, $filecheck);

					#Update the real file path and title if they differ from the saved one just in case the file got manually renamed or some weird shit
					unless ($file eq $filecheck)
					{
						($name,$path,$suffix) = fileparse($file, qr/\.[^.]*/);
						$redis->hset($id, "file", encode_utf8($file));
						$redis->hset($id, "name", encode_utf8($name));
						$redis->wait_all_responses;
					}	

				}
			else #can't be helped, parse archive and add it to Redis alongside its metadata.
				{ ($name,$event,$artist,$title,$series,$language,$tags,$isnew) = &addArchiveToRedis($id,$file,$redis); }

			#Once we have the data, we can build our line.

			my $urlencoded = $dirname."/".uri_escape($name); 	
					
			#Tag display. Simple list separated by hyphens which expands into a caption div with nicely separated tags on hover.
			my $printedtags = "";

			unless ($event eq "") 
				{ $printedtags = $event.", ".$tags; }
			else
				{ $printedtags = $tags;}
			

			my $thumbname = $dirname."/thumb/".$id.".jpg";

			unless (-e $thumbname)
				{ $thumbname = "null"; } #force ajax thumbnail if the image doesn't already exist

			$json.=qq(
				{
					"arcid": "$id",
					"url": "$urlencoded",
					"thumbnail": "$thumbname",
					"artist": "$artist",
					"title": "$title",
					"series": "$series",
					"language": "$language",
					"tags": "$tags",
					"isnew": "$isnew"
				},
			);
			
		}


		$json.="]";

		return $json;
 }