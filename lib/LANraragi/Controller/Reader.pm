package LANraragi::Controller::Reader;
use Mojo::Base 'Mojolicious::Controller';

use LANraragi::Model::Utils;
use LANraragi::Model::Config;
use LANraragi::Model::Reader;

# This action will render a template
sub render {
	my $self = shift;

	if ($self->param()) 
		{
		    # We got a file name, let's get crackin'.
			my $id = $self->param('id');

			#Quick Redis check to see if the ID exists:
			my $redis = &getRedisConnection();

			unless ($redis->hexists($id,"title"))
				{ $self->redirect('index'); }

			#Get a computed archive name if the archive exists
			my $artist = $redis->hget($id,"artist");
			my $arcname = $redis->hget($id,"title");

			unless ($artist =~ /^\s*$/)
				{$arcname = $arcname." by ".$artist; }
				
			$arcname = decode_utf8($arcname);
		
			my $force = $self->param('force_reload');
			my $thumbreload = $self->param('reload_thumbnail');
			my $imgpaths = "";

			#Load a json matching pages to paths
			$imgpaths = &buildReaderData($id,$force,$thumbreload);

			my $userlogged = 0;

			if ($self->session('is_logged')) 
				{ $userlogged = 1;}

			$self->render(template => "templates/reader.tmpl",
	  				      	arcname => $arcname,
				            id => $id,
				            imgpaths => $imgpaths,
				            readorder => &get_readorder(),
				            cssdrop => &printCssDropdown(0),
				            userlogged => &userlogged
			  	            );
		} 
		else 
		{
		    # No parameters back the fuck off
			$self->redirect('index');
		}
}

1;
