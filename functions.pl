use Digest::SHA qw(sha1 sha1_hex sha1_base64); #habbening
use URI::Escape;
use Redis;
use Encode;

require 'config.pl';

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

	#dropdown list
	my $CSSsel = '<div style="position: absolute; right: 20px;" ><form style="float: right;"><select size="1">'; 
	
	$CSSsel = $CSSsel.'<option>Select a custom style</option>';

	#link tags
	my $html;

	#We opened a drop-down list. Now, we'll fill it.
	for ( my $i = 0; $i < $#css+1; $i++) 
	{
		if (@css[$i] ne "lrr.css") #quality work
		{
			$CSSsel = $CSSsel.'<option onclick="switch_style(\''.$i.'\');return false;">'.&cssNames(@css[$i]).' </option>';
			if (@css[$i] eq &get_style) #if this is the default sheet, set it up as so.
				{$html=$html.'<link rel="stylesheet" type="text/css" title="'.$i.'" href="./styles/'.@css[$i].'"> ';}
			else
				{$html=$html.'<link rel="alternate stylesheet" type="text/css" title="'.$i.'" href="./styles/'.@css[$i].'"> ';}

		}
	}		

	$CSSsel = $CSSsel.'</select></form></div>';

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
	

#returns the thumbnail path for a filename. Creates the thumbnail if it doesn't exist.
sub getThumb
{
	my $dirname = &get_dirname;
	my $id = $_[0];

	my $thumbname = $dirname."/thumb/".$id.".jpg";
	#let's create it!
			
	my $redis = Redis->new(server => &get_redisad, 
					reconnect => 100,
					every     => 2000);
							
	my $file = $redis->hget($id,"file");
	$file = decode_utf8($file);
			
	my $path = $dirname."/thumb/temp";	
	#delete everything in tmp to prevent file mismatch errors.
	unlink glob $path."/*.*";

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
	
	return $thumbname;
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
