package LANraragi::Plugin::Chaika;

use strict;
use warnings;

#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use URI::Escape;
use Mojo::UserAgent;

#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "Chaika.moe",
        namespace   => "trabant",
        author      => "Difegue",
        version     => "1.0",
        description => "Searches chaika.moe for tags matching your archive.",

#If your plugin uses/needs custom arguments, input their name here.
#This name will be displayed in plugin configuration next to an input box for global arguments, and in archive edition for one-shot arguments.
        global_arg  => "",
        oneshot_arg => "Chaika Gallery or Archive URL (Will attach matching tags to your archive)"
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    #LRR gives your plugin the recorded title/tags/thumbnail hash for the file, the filesystem path, and the custom arguments if available.
    shift;
    my ( $title, $tags, $thumbhash, $file, $globalarg, $oneshotarg ) = @_;

    my $logger = LANraragi::Model::Utils::get_logger( "Chaika", "plugins" );

    #Chaika has two possible types - Gallery or Archive. 
    #We perform searching in archives by default, but the user can use gallery URLs.
    my $type = "archive";
    my $ID   = "";

    #parse the given link to see if we can extract type and ID
    if ( $oneshotarg =~ /.*\/(.*)\/([0-9]*).*/ ) {
        $type = $1;
        $ID   = $2;
    }
    else {
        #Get Gallery ID by hand if the user didn't specify a URL
        $ID = search_for_archive($title, $tags);
    }

    if ($ID eq "") {
        $logger->info("No matching Chaika Archive Found!");
        return ( error => "No matching Chaika Archive Found!" );
    }

    my $tags = tags_from_chaika($type,$ID);

    #Return a hash containing the new metadata - it will be integrated in LRR.
    return ( tags => $tags );
}

######
## Chaika Specific Methods
######

# search_for_archive
# Uses chaika's elasticsearch to find a matching archive ID
sub search_for_archive {

    my $title = $_[0];
    my $tags = $_[1];

    #chaika.moe/es-index/?q=

    return "27240";

}

# tags_from_chaika(type,ID)
# Parses the JSON obtained from the Chaika API to get the tags.
sub tags_from_chaika {

    my $type     = $_[0];
    my $ID       = $_[1];
    my $returned = "";

    my $logger = LANraragi::Model::Utils::get_logger( "Chaika", "plugins" );
    my $URL    = "https://panda.chaika.moe/jsearch/?".$type."=".$ID;
    my $ua     = Mojo::UserAgent->new;
    my $res    = $ua->get($URL)->result;

    my $textrep = $res->body;
    $logger->debug("Chaika API returned this JSON: $textrep");

    my $json = $res->json;
    my $tags = $json->{"tags"};

    #TODO (maybe): 
    #Chaika has support for english and japanese titles through its "title" and "title_jpn" fields.

    foreach my $tag (@$tags) {

        $returned .= ", " unless $returned eq "";

        #Replace underscores with spaces
        $tag =~ s/_/ /g;

        $returned .= $tag;

    }

    $logger->info("Sending the following tags to LRR: $returned");

    return $returned;

}

1;
