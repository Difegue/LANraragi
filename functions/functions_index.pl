use strict;
use utf8;
use URI::Escape;
use Redis;
use Encode;
use File::Path qw(make_path remove_tree);
use File::Basename;

require 'functions/functions_config.pl';

#generateTableJSON(@list)
#With a list of files, generates JSONs.
#One JSON contains all existing archives in the database, alongside their info.
sub generateTableJSON
 {
		my @dircontents = @_;

		my ($file,$id);

		my $newfiles = 0;

		my $redis = &getRedisConnection();

		#Start building JSONs
		# $json is for archives that are already parsed and in redis. 
		# $newfilesjson is for new archives that haven't been parsed yet.
		my $json = "[";
		my $newfilesjson = "[";

		foreach $file (@dircontents)
		{
			#ID of the archive, used for storing data in Redis.
			$id = sha256_hex($file);

			#Let's check out the Redis cache first to see if the archive has already been parsed
			if ($redis->hexists($id,"title"))
				{
					#bingo, no need for expensive file parsing operations.
					if ( $newfiles == 0) #small optimization to just ignore existing archive parsing if new archives are present 
						{ $json.=&parseExistingArchive($id, $file, $redis); }

				}
			else 
				{ 
					#New archives are present. We discard the regular archive json and add objects to the new files json instead.
					$newfiles++;

					#The new files json will be used on the client side to show a dynamic loading screen, using ajax calls to add the archives to redis.	
					$newfilesjson.= qq(
										{
											"arcid": "$id",
											"file": "$file",
										},
									);

				}
			
		}


		$json.="]";
		$newfilesjson.="]";

		return ($json, $newfilesjson);
 }


#parseExistingArchive(id, file, redis)
#Builds a JSON object for an archive already registered in the Redis database and returns it.
sub parseExistingArchive()
 {
		my ($id, $file, $redis) = @_;
		my $dirname = &get_dirname;

		my %hash = $redis->hgetall($id);
		my ($filecheck, $path, $suffix);

		#It's not a new archive, though. But it might have never been clicked on yet, so we'll grab the value for $isnew stored in redis.
		my ($name,$event,$artist,$title,$series,$language,$tags,$filecheck,$isnew) = @hash{qw(name event artist title series language tags file isnew)};

		#Parameters have been obtained, let's decode them.
		( eval { $_ = decode_utf8($_) } ) for ($name, $event, $artist, $title, $series, $language, $tags, $filecheck);

		#Update the real file path and title if they differ from the saved one just in case the file got manually renamed or some weird shit
		unless ($file eq $filecheck)
		{
			($name,$path,$suffix) = fileparse($file, qr/\.[^.]*/);
			$redis->hset($id, "file", encode_utf8($file));
			$redis->hset($id, "name", encode_utf8($name));
			$redis->wait_all_responses;
		}	

		#Grab the suffix to put it in the url for downloads
		my $suffix = (fileparse($file, qr/\.[^.]*/))[2];

		#Once we have the data, we can build our json object.
		my $urlencoded = $dirname."/".uri_escape($name).$suffix; 	
				
		#Tag display. Simple list separated by hyphens which expands into a caption div with nicely separated tags on hover.
		my $printedtags = "";

		unless ($event eq "") 
			{ $printedtags = $event.", ".$tags; }
		else
			{ $printedtags = $tags;}
		

		my $thumbname = "./img/thumb/".$id.".jpg";

		unless (-e $thumbname)
			{ $thumbname = "null"; } #force ajax thumbnail if the image doesn't already exist

		if ($title =~ /^\s*$/) #Workaround if title was incorrectly parsed as blank
			{ $title = "<i class='fa fa-exclamation-circle'></i> Untitled archive, please edit metadata.";}

		my $finaljson = qq(
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

		#Try to UTF8-decode the JSON again, in case it has mangled japanese characters. 
		#This comes from a misstep somewhere earlier in the code, but the whole unicode situation is such a mess this'll do as a bandaid.
		eval { $finaljson = decode_utf8($finaljson) };

		return $finaljson;

 }