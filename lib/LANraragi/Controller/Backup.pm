package LANraragi::Controller::Backup;
use Mojo::Base 'Mojolicious::Controller';

use LANraragi::Model::Utils;
use LANraragi::Model::Config;
use LANraragi::Model::Backup;

# This action will render a template
sub index {
  	my $self = shift;

  	#GET with a parameter => do backup
  	if ($self->req->param('dobackup'))
	{
		my $json = &build_backup_JSON();

		#Write json to file in the ugc directory and serve that file through render_static
		my $file = &get_userdir.'backup.json';

		if (-e $file) 
			{ unlink $file }

		my $OUTFILE;

		open $OUTFILE, '>>', $file;
		print { $OUTFILE } $json;
		close $OUTFILE;

		$self->reply->static($file);

	}
	else 
	{   #Get with no parameters => Regular HTML printout
		$self->render(  template => "templates/backup.tmpl",
		            	title => &get_htmltitle,
		            	cssdrop => &generate_themes(0)
		            	);
	}
}

sub restore {
	my $self = shift;
	my $file = $self->req->upload('file');

	if ($file->headers->content_type eq "application/json") 
	{
		my $json = $file->slurp;
		&restore_from_JSON($json);

		$self->render(  json => {
						operation => "restore_backup", 
						success => 1
					  });
	}
	else
	{
		$self->render(  json => {
						operation => "restore_backup", 
						success => 0,
						error => "Not a JSON file."
					  });
	}
}




1;
