package LANraragi::Model::Utils;

use strict;
use warnings;
use utf8;

use LANraragi::Model::Config;

use Digest::SHA qw(sha256_hex);
use File::Basename;
use Redis;

#Print a dropdown list to select CSS, and adds <link> tags for all the style sheets present in the /style folder.
#Takes a boolean as argument: if true, return the styles and the dropdown. If false, only return the styles.
sub printCssDropdown
 {

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
	my $html;

	#We opened a drop-down list. Now, we'll fill it.
	for ( my $i = 0; $i < $#css+1; $i++) 
	{
		#populate the div with spans
		$CSSsel = $CSSsel.'<span><a href="#" onclick="switch_style(\''.$i.'\');return false;">'.&cssNames(@css[$i]).'</a></span>';


		if (@css[$i] eq &get_style) #if this is the default sheet, set it up as so.
			{$html=$html.'<link rel="stylesheet" type="text/css" title="'.$i.'" href="./styles/'.@css[$i].'"> ';}
		else
			{$html=$html.'<link rel="alternate stylesheet" type="text/css" title="'.$i.'" href="./styles/'.@css[$i].'"> ';}
	}		

	#close up dropdown list
	$CSSsel = $CSSsel.'</div>
    				</span>
				</div>';

	if ($_[0])
	{return $html.$CSSsel;}
	else
	{return $html;}
	
 }
	

#This handy function gives us a SHA-1 hash for the passed file, which is used as an id for some files. 
sub shasum
 {
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
	

sub removeSpaceF #Remove spaces before and after a word 
 {
	 until (substr($_[0],0,1)ne" "){
	 $_[0] = substr($_[0],1);}

	 until (substr($_[0],-1)ne" "){
	 chop $_[0];} 
 }

#magical sort function
sub expand 
 {
    my $file=shift; 
    $file=~s{(\d+)}{sprintf "%04d", $1}eg;
    return $file;
 }

#parseName(name,id)
#parses an archive name with the regex specified in the configuration file(get_regex and select_from_regex subs) to find metadata.
sub parseName
 {
	my $id = $_[1];
	
	#Use the regex on our file, and pipe it to the regexsel sub.
	$_[0] =~ &get_regex || next;

	#select_from_regex picks the variables from the regex selection that will be used. 
	my ($event,$artist,$title,$series,$language) = &select_from_regex;
	my $tags ="";
		
	return ($event,$artist,$title,$series,$language,$tags,$id);
 }

#addArchiveToRedis($id,$file,$redis)
#Parses the name of a file for metadata, and matches that metadata to the SHA-1 hash of the file in our Redis database.
sub addArchiveToRedis
 {
 	my ($id, $file, $redis) = @_;
					
	my ($name,$path,$suffix) = fileparse($file, qr/\.[^.]*/);
					
	#parseName function is up there 
	my ($event,$artist,$title,$series,$language,$tags,$id) = &parseName($name.$suffix,$id);
					
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

 1;