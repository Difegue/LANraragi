package LANraragi::Controller::Backup;
use Mojo::Base 'Mojolicious::Controller';

use LANraragi::Model::Utils;
use LANraragi::Model::Config;
use LANraragi::Model::Backup;

# This action will render a template
sub index {
  	my $self = shift;

  	#GET with a parameter => do backup
  	if ($self->param('dobackup'))
	{
		my $json = &buildBackupJSON();

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
		            	cssdrop => &printCssDropdown(0)
		            	);
	}
}

sub restore {
	my $self = shift;
	my $file = $self->param('file');

	if ($file->headers->content_type eq "application/json") 
	{
		my $json = $file->slurp;
		&restoreFromJSON($json);

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
