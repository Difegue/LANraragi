use strict;
use URI::Escape;
use File::Basename;
use LWP::Simple qw($ua get);
use JSON::Parse 'parse_json';
use Redis;
use Encode;

require 'functions/functions_config.pl';


#addTags($id,$tags)
#Adds the given $tags to the Redis storage for $id. Used in batch tagging.
sub addTags
 {
	my $id = $_[0];
	my $tags = $_[1];

	unless ($tags eq "NOTAGS" || $tags eq "NOTHUMBNAIL")
	{

		my $redis = &getRedisConnection();
		my $oldTags = $redis->hget($id,"tags");
		
		if ($oldTags eq "")
			{ $oldTags = $tags; }
		else
			{$oldTags.=", ".$tags; }

		$redis->hset($id,"tags",encode_utf8($oldTags));

		$redis->quit();
	}

 }


############################
##### e-hentai methods #####
############################

#eHentaiGetTags(redisId,isHash)
#Takes an archive ID's title/thumbnail hash and gets a g.e-hentai URL to use for searching.
sub eHentaiGetTags
 {

	my $id = $_[0];
	my $isHash = $_[1];
	my $URL;

	my $redis = &getRedisConnection();

	my $title = $redis->hget($id,"title");
	my $artist = $redis->hget($id,"artist");
	my $thumbhash = $redis->hget($id,"thumbhash");
	$title = decode_utf8($title);
	$artist = decode_utf8($artist);
	$thumbhash = decode_utf8($thumbhash);

	if ($isHash eq "1")
	{	
		#Check if we do have a thumbnail hash
		if ($thumbhash eq "")
		{
			die "No thumbnail hash available, stopped";
		}

		#search with image SHA hash
		$URL = "http://g.e-hentai.org/".
				"?f_doujinshi=1&f_manga=1&f_artistcg=1&f_gamecg=1&f_western=1&f_non-h=1&f_imageset=1&f_cosplay=1&f_asianporn=1&f_misc=1".
				"&f_search=Search+Keywords&f_apply=Apply+Filter&f_shash=$thumbhash&fs_similar=1";
	}
	else
	{	#search with archive title
		$URL = "http://g.e-hentai.org/".
				"?f_doujinshi=1&f_manga=1&f_artistcg=1&f_gamecg=1&f_western=1&f_non-h=1&f_imageset=1&f_cosplay=1&f_asianporn=1&f_misc=1".
				"&f_search=".uri_escape($title." ".$artist)."&f_apply=Apply+Filter";
	}
	
	return &eHentaiLookup($URL);
	
 }

#eHentaiLookup(URL)
#Performs a remote search on g.e-hentai, and builds the matching JSON to send to the API for data.
sub eHentaiLookup()
 {
 	my $URL = $_[0];
 	my $content = get $URL;

	#now for the parsing of the HTML we obtained.
	#the first occurence of <tr class="gtr0"> matches the first row of the results. 
	#If it doesn't exist, what we searched isn't on E-hentai.
	my @benis = split('<tr class="gtr0">', $content);
	
	#Inside that <tr>, we look for <div class="it5"> . the <a> tag inside has an href to the URL we want.
	my @final = split('<div class="it5">',@benis[1]);

	my $url = (split('http://g.e-hentai.org/g/',@final[1]))[1];

	
	my @values = (split('/',$url));

	my $gID = @values[0];
	my $gToken = @values[1];

	#Returning shit yo
	return qq({"method": "gdata","gidlist": [[$gID,"$gToken"]]});

 }

#getTagsFromEHAPI(JSON)
#Executes an e-hentai API request with the given JSON and returns 
sub getTagsFromEHAPI
 {
	
	my $uri = 'http://g.e-hentai.org/api.php';
	my $json = $_[0];
	my $req = HTTP::Request->new( 'POST', $uri );
	$req->header( 'Content-Type' => 'application/json' );
	$req->content( $json );

	#Execute the request with LWP:
	my $ua = LWP::UserAgent->new; 
	$ua->agent('LANraragi Tag Lookup/1337.0');
	my $res = $ua->request($req);
	
	#$res is a JSON response. 
	my $jsonresponse = $res -> decoded_content;
	my $hash = parse_json($jsonresponse);

	unless (exists $hash->{"error"})
	{
		my $data = $hash->{"gmetadata"};
		my $tags = @$data[0]->{"tags"};

		my $return = join(", ", @$tags);
		return $return; #Strip first comma
	}	
	else #if an error occurs(no tags available) return an empty string.
		{ return ""; }

 }



###########################
##### nHentai Methods #####
###########################

#nHentaiGetTags(id)
#nhentai version. Gets the galleryID then the json page for scraping tags.
sub nHentaiGetTags
 {
	my $id = $_[0];
	my $URL;
	
	my $redis = &getRedisConnection();

	my $title = $redis->hget($id,"title");
	my $artist = $redis->hget($id,"artist");

	#quote the title to ensure we don't get random galleries with parts of it.
	$URL = "https://nhentai.net/api/galleries/search?query=\"".uri_escape($title)."\"+".uri_escape($artist);

	my $gID = &nHentaiLookup($URL);

	return &getTagsFromNHAPI($gID);

 }

#nHentaiLookup(URL)
#Uses the website's search API to find a gallery and returns its gallery ID.
sub nHentaiLookup
 {
 	my $URL = $_[0];
 	$ua->agent('LANraragi Tag Lookup/1337.0');
	my $content = get $URL;

	my $json = parse_json($content);

	#get the first gallery of the research
	my $gallery = $json->{"result"};
	$gallery = @$gallery[0];

	return $gallery->{"id"};
 }

#getTagsFromNHAPI(galleryID)
# Parses the JSON obtained from the nhentai API to get the tags.
sub getTagsFromNHAPI
 {
 	my $gID = $_[0];
 	my $tag = "";
 	my $returned = "";

 	my $URL = "https://nhentai.net/api/gallery/$gID";

 	$ua->agent('LANraragi Tag Lookup/1337.0');
 	my $content = get $URL;

	my $json = parse_json($content);
	my $tags = $json->{"tags"};

	foreach $tag (@$tags)
	{
		#if ($tag->{"type"} eq "tag" )
			#{ 
				$returned.=", ".$tag->{"name"}; 
			#}
	}

	return substr $returned, 2; #Strip first comma and space

 }
