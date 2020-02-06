package LANraragi::Plugin::Metadata::Hdoujin;

use strict;
use warnings;

#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use Mojo::JSON qw(from_json);

#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "Hdoujin",
        type        => "metadata",
        namespace   => "Hdoujinplugin",
        author      => "Pao",
        version     => "0.4",
        description => "Collects metadata embedded into your archives by HDoujin Downloader's json or txt files.",
        icon        => "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAABmJLR0QA/wD/AP+gvaeTAAAACXBI\nWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH4wYDFB0m9797jwAAAB1pVFh0Q29tbWVudAAAAAAAQ3Jl\nYXRlZCB3aXRoIEdJTVBkLmUHAAAEbklEQVQ4y1WUPW/TUBSGn3uvHdv5cBqSOrQJgQ4ghqhCAgQM\nIIRAjF2Y2JhA/Q0g8R9YmJAqNoZKTAwMSAwdQEQUypeQEBEkTdtUbdzYiW1sM1RY4m5Hunp1znmf\n94jnz5+nAGmakiQJu7u7KKWwbRspJWma0m63+fHjB9PpFM/z6Ha7FAoFDMNga2uLx48fkyQJ29vb\nyCRJSNMUz/PY2dnBtm0qlQpKKZIkIQgCer0eW1tbDIdDJpMJc3NzuK5Lt9tF13WWl5dJkoRyuYyU\nUrK3t0ccx9TrdQzD4F/HSilM08Q0TWzbplqtUqvVKBaLKKVoNpt8/vyZKIq4fv064/EY2ev1KBQK\n2LadCQkhEEJkteu6+L6P7/tMJhOm0ylKKarVKjdu3GA6nXL+/HmSJEHWajV0Xf9P7N8TQhDHMWEY\nIoRgOBzieR4At2/f5uTJk0RRRLFYZHZ2liNHjqBFUcRoNKJarSKlRAiRmfPr1y/SNMVxHI4dO8aF\nCxfI5/O4rotSirdv33L16lV+//7Nly9fUEqh5XI5dF0nTdPMaSEEtm3TaDSwLAvLstB1nd3dXUql\nEqZpYlkW6+vrdLtdHjx4wPb2NmEYHgpalkUQBBwcHLC2tsbx48cpFos4jkMQBIRhyGQyYTgcsrGx\nQavVot1uc+LECcbjMcPhkFKpRC6XQ0vTlDAMieOYQqGA4zhcu3YNwzDQdR3DMA4/ahpCCPL5fEbC\nvXv3WFlZ4c+fP7TbbZaWlpBRFGXjpmnK/Pw8QRAwnU6RUqJpGp7nMRqNcF0XwzCQUqKUolwus7y8\njO/7lMtlFhcX0YQQeJ6XMXfq1Cn29/epVCrouk4QBNi2TalUIoqizLg0TQEYjUbU63VmZmYOsdE0\nDd/3s5HH4zG6rtNsNrEsi0qlQqFQYH19nVevXjEej/8Tm0wmlMtlhBAMBgOkaZo0Gg329vbY2dkh\nCIJsZ0oplFK8efOGp0+fcvHiRfL5PAAHBweEYcj8/HxGydevX5FxHDMajajVanz69Ik4jkmSBF3X\n0TSNzc1N7t69S6vV4vXr10gp8X2f4XBIpVLJghDHMRsbG2jT6TRLxuLiIr1eDwBN09A0jYcPHyKE\n4OjRo8RxTBRF9Pt95ubmMud93+f79+80m03k/v4+UspDKDWNRqPBu3fvSNOUtbU16vU6ly5dwnEc\ncrkcrutimib5fD4zxzRNVldXWVpaQqysrKSdTofLly8zmUwoFAoIIfjXuW3bnD17NkuJlBLHcdA0\nDYAgCHj27BmO47C6uopM05RyucyLFy/QNA3XdRFCYBgGQRCwubnJhw8fGAwGANRqNTRNI0kSXr58\nyc2bN6nX64RhyP379xFPnjxJlVJIKTl37hydTocoiuh0OszOzmJZFv1+n8FgwJ07d7hy5Qrj8ZiP\nHz/S7/c5ffo0CwsL9Ho9ZmZmEI8ePUoNwyBJEs6cOcPCwgLfvn3j/fv35PN5bNtGKZUdjp8/f3Lr\n1q3svLVaLTzPI4oiLMviL7opJdyaltNwAAAAAElFTkSuQmCC",
        parameters  => []
    );

}
#Mandatory function to be implemented by your plugin
sub get_tags {

#LRR gives your plugin the recorded title/tags/thumbnail hash for the file, the filesystem path, and the custom arguments if available.
    shift;
    my ( $title, $tags, $thumbhash, $file, $oneshotarg, @args ) = @_;

    my $logger = LANraragi::Utils::Logging::get_logger( "Hdoujin", "plugins" );

    if ( LANraragi::Utils::Archive::is_file_in_archive( $file, "info.json" ) ) {

        #Extract info.json
        my $filepath = LANraragi::Utils::Archive::extract_file_from_archive( $file,
            "info.json" );

        #Open it
        my $stringjson = "";

        open( my $fh, '<:encoding(UTF-8)', $filepath )
          or return ( error => "Could not open $filepath!" );

        while ( my $row = <$fh> ) {
            chomp $row;
            $stringjson .= $row;
        }

        #Use Mojo::JSON to decode the string into a hash
        my $hashjson = from_json $stringjson;

        $logger->debug("Found and loaded the following JSON: $stringjson");

        #Parse it
        $tags = tags_from_Hdoujin_json($hashjson);

        #Delete it
        unlink $filepath;

        #Return tags
        $logger->info("Sending the following tags to LRR: $tags");
        return ( tags => $tags );

    }
    elsif ( LANraragi::Utils::Archive::is_file_in_archive( $file, "info.txt" ) ) {

        # Extract info.txt
        my $filepath = LANraragi::Utils::Archive::extract_file_from_archive( $file,
            "info.txt" );

        # Open it
        open( my $fh, '<:encoding(UTF-8)', $filepath )
          or return ( error => "Could not open $filepath!" );

        while( my $line = <$fh>)  {   

            # Check if the line starts with TAGS:
            if ($line =~ m/TAGS: (.*)/) {
                return ( tags => $1);
            }
        }
        return ( error => "No tags were found in info.txt!" );

    } else {
        return ( error => "No Hdoujin info.json or info.txt file found in this archive!" );
    }

}

#tags_from_Hdoujin_json(decodedjson)
#Goes through the JSON hash obtained from an info.json file and return the contained tags.
sub tags_from_Hdoujin_json {

    	my $hash = $_[0];
    	my $return = "";

#HDoujin jsons are composed of a main manga_info object, containing fields for every metadata.
#Those fields can contain either a single tag or an array of tags.
	
    	my $tags = $hash->{"manga_info"};

    	#Take every key in the manga_info hash, except for title which we're already processing
	
	my @filtered_keys = grep { $_ ne "tags" and $_ ne "title" } keys(%$tags);

	foreach my $namespace ( @filtered_keys ) {

        my $members = $tags->{$namespace};
	   
	    if(ref($members) eq 'ARRAY'){
    

			foreach my $tag (@$members){

				$return .= ", " unless $return eq "";
				$return .= $namespace . ":" . $tag unless $members eq "";
			
			} 
			
		}
		else {
		
				$return .= ", " unless $return eq "";
				$return .= $namespace . ":" . $members unless $members eq "";
				
		}
	
	}
    
    	my $tagsobj = $hash->{"manga_info"}->{"tags"};
    
		if (ref($tagsobj) eq 'HASH'){
	
				return $return . "," . tags_from_wRespect($hash);
		
		}
		else {
		
				return $return . "," . tags_from_noRespect($hash);
				
		}

}

sub tags_from_wRespect {

    my $hash   = $_[0];
    my $return = "";
    my $tags = $hash->{"manga_info"}->{"tags"};

    foreach my $namespace ( keys(%$tags) ) {

        my $members = $tags->{$namespace};
        foreach my $tag (@$members) {

	    
            $return .= ", " unless $return eq "";
            $return .= $namespace . ":" . $tag;

        }
    }

    return $return;

}

sub tags_from_noRespect {

    my $hash   = $_[0];
    my $return = "";
    my $tags = $hash->{"manga_info"};
	
	my @filtered_keys = grep  {  /^tags/ } keys(%$tags);
	
	foreach my $namespace ( @filtered_keys ) {

		my $members = $tags->{$namespace};
	  
				if(ref($members) eq 'ARRAY'){
    

					foreach my $tag (@$members){

						$return .= ", " unless $return eq "";
						$return .= $namespace . ":" . $tag;
			  
					}
					
				}
	
	}

    return $return;

}

1;
