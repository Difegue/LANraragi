package LANraragi::Controller::Api;
use Mojo::Base 'Mojolicious::Controller';

use Redis; 
use Encode;
use File::Find::utf8;
use File::Path qw(remove_tree);

use LANraragi::Model::Utils;
use LANraragi::Model::Config;
use LANraragi::Model::Plugins;

#use RenderFile to get the file of the provided id to the client.
sub serve_file {

	my $self = shift;
	my $id = $self->req->param('id');
	my $redis = $self->LRR_CONF->get_redis();

	my $file = $redis->hget($id,"file");
	$self->render_file(filepath => $file);
}

#Remove temp dir.
sub clean_tempfolder {

	my $self = shift;
	remove_tree('./public/temp', {error => \my $err}); 

	my $cleanmsg = "";
  	if (@$err) {
  		for my $diag (@$err) {
	      my ($file, $message) = %$diag;
	      if ($file eq '') {
	          $cleanmsg = "General error: $message\n";
	      }
	      else {
	          $cleanmsg = "Problem unlinking $file: $message\n";
	      }
  		}
  	}

  	my $size = 0;
	find(sub { $size += -s if -f }, "./public/temp");

  	$self->render(  json => {
					operation => "cleantemp", 
					success => $cleanmsg eq "",
					error => $cleanmsg,
					newsize => int($size/1048576*100)/100
				  });
}

sub serve_thumbnail {
	my $self = shift;

	my $id = $self->req->param('id');
	my $dirname = $self->LRR_CONF->get_userdir;

	#Thumbnails are stored in the content directory, thumb subfolder.
	my $thumbname = $dirname."/thumb/".$id.".jpg";
		
	unless (-e $thumbname) 
	{
		mkdir $dirname."/thumb";
		my $redis = $self->LRR_CONF->get_redis();
								
		my $file = $redis->hget($id,"file");
		$file = LANraragi::Model::Utils::redis_decode($file);
		
		my $path = "./public/temp/thumb";	
		#delete everything in thumb temp to prevent file mismatch errors.
		unlink glob $path."/*.*";

		#Get lsar's output, jam it in an array, and use it as @extracted.
		#print $file;
		my $vals = `lsar "$file"`; 
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
		my $shasum = LANraragi::Model::Utils::shasum($arcimg,1);
		$redis->hset($id,"thumbhash", encode_utf8($shasum));
		
		#Thumbnail generation
		LANraragi::Model::Utils::generate_thumbnail($arcimg,$thumbname);

		#Delete the previously extracted file.
		unlink $arcimg;
	}

	#Simply serve the thumbnail.
	$self->render_file(filepath => $thumbname);

}

sub force_refresh {

	my $self = shift;
 	LANraragi::Model::Utils::invalidate_cache();

 	$self->render(  json => {
					operation => "refresh_cache",
					status => 1,
					message => "JSON cache invalidated."
				  });
}

#Use all enabled plugins on an archive ID. Tags are automatically saved in the background.
#Returns number of successes and failures.
sub use_enabled_plugins {

	my $self = shift;

	my $id = $self->req->param('id');
	my $redis = $self->LRR_CONF->get_redis();

	if ($redis->hexists($id,"title") && LANraragi::Model::Config::enable_autotag) {

		my ($succ, $fail) = LANraragi::Model::Plugins::exec_enabled_plugins_on_file($id);

		$self->render(  json => {
						operation => "autotag",
						id => $id,
						success => 1,
						message => "$succ Plugins used successfully, $fail Plugins failed."
					  });
	} else {

		$self->render(  json => {
						operation => "autotag",
						id => $id,
						success => 0,
						message => "ID not found in database or AutoTagging disabled by admin."
					  });
	}
}

#Uses a plugin on the given archive with the given argument.
#Returns the fetched tags in a JSON response.
sub use_plugin {
	my $self = shift;

	my $id = $self->req->param('id');
	my $plugname = $self->req->param('plugin');
	my $oneshotarg = $self->req->param('arg');
	my $redis = $self->LRR_CONF->get_redis();

	#Go through plugins to find one with a matching namespace
	my @plugins = LANraragi::Model::Plugins::plugins;

	foreach my $plugin (@plugins) {

	    my %pluginfo = $plugin->plugin_info();
	    my $namespace = $pluginfo{namespace};

	    if ($plugname eq $namespace) {

	    	#Get the matching argument in Redis
	    	my $namerds = "LRR_PLUGIN_".uc($namespace);
	    	my $globalarg = $redis->hget($namerds,"customarg");
	    	$globalarg = LANraragi::Model::Utils::redis_decode($globalarg);

	    	#Finally, execute the plugin 
	    	my %plugin_result = LANraragi::Model::Plugins::exec_plugin_on_file($plugin, $id, $globalarg, $oneshotarg);

	    	if (exists $plugin_result{error}) {

	    		$self->render(  json => {
								operation => "fetch_tags",
								success => 0,
								message => $plugin_result{error}
							  });
	    	}
	    	else {

	    		$self->render(  json => {
								operation => "fetch_tags",
								success => 1,
								tags => $plugin_result{new_tags}
							  });
	    	}
	    	
	    	return;
	    }
	}

	$self->render(  json => {
					operation => "fetch_tags",
					success => 0,
					message => "Plugin not found on system."
				  });

}

1;
