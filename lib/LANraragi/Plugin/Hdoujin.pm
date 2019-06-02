package LANraragi::Plugin::Hdoujin;

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
        version     => "0.3",
        description => "Collects metadata embedded into your archives ONLY by the Hdoujin .json files, does not support other format.",
        parameters  => []
    );

}
#Mandatory function to be implemented by your plugin
sub get_tags {

#LRR gives your plugin the recorded title/tags/thumbnail hash for the file, the filesystem path, and the custom arguments if available.
    shift;
    my ( $title, $tags, $thumbhash, $file, $oneshotarg, @args ) = @_;

    my $logger = LANraragi::Utils::Generic::get_logger( "Hdoujin", "plugins" );

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
    else {

        return ( error => "No Hdoujin info.json file found in this archive!" );
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
