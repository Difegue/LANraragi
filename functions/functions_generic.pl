use strict;
use Digest::SHA qw(sha256_hex);

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
