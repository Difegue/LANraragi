package LANraragi::Controller::Upload;
use Mojo::Base 'Mojolicious::Controller';

use Redis;

use LANraragi::Model::Utils;
use LANraragi::Model::Config;


sub process_upload {
	my $self = shift;

	#Receive uploaded file.
	my $file = $self->req->upload('file');

	my $uploadMime = $file->headers->content_type;

	my @mimeTypes = ("application/zip","application/x-zip-compressed","application/x-rar-compressed","application/x-7z-compressed","application/x-tar","application/x-gtar","application/x-lzma","application/x-xz");
	my %acceptedTypes = map { $_ => 1 } @mimeTypes;

	#Check if the uploaded file's mimetype matches one we accept
	if(exists($acceptedTypes{$uploadMime})) {
		
		my $filename = $file->filename;

		my $output_file = $self->LRR_CONF->get_userdir.'/'.$filename; #open up a file on our side
				
		if (-e $output_file) { 
			#if it doesn't already exist, that is.
			$self->render(  json => {
							operation => "upload", 
							name => $file->filename,
							type => $uploadMime,
							success => 0,
							error => "A file bearing this name already exists in the Library."
						  });
		}
		else {
				open (OUTFILE, ">", "$output_file") 
					or die "Couldn't open $output_file for writing: $!";

				my $bytes = $file->slurp; 
				print OUTFILE $bytes; #Write the uploaded contents to that file.

				close OUTFILE;

				#Parse for metadata right now and get the database ID
				my $redis = $self->LRR_CONF->get_redis();

				my $id = LANraragi::Model::Utils::compute_id($output_file);

				LANraragi::Model::Utils::add_archive_to_redis($id,$output_file,$redis);

				$self->render(  json => {
								operation => "upload", 
								name => $file->filename,
								type => $uploadMime,
								success => 1,
								id => $id
							});			
		}
	}
	else {

		$self->render(  json => {
							operation => "upload", 
							name => $file->filename,
							type => $uploadMime,
							success => 0,
							error => "Unsupported Filetype. (".$uploadMime.")"
						  });
	}	
}

sub index {

	my $self = shift;

	$self->render(  template => "upload",
	            	title => $self->LRR_CONF->get_htmltitle,
	            	autotag => $self->LRR_CONF->enable_autotag,
	            	cssdrop => LANraragi::Model::Utils::generate_themes
	            	);
}

1;
