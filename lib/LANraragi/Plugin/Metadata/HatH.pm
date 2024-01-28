package LANraragi::Plugin::Metadata::hentaiathome;

use strict;
use warnings;

#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.


#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::Archive qw(is_file_in_archive extract_file_from_archive);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name            => "HentaiAtHome plugin",
        type             => "metadata",
        namespace    => "hentaiathome",
        author          => "lily",
        version         => "0.1",
        description    => "Collects metadata embedded into your archives by HentaiAtHome Downloader's galleryinfo txt files.",
        icon =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAABmJLR0QA/wD/AP+gvaeTAAAACXBI\nWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH4wYDFB0m9797jwAAAB1pVFh0Q29tbWVudAAAAAAAQ3Jl\nYXRlZCB3aXRoIEdJTVBkLmUHAAAEbklEQVQ4y1WUPW/TUBSGn3uvHdv5cBqSOrQJgQ4ghqhCAgQM\nIIRAjF2Y2JhA/Q0g8R9YmJAqNoZKTAwMSAwdQEQUypeQEBEkTdtUbdzYiW1sM1RY4m5Hunp1znmf\n94jnz5+nAGmakiQJu7u7KKWwbRspJWma0m63+fHjB9PpFM/z6Ha7FAoFDMNga2uLx48fkyQJ29vb\nyCRJSNMUz/PY2dnBtm0qlQpKKZIkIQgCer0eW1tbDIdDJpMJc3NzuK5Lt9tF13WWl5dJkoRyuYyU\nUrK3t0ccx9TrdQzD4F/HSilM08Q0TWzbplqtUqvVKBaLKKVoNpt8/vyZKIq4fv064/EY2ev1KBQK\n2LadCQkhEEJkteu6+L6P7/tMJhOm0ylKKarVKjdu3GA6nXL+/HmSJEHWajV0Xf9P7N8TQhDHMWEY\nIoRgOBzieR4At2/f5uTJk0RRRLFYZHZ2liNHjqBFUcRoNKJarSKlRAiRmfPr1y/SNMVxHI4dO8aF\nCxfI5/O4rotSirdv33L16lV+//7Nly9fUEqh5XI5dF0nTdPMaSEEtm3TaDSwLAvLstB1nd3dXUql\nEqZpYlkW6+vrdLtdHjx4wPb2NmEYHgpalkUQBBwcHLC2tsbx48cpFos4jkMQBIRhyGQyYTgcsrGx\nQavVot1uc+LECcbjMcPhkFKpRC6XQ0vTlDAMieOYQqGA4zhcu3YNwzDQdR3DMA4/ahpCCPL5fEbC\nvXv3WFlZ4c+fP7TbbZaWlpBRFGXjpmnK/Pw8QRAwnU6RUqJpGp7nMRqNcF0XwzCQUqKUolwus7y8\njO/7lMtlFhcX0YQQeJ6XMXfq1Cn29/epVCrouk4QBNi2TalUIoqizLg0TQEYjUbU63VmZmYOsdE0\nDd/3s5HH4zG6rtNsNrEsi0qlQqFQYH19nVevXjEej/8Tm0wmlMtlhBAMBgOkaZo0Gg329vbY2dkh\nCIJsZ0oplFK8efOGp0+fcvHiRfL5PAAHBweEYcj8/HxGydevX5FxHDMajajVanz69Ik4jkmSBF3X\n0TSNzc1N7t69S6vV4vXr10gp8X2f4XBIpVLJghDHMRsbG2jT6TRLxuLiIr1eDwBN09A0jYcPHyKE\n4OjRo8RxTBRF9Pt95ubmMud93+f79+80m03k/v4+UspDKDWNRqPBu3fvSNOUtbU16vU6ly5dwnEc\ncrkcrutimib5fD4zxzRNVldXWVpaQqysrKSdTofLly8zmUwoFAoIIfjXuW3bnD17NkuJlBLHcdA0\nDYAgCHj27BmO47C6uopM05RyucyLFy/QNA3XdRFCYBgGQRCwubnJhw8fGAwGANRqNTRNI0kSXr58\nyc2bN6nX64RhyP379xFPnjxJlVJIKTl37hydTocoiuh0OszOzmJZFv1+n8FgwJ07d7hy5Qrj8ZiP\nHz/S7/c5ffo0CwsL9Ho9ZmZmEI8ePUoNwyBJEs6cOcPCwgLfvn3j/fv35PN5bNtGKZUdjp8/f3Lr\n1q3svLVaLTzPI4oiLMviL7opJdyaltNwAAAAAElFTkSuQmCC",
        parameters => []
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;    # Global info hash

    my $logger = get_plugin_logger();
    my $file   = $lrr_info->{file_path};

    my $path_in_archive = is_file_in_archive( $file, "galleryinfo.txt" );
    if ($path_in_archive) {

        # Extract galleryinfo.txt
        my $filepath = extract_file_from_archive( $file, $path_in_archive );

        # Open it
        open( my $fh, '<:encoding(UTF-8)', $filepath )
            or return ( error => "Could not open $filepath!" );
			
			my $tag = "";
			my $title = "";
            while ( my $line = <$fh> ) {
				# Check if the line starts with Title:
				if ( $line =~ m/Title: (.*)/ ) {
					$title = $1;
				}
				# Check if the line starts with Uploaded By: 
				if ( $line =~ m/Uploaded By: (.*)/ ) {
					$tag .= "uploader:$1, ";
				}
				# Check if the line starts with Upload Time: 
				if ( $line =~ m/Upload Time: (.*)/ ) {
					$tag .= "Upload Time:$1, ";
				}
                # Check if the line starts with TAGS:
                if ( $line =~ m/Tags: (.*)/ ) {
					$tag .= $1;
                    return ( tags => $tag , title => $title );
                }
            }
		return ( error => "No tags were found in galleryinfo.txt!" );
    } else {
        return ( error => "No galleryinfo.txt file found in this archive!" );
    }
}

1;
