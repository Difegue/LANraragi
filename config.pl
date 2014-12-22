#Default config variables. Change as you see fit.

#Title of the html page.
my $htmltitle = "LANraragi"; 

#Text that appears on top of the page. Empty for no text. (look at me ma i'm versioning)
my $motd = "Welcome to this Library running LANraragi v.0.1.8!"; 

#Whether or not you load thumbnails when hovering over a title. Requires an imagemagick install. (Just imagemagick, none of these perlmagick thingamabobs)
my $thumbnails = 1; 

#Password-protect edit and upload modes. You'd do well to enable this if you're making the library available online.
my $enablepass = 1;

#Password for editing and uploading titles. You should probably change this, even though it's not "admin".
my $password = "kamimamita"; 
#Directory of the zip archives. Make sure your web server can serve what's inside this directory. (Write rights would help too.)
my $dirname = "./content"; 

#Resize images in reader when the original is heavier than this size. (in KBs.) (0 for no resizing)
my $sizethreshold = 900;

#Quality of the converted images if resized.
my $readerquality = 90; 

#Number of archives shown on a page. 0 for no pages.
my $pagesize = 100;

#Adress and port of redis instance.
my $redisaddress = "127.0.0.1:6379";

#Syntax of an archive's filename. Used in editing.
my $syntax = "(%RELEASE) [%ARTIST] %TITLE (%SERIES) [%LANGUAGE]";

#Regular Expression matching the above syntax. Used in parsing. Stuff that's between unescaped ()s is put in a numbered variable: $1,$2,etc
	#This regex autoparses the given string according to the exhentai standard convention: (Release) [Artist] TITLE (Series) [Language]
	#Parsing is only done the first time the file is found. The parsed info is then stored into Redis. 
	#Change this regex if you wish to use a different parsing for mass-addition of archives.
	
	#()? indicates the field is optional.
	#(\(([^([]+)\))? returns the content of (Release). Optional.
	#(\[([^]]+)\])? returns the content of [Artist]. Optional.
	#([^([]+) returns the title. Mandatory.
	#(\(([^([)]+)\))? returns the content of (Series). Optional.
	#(\[([^]]+)\])? returns the content of [Language]. Optional.
	#\s* indicates zero or more whitespaces.
my $regex = qr/(\(([^([]+)\))?\s*(\[([^]]+)\])?\s*([^([]+)\s*(\(([^([)]+)\))?\s*(\[([^]]+)\])?/;

#This sub defines which numbered variables from the regex selection are taken for display. In order:
# [release, artist, title, series, language]
sub regexsel { return ($2,$4,$5,$7,$9)};

###############VARIABLE SET UP ENDS HERE####################
######################END OF RINE###########################

#Functions that return the local config variables. Avoids fuckups if you happen to create a $motd variable in your own code, for example.

sub get_htmltitle { return $htmltitle };
sub get_motd { return $motd };
sub enable_thumbs { return $thumbnails };
sub enable_pass { return $enablepass };
sub get_password { return $password };
sub get_dirname  { return $dirname };
sub get_quality { return $readerquality };
sub get_syntax { return $syntax };
sub get_threshold { return $sizethreshold };
sub get_pagesize { return $pagesize };
sub get_thumbpref { return $generateonindex };
sub get_redisad { return $redisaddress };

use Digest::SHA qw(sha1 sha1_hex sha1_base64); #habbening
use URI::Escape;
use Redis;
use Encode;

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
	
#Delete the cached index.html. 
#This doesn't really require a sub, but it's cleaner in code to have "rebuild_index" instead of "unlink(./index.html);"

sub rebuild_index
	{
	unlink("./index.html");
	}

#parseName, with regex. [^([]+ 
sub parseName
	{
	my $id = $_[1];
	
	#Use the regex.
	$_[0] =~ $regex || next;

	my ($event,$artist,$title,$series,$language) = &regexsel;
	my $tags ="";
		
	return ($event,$artist,$title,$series,$language,$tags,$id);
	}
	

#returns the thumbnail path for a filename. Creates the thumbnail if it doesn't exist.
sub getThumb
{

my $dirname = &get_dirname;
my $id = $_[0];

my $thumbname = $dirname."/thumb/".$id.".jpg";

#Has a thumbnail already been made? And is it enabled in config?
	unless (-e $thumbname)
	{ #if it doesn't, let's create it!
		#my $zipFile = $dirname."/".$file;
		
		my $redis = Redis->new(server => &get_redisad, 
						reconnect => 100,
						every     => 2000);
						
		my $file = $redis->hget($id,"file");
		$file = decode_utf8($file);
		
		my $path = $dirname."/thumb/temp";		
				
		#Get lsar's output, jam it in an array, and use it as @extracted.
		my $vals = `lsar "$file"`; 
		#print $vals;
		my @lsarout = split /\n/, $vals;
		my @extracted; 
			
		#The -i 0 option on unar doesn't always return the first image, so we gotta rely on that lsar thing.
		#Sort on the lsar output to find the first image.					
		foreach $_ (@lsarout) 
			{
			if ($_ =~ /^(.*\/)*.+\.(png|jpg|gif|bmp|jpeg|PNG|JPG|GIF|BMP)$/ ) #is it an image? lsar can give us folder names.
				{push @extracted, $_ }
			}
					
		@extracted = sort { lc($a) cmp lc($b) } @extracted;
				
		#unar sometimes crashes on certain folder names inside archives. To solve that, we replace folder names with the wildcard * through regex.
		my $unarfix = @extracted[0];
		$unarfix =~ s/[^\/]+\//*\//g;
				
		#let's extract now.
		print("ZIPFILE-----"+$file+"bb--------");	
		`unar -D -o $path "$file" "$unarfix"`;
		
		my $path2 = $path.'/'.@extracted[0];
				
		#While we have the image, grab its SHA-1 hash for potential tag research later. 
		#That way, no need to repeat the costly extraction later.
		
		$redis->hset($id,"thumbhash", encode_utf8(shasum($path2)));
		$redis.close();
		
		#use ImageMagick to make the thumbnail. I tried using PerlMagick but it's a piece of ass, can't get it to build :s
		`convert -strip -thumbnail 200x "$path2" $thumbname`;
				
		#Delete the previously extracted file.
		unlink $path2;
	}
	return $thumbname;
}
	
#-------------------------------Unused Shit Below----------------------



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
