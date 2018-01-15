package LANraragi::Model::Reader;

use strict;
use warnings;
use utf8;

use Redis;
use IPC::Cmd qw[can_run run];
use File::Basename;
use File::Path qw(remove_tree);
use Encode;
use File::Find qw(find);
use HTML::Entities;

use LANraragi::Model::Config;

#reader_error_HTML($filename,$log)
sub reader_error_HTML {

	my $filename = $_[0];
	my $errorlog = $_[1];
	
	print " <body style='background: none repeat scroll 0% 0% brown; color: white; font-family: sans-serif; text-align: center'>
				<img src='./img/flubbed.gif'/><br/>
				<h2>I flubbed it while trying to open the archive ".$filename.".</h2>It's likely the archive contains a folder with unicode characters.<br/> 
				No real way around that for now besides modifying your archive, sorry !<br/>";


	print "<h3>Some more info below :</h3> <br/>";
	print decode_utf8($errorlog);

	print "</body>";

 }

#magical sort function used below
sub expand {
    my $file=shift; 
    $file=~s{(\d+)}{sprintf "%04d", $1}eg;
    return $file;
}

#build_reader_JSON(id,forceReload,refreshThumbnail)
#Opens the archive specified by its ID and returns a json matching pages to their 
sub build_reader_JSON {

	my ($id, $force, $thumbreload) = @_;
	my $tempdir = "./public/temp";

	#Redis stuff: Grab archive path and update some things
	my $redis = LANraragi::Model::Config::get_redis();
	
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
				&reader_error_HTML($filename,$errlog);
				exit;
			}
		}
		
	#Find the extracted images with a full search (subdirectories included), treat them and jam them into an array.
	my @images;
	find({ wanted => sub { 
							if ($_ =~ /^*.+\.(png|jpg|gif|bmp|jpeg|PNG|JPG|GIF|BMP)$/ ) #is it an image? readdir tends to read folder names too...
								{
									#We need to sanitize the image's path, in case the folder contains illegal characters, but uri_escape would also nuke the / needed for navigation.
									#Let's solve this with a quick regex search&replace.
									#First, we encode all HTML characters...
									my $imgpath = $_;
									$imgpath = encode_entities($imgpath);
									
									#Then we bring the slashes back.
									$imgpath =~ s!%2F!/!g;

									#We also now need to strip the /public/ part, as it's not visible by clients.
									$imgpath =~ s!public/!!g;
									push @images, $imgpath;

								}
						} , no_chdir => 1 }, $path); #find () does exactly that. 
			  
    @images = sort { &expand($a) cmp &expand($b) } @images;
	
	#Convert page 1 into a thumbnail for the main reader index if it's not been done already(Or if it fucked up for some reason).
	my $thumbname = "./public/thumb/".$id.".jpg";

	unless (-e $thumbname && $thumbreload eq "0")
	{
		my $path = $images[0];
		my $shasum = LANraragi::Model::Utils::shasum($path);
		$redis->hset($id,"thumbhash", encode_utf8($shasum));

		LANraragi::Model::Utils::generate_thumbnail($path,$thumbname);
	}

	#Build json (it's just the images array in a string)
	my $list = "{\"pages\": [\"".join("\",\"",@images)."\"]}";
	return $list;

}

 1;