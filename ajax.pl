#!/usr/bin/perl

#ajax calls possible:
#?function=thumbnail&id=xxxxxx
#?function=tags&ishash=0/1&input=xxxxxx

use strict;
use CGI qw(:standard);

require 'config.pl';
require 'functions/functions_tags.pl';
require 'functions/functions_login.pl';

#set up cgi for receiving ajax calls
my $qajax = new CGI;
print $qajax->header('text/plain');

#Is this a call? 
if ($qajax->param() && &isUserLogged($qajax))
{

	my $call = $qajax->param('function');

	if ($call eq "thumbnail")
		{
			my $id = $qajax->param('id');
			&getThumb($id);
		}

	if ($call eq "password")
		{
			my $pass = $qajax->param('pass');

			if (($pass eq &get_password) || (&enable_pass == 0))  
				{
					print "1";
				}
				else
					{
						print "0";
					}

		}

	if ($call eq "tags")
		{
			my $ishash = $qajax->param('ishash');
			my $input = $qajax->param('input');
			my $pass = $qajax->param('pass');
			my $queryJson;


			#This rings up g.e-hentai with the input we obtained.
			$queryJson = &getGalleryId($input,$ishash); #getGalleryId is in functions.pl.

			#Call the actual e-hentai API with the json we created and grab dem tags
			my $tags = &getTagsFromAPI($queryJson);

			unless ($tags eq(""))
				{
					print $tags;
				}	
			else
				{
					print "NOTAGS";
				}
		}

}
else
{
	print "Session expired, please login again."
}


#returns the thumbnail path for a filename. Creates the thumbnail if it doesn't exist.
sub getThumb
{
	my $dirname = &get_dirname;
	my $id = $_[0];

	my $thumbname = $dirname."/thumb/".$id.".jpg";
	#let's create it!
		
	if (-e $thumbname)
	{
		print $thumbname;
	}
	else
	{
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
		#print("ZIPFILE-----"+$file+"bb--------");	
		`unar -D -o $path "$file" "$unarfix"`;
			
		my $path2 = $path.'/'.@extracted[0];
					
		#While we have the image, grab its SHA-1 hash for potential tag research later. 
		#That way, no need to repeat the costly extraction later.
			
		$redis->hset($id,"thumbhash", encode_utf8(shasum($path2)));
			
		#use ImageMagick to make the thumbnail. I tried using PerlMagick but it's a piece of ass, can't get it to build :s
		`convert -strip -thumbnail 200x "$path2" $thumbname`;
					
		print $thumbname;

		$redis.close();
		#Delete the previously extracted file.
		unlink $path2;
	}
}
	
