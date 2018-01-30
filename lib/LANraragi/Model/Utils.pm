package LANraragi::Model::Utils;

use strict;
use warnings;
use utf8;

use Digest::SHA qw(sha256_hex);
use File::Basename;
use Encode;
use URI::Escape;
use Redis;
use Image::Magick;

use LANraragi::Model::Config;

#Print a dropdown list to select CSS, and adds <link> tags for all the style sheets present in the /style folder.
#Takes a boolean as argument: if true, return the styles and the dropdown. If false, only return the styles.
sub generate_themes {

	#Getting all the available CSS sheets.
	my @css;
	opendir (DIR, "./public/themes") or die $!;
	while (my $file = readdir(DIR)) 
	{
		if ($file =~ /.+\.css/)
		{push(@css, $file);}

	}
	closedir(DIR);

	#button for deploying dropdown
	my $CSSsel = '<div class="menu" style="display:inline">
    				<span>
        				<a href="#"><input type="button" class="stdbtn" value="Change Library Look"></a>';

	#the list itself
	$CSSsel = $CSSsel.'<div>';

	#html that we'll insert before the list to declare all the available styles.
	my $html = "";

	#We opened a drop-down list. Now, we'll fill it.
	for ( my $i = 0; $i < $#css+1; $i++) 
	{
		#populate the div with spans
		my $css_name = LANraragi::Model::Config::css_default_names($css[$i]);
		$CSSsel = $CSSsel.'<span><a href="#" onclick="switch_style(\''.$i.'\');return false;">'.$css_name.'</a></span>';


		if ($css[$i] eq LANraragi::Model::Config->get_style) #if this is the default sheet, set it up as so.
			{$html=$html.'<link rel="stylesheet" type="text/css" title="'.$i.'" href="./themes/'.$css[$i].'"> ';}
		else
			{$html=$html.'<link rel="alternate stylesheet" type="text/css" title="'.$i.'" href="./themes/'.$css[$i].'"> ';}
	}		

	#close up dropdown list
	$CSSsel = $CSSsel.'</div>
    				</span>
				</div>';

	#Append JS to enable dropdown w.dropit (JS generation on the Perl side is heresy but this is bound to change soon)
	$CSSsel = $CSSsel." <script>
				\$('.menu').dropit({
					action: 'click', // The open action for the trigger
					submenuEl: 'div', // The submenu element
					triggerEl: 'a', // The trigger element
					triggerParentEl: 'span', // The trigger parent element
					afterLoad: function(){}, // Triggers when plugin has loaded
					beforeShow: function(){}, // Triggers before submenu is shown
					afterShow: function(){}, // Triggers after submenu is shown
					beforeHide: function(){}, // Triggers before submenu is hidden
					afterHide: function(){} // Triggers before submenu is hidden
				}); 
			</script>";

	if ($_[0])
	{return $html.$CSSsel;}
	else
	{return $html;}
	
}

#generate_thumbnail(original_image, thumbnail_location)
#use ImageMagick to make a thumbnail, width = 200px
sub generate_thumbnail {

	my ($orig_path, $thumb_path, $force) = @_;
	my $img = Image::Magick->new;
        
    $img->Read($orig_path);
    $img->Thumbnail(geometry => '200x');
    $img->Write($thumb_path);
}

#This function gives us a SHA-1 hash for the passed file, which is used as an id for some files. 
sub shasum {
	my $digest = "";
	eval{
	  open(FILE, $_[0]) or die "Can't find file $_[0]\n";
	  my $ctx = Digest::SHA->new;
   	$ctx->addfile(*FILE);
   	$digest = $ctx->hexdigest;
	  close(FILE);
	};
	if($@){
	  print $@;
	  return "";
	}
	return $digest;
}
	
#Remove spaces before and after a word 
sub remove_spaces {
	 until (substr($_[0],0,1)ne" "){
	 $_[0] = substr($_[0],1);}

	 until (substr($_[0],-1)ne" "){
	 chop $_[0];} 
}

#parse_name(name)
#parses an archive name with the regex specified in the configuration file(get_regex and select_from_regex subs) to find metadata.
sub parse_name {
	
	#Use the regex on our file, and pipe it to the regexsel sub.
	$_[0] =~ LANraragi::Model::Config->get_regex || next;

	#select_from_regex picks the variables from the regex selection that will be used. 
	my ($event,$artist,$title,$series,$language) = LANraragi::Model::Config->select_from_regex;
	my $tags = "";
		
	return ($event,$artist,$title,$series,$language,$tags);
}

#add_archive_to_redis($id,$file,$redis)
#Parses the name of a file for metadata, and matches that metadata to the SHA-1 hash of the file in our Redis database.
sub add_archive_to_redis {
 	my ($id, $file, $redis) = @_;
					
	my ($name,$path,$suffix) = fileparse($file, qr/\.[^.]*/);
					
	#parse_name function is up there 
	my ($event,$artist,$title,$series,$language,$tags) = &parse_name($name.$suffix);
					
	#jam this shit in redis
	#prepare the hash which'll be inserted.
	my %hash = (
		name => encode_utf8($name),
		event => encode_utf8($event),
		artist => encode_utf8($artist),
		title => encode_utf8($title),
		series => encode_utf8($series),
		language => encode_utf8($language),
		tags => encode_utf8($tags),
		file => encode_utf8($file),
		isnew => encode_utf8("block"), #New file in collection, so this flag is set.
		);
						
	#for all keys of the hash, add them to the redis hash $id with the matching keys.
	$redis->hset($id, $_, $hash{$_}, sub {}) for keys %hash; 
	$redis->wait_all_responses;

	return ($name,$event,$artist,$title,$series,$language,$tags,"block");
}

#build_archive_JSON(id, file, redis, userdir)
#Builds a JSON object for an archive already registered in the Redis database and returns it.
sub build_archive_JSON {
		my ($id, $file, $redis, $dirname) = @_;

		my %hash = $redis->hgetall($id);
		my ($path, $suffix);

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
		$suffix = (fileparse($file, qr/\.[^.]*/))[2];

		#Once we have the data, we can build our json object.
		my $urlencoded = $dirname."/".uri_escape($name).$suffix; 	
				
		#Tag display. Simple list separated by hyphens which expands into a caption div with nicely separated tags on hover.
		my $printedtags = "";

		unless ($event eq "") 
			{ $printedtags = $event.", ".$tags; }
		else
			{ $printedtags = $tags;}
		
		if ($title =~ /^\s*$/) #Workaround if title was incorrectly parsed as blank
			{ $title = "<i class='fa fa-exclamation-circle'></i> Untitled archive, please edit metadata.";}

		my $finaljson = qq(
			{
				"arcid": "$id",
				"url": "$urlencoded",
				"artist": "$artist",
				"title": "$title",
				"series": "$series",
				"language": "$language",
				"tags": "$tags",
				"isnew": "$isnew"
			},
		);

		#Try to UTF8-decode the JSON again, in case it has mangled characters. 
		eval { $finaljson = decode_utf8($finaljson) };

		return $finaljson;
 }

 1;