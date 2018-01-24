package LANraragi::Controller::Index;
use Mojo::Base 'Mojolicious::Controller';

use utf8;
use URI::Escape;
use Redis;
use Encode;
use File::Basename;
use File::Find;
use Authen::Passphrase;

use LANraragi::Model::Utils;
use LANraragi::Model::Config;
use LANraragi::Model::Index;

#sub LRR_CONF { LANraragi::Model::Config:: }

sub random_archive
{
	my $self = shift;
	my $archive="";
	my $archiveexists = 0;

	my $redis = $self->LRR_CONF->get_redis();

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

	#We redirect to the reader, with the key as parameter.
	$self->redirect_to('/reader?id='.$archive);

}

# Go through the archives in the content directory and build the template at the end.
sub index {

	my $self = shift;

  	my $version = $self->config->{version};
  	my $dirname = $self->LRR_CONF->get_userdir;

	#Get all files in content directory and subdirectories.
	my @filez;
	find({ wanted => sub { 
							if ($_ =~ /^*.+\.(zip|rar|7z|tar|tar.gz|lzma|xz|cbz|cbr)$/ )
								{push @filez, $_ }
						 },
		   no_chdir => 1,
		   follow_fast => 1 }, 
		$dirname);

	my $archivejson;
	my $newarchivejson;

	#From the file tree, generate the archive JSONs
	if (@filez)
	{ 
		my $redis = $self->LRR_CONF->get_redis;
		($archivejson, $newarchivejson) = LANraragi::Model::Index::build_table_JSON(@filez); 
	}
	else
	{ 
		$archivejson = "[]";
		$newarchivejson = "[]";
	}

	#Checking if the user still has the default password enabled
	my $ppr = Authen::Passphrase->from_rfc2307($self->LRR_CONF->get_password);
	my $passcheck = ($ppr->match("kamimamita") && $self->LRR_CONF->enable_pass);

	$self->render(template => "index",
		            title => $self->LRR_CONF->get_htmltitle,
		            pagesize => $self->LRR_CONF->get_pagesize,
		            userlogged => $self->session('is_logged'),
		            motd => $self->LRR_CONF->get_motd,
		            cssdrop => LANraragi::Model::Utils::generate_themes(1),
		            archiveJSON => $archivejson,
		            newarchiveJSON => $newarchivejson,
		            nonewarchives => ($newarchivejson eq "[]"),
		            usingdefpass => $passcheck,
		            version => $version
		        );
}

1;
