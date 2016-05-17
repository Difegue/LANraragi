use strict;
use utf8;
use Redis;
use IPC::Cmd qw[can_run run];
use File::Basename;
use File::Path qw(remove_tree);
use Encode;
use Image::Info qw(image_info dim);
use File::Find qw(find);
use Image::Magick;

require 'functions/functions_config.pl';
require 'functions/functions_login.pl';

#printReaderErrorPage($filename,$log)
sub printReaderErrorPage
 {

	my $filename = $_[0];
	my $errorlog = $_[1];
	
	print "<img src='./img/flubbed.gif'/><br/>
			<h2>I flubbed it while trying to open the archive ".$filename.".</h2>It's likely the archive contains a folder with unicode characters.<br/> No real way around that for now besides modifying your archive, sorry !<br/>";

	print "<h3>Some more info below :</h3> <br/>";
	print decode_utf8($errorlog);

 }




#getImage(id,forceReload,refreshThumbnail,pageNumber)
#Returns the filepath to the requested page of the archive specified by its ID.
sub getImage
 {

	my ($id, $force, $thumbreload, $pagenum) = @_;
	my $img = Image::Magick->new; #Used for image resizing
	my $tempdir = &get_dirname."/temp";
	

	#Redis stuff: Grab archive path and update some things
	my $redis = Redis->new(server => &get_redisad, 
				reconnect => 100,
				every     => 3000);
	
	#We opened this id in the reader, so we can't mark it as "new" anymore.
	$redis->hset($id,"isnew","none");

	#Get the path from Redis.
	my $zipfile = $redis->hget($id,"file");
	$zipfile = decode_utf8($zipfile);

	#Get data from the path 
	my ($name,$fpath,$suffix) = fileparse($zipfile, qr/\.[^.]*/);
	my $filename = $name.$suffix;
	
	my $path = $tempdir."/".$id;
	
	if (-e $path && $force eq "1") #If the file has been extracted and force-reload=1, we wipe the extraction directory.
	{ remove_tree($path); }

	#Now, has our file been extracted to the temporary directory recently?
	#If it hasn't, we call unar to do it.
	unless(-e $path) #If the file hasn't been extracted, or if force-reload =1
		{
		 	my $unarcmd = "unar -D -o $path \"$zipfile\" "; #Extraction using unar without creating extra folders.

		 	my( $success, $error_message, $full_buf, $stdout_buf, $stderr_buf ) =
	            run( command => $unarcmd, verbose => 0 ); 

		 	#Has the archive been extracted ? If not, stop here and print an error page.
			unless (-e $path) {
				my $errlog = join "<br/>", @$full_buf;
				&printReaderErrorPage($filename,$errlog);
				exit;
			}
		}
		
	#Find the extracted images with a full search (subdirectories included)
	my @images;
	find({ wanted => sub { 
							if ($_ =~ /^*.+\.(png|jpg|gif|bmp|jpeg|PNG|JPG|GIF|BMP)$/ ) #is it an image? readdir tends to read folder names too...
								{push @images, $_ }
						} , no_chdir => 1 }, $path); #find () does exactly that. 
			  
    my @images = sort { &expand($a) cmp &expand($b) } @images;
    
	
	if (defined $pagenum) #Has a specific page been mentioned? If so, that's the one we'll need to display.
		{
		if ($pagenum <= 0)
			{$pagenum = 1;}

		if ($pagenum >= $#images+1)
			{$pagenum = $#images+1;}
		}
		else #We're on page 1: we can convert it into a thumbnail for the main reader index if it's not been done already(Or if it fucked up for some reason).
		{
			my $thumbname = &get_dirname."/thumb/".$id.".jpg";

			unless (-e $thumbname && $thumbreload eq "0")
			{
				my $path = @images[0];
				$redis->hset($id,"thumbhash", encode_utf8(shasum($path)));

				#use ImageMagick to make the thumbnail. width = 200px
		        
		        $img->Read($path);
		        $img->Thumbnail(geometry => '200x');
		        $img->Write($thumbname);

				$pagenum = 1; #Default page setting for imgpath below.
			}

		}

	my $imgpath = @images[$pagenum-1]; #This is the page we'll display.
	
	#convert to a cheaper on bandwidth format if the option is enabled.
	if (&enable_resize)
	{
			#Is the file size higher than the threshold?
			if ( (int((-s $imgpath )/ 1024*10)/10 ) > &get_threshold)
			{
				$img->Read($imgpath);
				$img->Resize(geometry => '1064x');
				$img->Set(quality=>&get_quality);
				$img->Write($imgpath);

				#`mogrify -scale 1064x -quality $quality "$imgpath"`; 
			}
	}

	#We return the path to the image and the number of pages the archive contains.
	return ($imgpath, $#images+1);

 }




#printReaderHTML(id,extractedImage,archiveName,archiveTotalPages, cgi, pagenum)
#Computes all the necessary values to feed to the HTML template for a reader page.
#Image info, number of pages, page we're actually in, image path.
sub printReaderHTML
 {

	my ( $id, $imgpath, $arcname, $arcpages, $cgi, $pagenum) = @_;

	unless (defined $pagenum)
		{ $pagenum = 1; }

	if ($pagenum >= $arcpages)
		{ $pagenum = $arcpages; }

	if ($pagenum < 1)
		{ $pagenum = 1; }

	#Let's get more precise info on the image to display. 
	my $info = image_info($imgpath);
		
	#gonna reuse those variables.
	my ($namet,$patht,$suffixt) = fileparse($imgpath, qr/\.[^.]*/);
	
	#Outputs something like "0001.png :: 1052 x 1500 :: 996.6 KB".
	my $size = (int((-s ($imgpath) )/ 1024*10)/10 ) ;
	
	my $imgwidth = $info->{width}; 
	my $imgheight = $info->{height}; 
	my $imgmapwidth = int($imgwidth/2 + 0.5);

	my $filename = $namet.$suffixt;
	
	#We need to sanitize the image's path, in case the folder contains illegal characters, but uri_escape would also nuke the / needed for navigation.
	#Let's solve this with a quick regex search&replace.
	#First, we sanitize it all...
	$imgpath = escapeHTML($imgpath);
	
	#Then we bring the slashes back.
	$imgpath =~ s!%2F!/!g;
	
	#Time to spit out the template.
	my $tt  = Template->new({
        INCLUDE_PATH => "templates",
        #ENCODING => 'utf8' 
    });

	my $out;

	$tt->process(
        "reader.tmpl",
        {
        	arcname => $arcname,
            arcpages => $arcpages,
            pagenum => $pagenum,
            id => $id,
            filename => $filename,
            width => $imgwidth,
            height => $imgheight,
            size => $size,
            mapwidth => $imgmapwidth,
            imgpath => $imgpath,
            readorder => &get_readorder(),
            cssdrop => &printCssDropdown(0),
            userlogged => &isUserLogged($cgi),

        },
        \$out,
    ) or die $tt->error;

    print $out;

 }