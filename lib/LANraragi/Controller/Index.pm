package LANraragi::Controller::Index;
use Mojo::Base 'Mojolicious::Controller';

use utf8;
use URI::Escape;
use Redis;
use Encode;
use File::Path qw(make_path remove_tree);
use File::Basename;
use File::Find;
use Authen::Passphrase;

use LANraragi::Model::Utils;
use LANraragi::Model::Config;
use LANraragi::Model::Index;

sub random_archive
{
	my $archive="";
	my $archiveexists = 0;

	my $redis = LANraragi::Model::Config->getRedisConnection();

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
sub index {

	my $self = shift;

  	my $version = $self->config->{version};
  	my $dirname = LANraragi::Model::Config->get_userdir;

	#Get all files in content directory and subdirectories.
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
		my $redis = LANraragi::Model::Config->getRedisConnection;
		($archivejson, $newarchivejson) = &generateTableJSON(@filez, $redis); 
	}
	else
	{ 
		$archivejson = "[]";
		$newarchivejson = "[]";
	}

	#Checking if the user still has the default password enabled
	my $ppr = Authen::Passphrase->from_rfc2307(LANraragi::Model::Config->get_password);
	my $passcheck = ($ppr->match("kamimamita") && LANraragi::Model::Config->enable_pass);

	$self->render(template => "index",
		            title => LANraragi::Model::Config->get_htmltitle,
		            pagesize => LANraragi::Model::Config->get_pagesize,
		            userlogged => $self->session('is_logged'),
		            motd => LANraragi::Model::Config->get_motd,
		            cssdrop => LANraragi::Model::Utils->printCssDropdown(1),
		            archiveJSON => $archivejson,
		            newarchiveJSON => $newarchivejson,
		            nonewarchives => ($newarchivejson eq "[]"),
		            usingdefpass => $passcheck,
		            version => $version
		        );
}

1;
