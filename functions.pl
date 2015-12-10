use Digest::SHA qw(sha1 sha1_hex sha1_base64); #habbening
use URI::Escape;
use Redis;
use Encode;
use LWP::Simple qw/get/;
use JSON::Parse 'parse_json';

require 'config.pl';

#getGalleryId(hash(or text),isHash)
#Takes an image hash or basic text, performs a remote search on g.e-hentai, and builds the matching JSON to send to the API for data.
sub getGalleryId{

	my $hash = $_[0];
	my $isHash = $_[1];
	my $URL;

	if ($isHash eq "1")
	{	#search with image SHA hash
		$URL = "http://g.e-hentai.org/".
				"?f_doujinshi=1&f_manga=1&f_artistcg=1&f_gamecg=1&f_western=1&f_non-h=1&f_imageset=1&f_cosplay=1&f_asianporn=1&f_misc=1".
				"&f_search=Search+Keywords&f_apply=Apply+Filter&f_shash=".$hash."&fs_similar=1";
	}
	else
	{	#search with archive title
		$URL = "http://g.e-hentai.org/".
				"?f_doujinshi=1&f_manga=1&f_artistcg=1&f_gamecg=1&f_western=1&f_non-h=1&f_imageset=1&f_cosplay=1&f_asianporn=1&f_misc=1".
				"&f_search=".$hash."&f_apply=Apply+Filter";
	}
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
	return qq({
				"method": "gdata",
				"gidlist": [
					[$gID,"$gToken"]
				]
				});
	
}

#Executes an API request with the given JSON and returns 
sub getTagsFromAPI{
	
	my $uri = 'http://g.e-hentai.org/api.php';
	my $json = $_[0];
	my $req = HTTP::Request->new( 'POST', $uri );
	$req->header( 'Content-Type' => 'application/json' );
	$req->content( $json );

	#Then you can execute the request with LWP:

	my $ua = LWP::UserAgent->new; 
	my $res = $ua->request($req);
	
	#$res is a JSON response. 
	#print $res->decoded_content;
	my $jsonresponse = $res -> decoded_content;
	my $hash = parse_json($jsonresponse);
	
	#eval {
	unless (exists $hash->{"error"})
	{
		my $data = $hash->{"gmetadata"};
		my $tags = @$data[0]->{"tags"};

		my $return = join(" ", @$tags);
		return $return;
	}	
	else 
	{
	return ""; #if an error occurs(no tags available) return an empty string.
	}

}


#Print a dropdown list to select CSS, and adds <link> tags for all the style sheets present in the /style folder.
#Takes a boolean as argument: if true, return the styles and the dropdown. If false, only return the styles.
sub printCssDropdown{

	#Getting all the available CSS sheets.
	my @css;
	opendir (DIR, "./styles/") or die $!;
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
		if (@css[$i] ne "lrr.css") #quality work
		{
			#populate the div with spans
			$CSSsel = $CSSsel.'<span><a href="#" onclick="switch_style(\''.$i.'\');return false;">'.&cssNames(@css[$i]).'</a></span>';


			if (@css[$i] eq &get_style) #if this is the default sheet, set it up as so.
				{$html=$html.'<link rel="stylesheet" type="text/css" title="'.$i.'" href="./styles/'.@css[$i].'"> ';}
			else
				{$html=$html.'<link rel="alternate stylesheet" type="text/css" title="'.$i.'" href="./styles/'.@css[$i].'"> ';}

		}
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
sub shasum{
  my $digest = "";
  eval{
    open(FILE, $_[0]) or die "Can't find file $file\n";
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

#Removes spaces if present before a non-space character.
sub removeSpace
	{
	until (substr($_[0],0,1)ne" "){
			$_[0] = substr($_[0],1);}
	}

#Removes spaces at the end of a file.
sub removeSpaceR
	{
	until (substr($_[0],-1)ne" "){
			chop $_[0];} #perl is literally too based to exist
	}

sub removeSpaceF #hue
	{
	removeSpace($_[0]);
	removeSpaceR($_[0]);
	}
	

#parseName, with regex. [^([]+ 
sub parseName
	{
	my $id = $_[1];
	
	#Use the regex.
	$_[0] =~ &get_regex || next;

	my ($event,$artist,$title,$series,$language) = &regexsel;
	my $tags ="";
		
	return ($event,$artist,$title,$series,$language,$tags,$id);
	}
	

#-------------------------------Unused Shit Below----------------------

#Delete the cached index.html. 
#This doesn't really require a sub, but it's cleaner in code to have "rebuild_index" instead of "unlink(./index.html);"

sub rebuild_index
	{
	unlink("./index.html");
	}

#Splits a name into fields that are treated. Syntax is (Release) [Artist (Pseudonym) ] TITLE (Series) [Language] misc shit .extension
#old version with substr and stuff, use if you don't like regexes or something
sub parseNameOld
	{
		my ($event,$artist,$title,$series,$language,$tags) = (" "," "," "," "," "," ");
		my @values=(" "," ");
		my $temp=$_[0];
		my $id = shasum(&get_dirname.'/'.$_[0]);
		my $noseries = 0;
		
		#Split up the filename
		#Is the field present? If not, skip it.
		removeSpace($temp);
		if (substr($temp, 0, 1)eq'(') 
			{
			@values = split('\)', $temp, 2); # (Event)
			$event = substr($values[0],1);
			$temp = $values[1];
			}
		removeSpace($temp);
			
		if (substr($temp, 0, 1)eq"[") 
			{
			@values = split(']', $temp, 2); # [Artist (Pseudonym)]
			$artist = substr($values[0],1);
			$temp = $values[1];
			}
		removeSpace($temp);
			
		#Always needs something in title, so it can't be empty
		
		@values = split('\(', $temp, 2); #Title. If there's no following (Series), we try again, looking for a [ instead, for language.
		#we'll know that there was no series if the array resulting from the split has only one element. That'd mean that there was no split.
		
		if (@values[1] eq '')
			{
			@values = split('\[', $temp, 2);
			$values[1] = "\[".$values[1]; #ugly as shit fix to make the language parsing work in both cases. Since split removes the [, we gotta...add it back.
			$noseries = 1;
			}
		
		$title = $values[0];
		$temp = $values[1];
		
		removeSpace($temp);
		
		unless ($noseries)
		{
			@values = split('\)', $temp, 2); #Series
			$series = $values[0];
			$temp = $values[1];

			removeSpace($temp);
		}
		
		@values = split(']', $temp, 2); #Language
		$language = substr($values[0],1);
		$temp = $values[1];

		removeSpace($temp);		

		#Is there a tag file?
		if (-e &get_dirname.'/tags/'.$id.'.txt')
		{
			open (MYFILE, &get_dirname.'/tags/'.$id.'.txt'); 
			while (<MYFILE>) {
				$tags = $tags.$_; #copy txt into tags
			}
		close (MYFILE); 
		}
		
		return ($event,$artist,$title,$series,$language,$tags,$id);
	}

	
#Sort an array of parsable filenames by their titles. Unused as of now.
sub parseSort
{
my $file= "";
my @params;

my ($event,$artist,$title,$series,$language,$tags,$id);

foreach $file (@_)
	{
	($event,$artist,$title,$series,$language,$tags,$id) = &parseName($file);
	push(@params, $title);		
	}
	
#print "@params\n";

#Both @params and the argument array's indexes match. All we have to do now is sort both at the same time, with params as reference.
#This is perl magic. Took me a while to understand, so I'll try to explain as best as I can.

my @indx = sort {lc $params[$a] cmp lc $params[$b] } (0..$#params); 
#We have an array of 0 to length(params). That's (0..$#params). 
#We sort it according to the contents of $params. If 1 matched BTile and 2 matched ATitle, the result in @idk would be [2,1].
#@idx ends up being our sorted index, which we apply to the original array of file names.

@params = @params[@indx]; 
@_ = @_[@indx];

#print "@params\n";
return @_;
	
}	



