package LANraragi::Controller::Api;
use Mojo::Base 'Mojolicious::Controller';

use CGI qw(:standard);
use Redis; 
use Encode;

use LANraragi::Model::Utils;
use LANraragi::Model::Config;
#use LANraragi::Model::Tagging;

sub generate_thumbnail {
	my $self = shift;

	my $id = $self->req->param('id');
	my $dirname = $self->LRR_CONF->get_userdir;

	#This thumbnail name is given to the client at the end, so we omit the /public/ directory.
	my $thumbname = "./thumb/".$id.".jpg";
		
	unless (-e "./public/".$thumbname) #But we have to re-add it here since we're doing server-side IO
	{
		my $redis = $self->LRR_CONF->get_redis();
								
		my $file = $redis->hget($id,"file");
		$file = decode_utf8($file);
		
		my $path = "./public/temp/thumb";	
		#delete everything in thumb temp to prevent file mismatch errors.
		unlink glob $path."/*.*";

		#Get lsar's output, jam it in an array, and use it as @extracted.
		my $vals = `lsar "$file"`; 
		#print $vals;
		my @lsarout = split /\n/, $vals;
		my @extracted; 
					
		#The -i 0 option on unar doesn't always return the first image, so we gotta rely on lsar.
		#Sort on the lsar output to find the first image.					
		foreach $_ (@lsarout) 
			{
			if ($_ =~ /^(.*\/)*.+\.(png|jpg|gif|bmp|jpeg|PNG|JPG|GIF|BMP)$/ ) #is it an image? lsar can give us folder names.
				{push @extracted, $_ }
			}
						
		@extracted = sort { lc($a) cmp lc($b) } @extracted;
					
		#unar sometimes crashes on certain folder names inside archives. To solve that, we replace folder names with the wildcard * through regex.
		my $unarfix = $extracted[0];
		$unarfix =~ s/[^\/]+\//*\//g;
					
		#let's extract now.
		#print("ZIPFILE-----"+$file+"bb--------");	
		`unar -D -o $path "$file" "$unarfix"`;
		
		#Path to the first image of the archive
		my $arcimg = $path.'/'.$extracted[0];
					
		#While we have the image, grab its SHA-1 hash for potential tag research later. 
		#That way, no need to repeat the costly extraction later.
		my $shasum = LANraragi::Model::Utils::shasum($path2);
		$redis->hset($id,"thumbhash", encode_utf8($shasum));
		
		#Thumbnail generation
		LANraragi::Model::Utils::generate_thumbnail($arcimg,"./public/".$thumbname);
			
		$redis.close();

		#Delete the previously extracted file.
		unlink $arcimg;
	}

	$self->render(  json => {
					id => $id,
					operation => "thumbnail", 
					thumbnail => $thumbname
				  });

}

#TODO - Fix clientside js to use new json syntax
sub add_archive {
	my $self = shift;

	my $id = $self->req->param('id');
	my $file = $self->req->param('arc_path');
 	my $redis = $self->LRR_CONF->get_redis();

 	if ($redis->hexists($id,"title"))
 	{ 
		$self->render(  json => {
						operation => "add_archive",
						status => 0, 
						error => "ID already exists."
					  });
	}

	my $userdir = $self->LRR_CONF->get_userdir;

 	#check if the file is in the content directory first
 	if (index($file,$userdir) == 0)
 	{ 
 		#utf8 decode the filename
 		eval { $file = decode_utf8($file) };

 		#Archive adding is in the Utils package
 		LANraragi::Model::Utils::add_archive_to_redis($id,$file,$redis);

 		$self->render(  json => {
 						operation => "add_archive",
						status => 1
					  });
 	}
 	else
 	{
 		$self->render(  json => {
 						operation => "add_archive",
						status => 0,
						error => "File $file not in the configured content directory $userdir."
					  });
 	}

}

#TODO - Fix clientside js to use new json syntax instead of plaintext
sub fetch_tags {
	my $self = shift;

	my $id = $self->req->param('id');
	my $method = $self->req->param('method');
	my $urlOverride = $self->req->param('url');
	my $blacklist = $self->LRR_CONF->get_tagblacklist;

	my $tags = &getTags($id,$method,$blacklist, $urlOverride);

	#with or without instasave
	if ($self->req->param('instasave'))
		{ &addTags($id,$tags); }

	$self->render(  json => {
					operation => "fetch_tags",
					status => 1,
					tags => $tags
				  });

}

#Get tags for the given input(title or image hash) and method(0 = title, 1= hash, 2=nhentai)
#TODO - Replace by plugin system
sub getTags {
	my $id = $_[0];
	my $method = $_[1];
	my $bliststr = $_[2];
	my $url = $_[3];
	my $tags = "";
	
	my $queryJson;

	if ($method eq "2") #nhentai usecase
	{ 
		if ($url eq "") 
		{ $tags = &nHentaiGetTags($id); }
		else
		{
		  if ($url =~ /.*\/g\/([0-9]*)\/.*/ ) { #Quick regex to get the nhentai id from the url
		  	$tags = &getTagsFromNHAPI($1); 
		  }
		}
		
	}
	else #g.e-hentai usecase
	{
		eval { 
				if ($url eq "") 
				{ $queryJson = &eHentaiGetTags($id,$method); }
				else 
				{ #Quick regex to get the E-H archive ids from the provided url.
					if ($url =~ /.*\/g\/([0-9]*)\/([0-z]*)\/*.*/ ) { 
						$queryJson = qq({"method": "gdata","gidlist": [[$1,"$2"]]});
					}
				}

				#Call the actual e-hentai API with the json we created and grab dem tags
				$tags = &getTagsFromEHAPI($queryJson);
			 }; 

		#If the archive didn't have a thumbnail hash, we return an error code.
		return "NOTHUMBNAIL" if $@; 
		
	}

	#We got the tags, let's strip out the ones in the blacklist.
	my @blacklist = split(/,\s?/, $bliststr);

	foreach my $tag (@blacklist) 
		{ $tags =~ s/\Q$tag\E,//ig; } #Remove all occurences of $tag in $tags
	
	unless ($tags eq("") || $tags eq(" "))
		{ return $tags; }	
	else
		{ return "NOTAGS"; }
	
}

1;
