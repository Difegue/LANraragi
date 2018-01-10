package LANraragi::Controller::Example;
use Mojo::Base 'Mojolicious::Controller';

use utf8;
use URI::Escape;
use Redis;
use Encode;
use File::Path qw(make_path remove_tree);
use File::Basename;

use LANraragi::Controller::Config;
use LANraragi::Model::Index;

sub random_archive
{
	my $archive="";
	my $archiveexists = 0;

	my $redis = &getRedisConnection();

	#We get a random archive ID. We check for the length to (sort-of) avoid not getting an archive ID.
	#Shit's never been designed to work on a redis database where other keys would be lying around. 
	until ($archiveexists)
	{
		$archive = $redis->randomkey();

		#We got a key, but does the matching archive still exist on the server? Better check it out.
		#This usecase only happens with the random selection : Regular index only parses the database for archive files it finds by default.
		if (length($archive)==64 && $redis->type($archive) eq "hash" && $redis->hexists($archive,"file"))
		{
			my $arclocation = $redis->hget($archive,"file");
			$arclocation = decode_utf8($arclocation);

			if (-e $arclocation)
				{ $archiveexists = 1; }
		}
	}
		
	my $self = shift;

	#We redirect to the reader, with the key as parameter.
	$self->redirect_to('reader', id => $archive);

}

# Go through the archives in the content directory and build the template at the end.
sub render {
  	my $self = shift;

  	my $version = $self->plugin('Config')>{version};
  	my $dirname = &get_dirname;

	#Get all files in content directory and subdirectories.
	#This should be enough supported file extensions, right? The old lsar method was hacky and took too long.
	my @filez;
	find({ wanted => sub { 
							if ($_ =~ /^*.+\.(zip|rar|7z|tar|tar.gz|lzma|xz|cbz|cbr)$/ )
								{push @filez, $_ }
						 },
		   no_chdir => 1,
		   follow_fast => 1 }, 
		$dirname);
			  
	remove_tree('./temp'); #Remove temp dir.

	my $archivejson;
	my $newarchivejson;

	#From the file tree, generate the archive JSONs
	if (@filez)
	{ 
		($archivejson, $newarchivejson) = &generateTableJSON(@filez, &getRedisConnection); 
	}
	else
	{ 
		$archivejson = "[]";
		$newarchivejson = "[]";
	}

	#Checking if the user still has the default password enabled
	my $ppr = Authen::Passphrase->from_rfc2307(&get_password);
	my $passcheck = ($ppr->match("kamimamita") && &enable_pass);

	$self->render(template => "templates/index.tmpl",
		            title => &get_htmltitle,
		            pagesize => &get_pagesize,
		            userlogged => &isUserLogged($cgi),
		            motd => &get_motd,
		            cssdrop => &printCssDropdown(1),
		            archiveJSON => $archivejson,
		            newarchiveJSON => $newarchivejson,
		            nonewarchives => ($newarchivejson eq "[]"),
		            usingdefpass => $passcheck,
		            version => $version
		        );
}

1;
