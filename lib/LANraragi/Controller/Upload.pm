package LANraragi::Controller::Upload;
use Mojo::Base 'Mojolicious::Controller';

use Encode;
use Redis;

use LANraragi::Model::Utils;
use LANraragi::Model::Config;


sub process_upload {
	my $self = shift;

	#Receive uploaded file.
	my $filename = $self->param('file');

	my $uploadMime = $filename->headers->content_type;

	my @mimeTypes = ("application/zip","application/x-zip-compressed","application/x-rar-compressed","application/x-7z-compressed","application/x-tar","application/x-gtar","application/x-lzma","application/x-xz");
	my %acceptedTypes = map { $_ => 1 } @mimeTypes;

	#Check if the uploaded file's mimetype matches one we accept
	if(exists($acceptedTypes{$uploadMime})) {
		
		my $output_file = &get_userdir.'/'.decode_utf8($filename); #open up a file on our side
				
		if (-e $output_file) { 
			#if it doesn't already exist, that is.
			$self->render(  json => {
							operation => "upload", 
							name => $filename,
							type => $uploadMime,
							success => 0,
							error => "A file bearing this name already exists in the Library."
						  });
		}
		else {
				my ($bytesread, $buffer);
				my $numbytes = 1024;

				open (OUTFILE, ">", "$output_file") 
					or die "Couldn't open $output_file for writing: $!";

				while ($bytesread = read($filename, $buffer, $numbytes)) 
					{ print OUTFILE $buffer; } #Write the uploaded contents to that file.

				close OUTFILE;

				#Parse for metadata right now and get the database ID
				my $redis = &getRedisConnection();

				my $id = sha256_hex(encode_utf8($output_file));

				&addArchiveToRedis($id,$output_file,$redis);

				$self->render(  json => {
								operation => "upload", 
								name => $filename,
								type => $uploadMime,
								success => 1,
								id => $id
							});			
		}
	}
	else {

		$self->render(  json => {
							operation => "upload", 
							name => $filename,
							type => $uploadMime,
							success => 0,
							error => "Unsupported Filetype. (".$uploadMime.")"
						  });
	}	
}

sub index {

	my $self = shift;

	$self->render(  template => "templates/upload.tmpl",
	            	title => &get_htmltitle,
	            	cssdrop => &printCssDropdown(0)
	            	);
}

1;
