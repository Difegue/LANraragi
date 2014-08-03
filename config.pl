#Default config variables. Change as you see fit.
my $htmltitle = "LANraragi"; #Title of the html page.
my $motd = "Welcome to this Library running LANraragi v.0.0.1!"; #Text that appears on top of the page. Empty for no text.
my $thumbnails = 1; #Whether or not you load thumbnails when hovering over a title.
my $password = "kamimamita"; #Password for editing titles. You should probably change this, even though it's not "admin" 
my $dirname = "./content"; #Directory of the zip archives.

#Functions that return the local config variables. Avoids fuckups if you happen to create a $motd variable in your own code, for example.

sub get_htmltitle { return $htmltitle };
sub get_motd { return $motd };
sub get_thumbnails { return $thumbnails };
sub get_password { return $password };
sub get_dirname  { return $dirname };


#Removes spaces if present before a non-space character.
sub removeSpace
	{
	until (substr($_[0],0,1)ne" "){
			$_[0] = substr($_[0],1);}
	}

#Removes spaces at the end of a file.
sub removeSpaceR
	{
	until (substr($_[0],-1,1)ne" "){
			$_[0] = substr($_[0],-1);}
	}
	
sub parseName
	{
		my ($event,$artist,$title,$series,$language,$tags) = (" "," "," "," "," "," ");
		my @values=(" "," ");
		my $temp=$_[0];
		
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
		@values = split('\(', $temp, 2); #Title. If there's no following (Series), the entire filename is taken and other variables are emptied by default. ┐(￣ー￣)┌
		$title = $values[0];
		$temp = $values[1];
		
		removeSpace($temp);
		
		@values = split('\)', $temp, 2); #Series
		$series = $values[0];
		$temp = $values[1];

		removeSpace($temp);
		
		@values = split(']', $temp, 2); #Language
		$language = substr($values[0],1);
		$temp = $values[1];

		removeSpace($temp);		

		#does the filename contain tags?
		if (substr($temp, 0, 1)eq"$") 
		{
			$tags = substr($temp,1); #only tags left
		}
		
		return ($event,$artist,$title,$series,$language,$tags);
	}
