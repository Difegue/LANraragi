package LANraragi::Controller::Tags;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Encode;

use LANraragi::Model::Utils;
use LANraragi::Model::Config;
use LANraragi::Model::Plugins;

# This action will render a template
sub index {

	my $self = shift;
	my $redis = $self->LRR_CONF->get_redis;

	#Build archive list for batch taggins
	#Fill the list with archives by looking up in redis
	my @keys = $redis->keys( '????????????????????????????????????????????????????????????????' ); #64-character long keys only => Archive IDs 
	my $arclist = "";

	#Parse the archive list and add <li> elements accordingly.
	foreach my $id (@keys)
	{

		if ($redis->hexists($id,"title")) 
			{
				my $file = $redis->hget($id,"file");
				$file = LANraragi::Model::Utils::redis_decode($file);

				if (-e $file) {

					my $title = $redis->hget($id,"title");
					$title = LANraragi::Model::Utils::redis_decode($title);
					
					#If the archive has no tags, pre-check it in the list.
					#TODO - Awfully outdated -- Check if the archive is already in the tagging queue instead (which we need to enumerate too...)
					#Might be good to hide/disable altogether archives already queued for metadata collection.
					if ($redis->hget($id,"tags") eq "")
						{ $arclist .= "<li><input type='checkbox' name='archive' id='$id' checked><label for='$id'> $title</label></li>"; }
					else
						{ $arclist .= "<li><input type='checkbox' name='archive' id='$id' ><label for='$id'> $title</label></li>"; }
				}
			}
	}

	$redis->quit();

	$self->render(template => "tags",
		            title => $self->LRR_CONF->get_htmltitle,
		            arclist => $arclist,
		            cssdrop => LANraragi::Model::Utils::generate_themes
		            );
}

1;