package LANraragi::Plugin::Eze;

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
        name      => "eze",
        namespace => "ezeplugin",
        author    => "Difegue",
        version   => "1.0",
        description =>
"Collects metadata embedded into your archives by the eze userscript. (info.json files)",
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

#LRR gives your plugin the recorded title/tags/thumbnail hash for the file, the filesystem path, and the custom arguments if available.
    shift;
    my ( $title, $tags, $thumbhash, $file, $oneshotarg, @args ) = @_;

    my $logger = LANraragi::Utils::Generic::get_logger( "eze", "plugins" );

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
        $tags = tags_from_eze_json($hashjson);

        #Delete it
        unlink $filepath;

        #Return tags
        $logger->info("Sending the following tags to LRR: $tags");
        return ( tags => $tags );

    }
    else {

        return ( error => "No eze info.json file found in this archive!" );
    }

}

#tags_from_eze_json(decodedjson)
#Goes through the JSON hash obtained from an info.json file and return the contained tags.
sub tags_from_eze_json {

    my $hash   = $_[0];
    my $return = "";

    #Tags are in gallery_info -> tags -> one array per namespace
    my $tags = $hash->{"gallery_info"}->{"tags"};

    foreach my $namespace ( keys(%$tags) ) {

        # Get the array for this namespace and iterate on it
        my $members = $tags->{$namespace};
        foreach my $tag (@$members) {

            $return .= ", " unless $return eq "";
            $return .= $namespace . ":" . $tag;

        }
    }

    #Done-o
    return $return;

}

1;
