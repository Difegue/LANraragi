#Default config variables. Change as you see fit.

#Title of the html page.
my $htmltitle = "LANraragi"; 

#Text that appears on top of the page. Empty for no text. (look at me ma i'm versioning)
my $motd = "Welcome to this Library running LANraragi v.0.1.1!"; 

#Whether or not you load thumbnails when hovering over a title. Requires an imagemagick install. (Just imagemagick, none of these perlmagick thingamabobs)
my $thumbnails = 1; 

#Password-protect edit and upload modes. You'd do well to enable this if making the library available online.
my $enablepass = 1;

#Password for editing and uploading titles. You should probably change this, even though it's not "admin".
my $password = "kamimamita"; 

#Directory of the zip archives. Make sure your web server can serve what's inside this directory.
my $dirname = "./content"; 

#If enabled, images will be resized when viewed through the reader to allow faster image transferring. (You can downsize individual images to 300KBs or so with 50% quality on) 
#Keep in mind the resizing will take some extra time upon loading an archive, so you should only use this when making your library available through the internet. Requires imagemagick.
my $shitbandwidth = 0; 

#Quality of the converted images if passed through the shitbandwidth resizer.
my $readerquality = 50; 

###############VARIABLE SET UP ENDS HERE####################
######################END OF RINE###########################

#Functions that return the local config variables. Avoids fuckups if you happen to create a $motd variable in your own code, for example.

sub get_htmltitle { return $htmltitle };
sub get_motd { return $motd };
sub enable_thumbs { return $thumbnails };
sub enable_pass { return $enablepass };
sub get_password { return $password };
sub get_dirname  { return $dirname };
sub get_bd { return $shitbandwidth };
sub get_quality { return $readerquality };


use Digest::MD5 qw(md5 md5_hex md5_base64); #habbening

#This handy function gives us a md5 hash for the passed file, which is used as an id for some files. It's possible to make it so that two files have the same md5 hashes, but I ain't gonna bother implementing something else, hf breaking it if you want to
sub md5sum{
  my $file = shift;
  my $digest = "";
  eval{
    open(FILE, $file) or die "Can't find file $file\n";
    my $ctx = Digest::MD5->new;
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

#Splits a name into fields that are treated. Syntax is (Release) [Artist (Pseudonym) ] TITLE (Series) [Language] misc shit .zip
sub parseName
	{
		my ($event,$artist,$title,$series,$language,$tags) = (" "," "," "," "," "," ");
		my @values=(" "," ");
		my $temp=$_[0];
		my $id = md5sum(&get_dirname.'/'.$_[0].'.zip');
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
	