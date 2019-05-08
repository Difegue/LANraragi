package LANraragi::Plugin::Chaika;

use strict;
use warnings;

#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use URI::Escape;
use Mojo::UserAgent;
use Mojo::DOM;

#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;

my $chaika_url = "https://panda.chaika.moe";

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "Chaika.moe",
        type        => "metadata",
        namespace   => "trabant",
        author      => "Difegue",
        version     => "2.0",
        description => "Searches chaika.moe for tags matching your archive.",
        parameters  => (),
        oneshot_arg => "Chaika Gallery or Archive URL (Will attach matching tags to your archive)"
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

#LRR gives your plugin the recorded title/tags/thumbnail hash for the file, the filesystem path, and the custom arguments if available.
    shift;
    my ( $title, $tags, $thumbhash, $file, $oneshotarg, @args ) = @_;

    my $logger = LANraragi::Utils::Generic::get_logger( "Chaika", "plugins" );
    my $newtags = "";

    #parse the given link to see if we can extract type and ID
    if ( $oneshotarg =~
        /https?:\/\/panda\.chaika\.moe\/(gallery|archive)\/([0-9]*)\/?.*/ )
    {
        $newtags = tags_from_chaika_id( $1, $2 );
    }
    else {

        #Try SHA-1 reverse search first
        $newtags = tags_from_sha1($thumbhash);

        if ( $newtags eq "" ) {

            #Get Gallery ID by hand if nothing else worked
            my $ID = search_for_archive( $title, $tags );

            #Chaika has two possible types - Gallery or Archive.
            #We perform searching in archives by default here.
            $newtags = tags_from_chaika_id( "archive", $ID );
        }
    }

    if ( $newtags eq "" ) {
        $logger->info("No matching Chaika Archive Found!");
        return ( error => "No matching Chaika Archive Found!" );
    }
    else {
        #Return a hash containing the new metadata
        return ( tags => $newtags );
    }

}

######
## Chaika Specific Methods
######

# search_for_archive
# Uses chaika's html search to find a matching archive ID
sub search_for_archive {

    my $logger = LANraragi::Utils::Generic::get_logger( "Chaika", "plugins" );
    my $title  = $_[0];
    my $tags   = $_[1];

    #Auto-lowercase the title for better results
    $title = lc($title);

    #Strip away hyphens and apostrophes as they apparently break search
    $title =~ s/-|'/ /g;

    my $URL = "$chaika_url/search/?title=" . uri_escape_utf8($title) . "&tags=";

    #Append language:english tag, if it exists.
    #Chaika only has english or japanese so I aint gonna bother more than this
    if ( $tags =~ /.*language:\s?english,*.*/gi ) {
        $URL = $URL . uri_escape_utf8("language:english") . "+";
    }

    $logger->debug("Calling $URL");
    my $ua      = Mojo::UserAgent->new;
    my $content = $ua->get($URL)->result->body;

    #Use Mojo's DOM parser to get the first link
    my $dom  = Mojo::DOM->new($content);
    my $href = "";

    #Find first <tr class="result-list"> node
    #In this node, first href is an archive ID
    eval {
        $href = $dom->at(".result-list")->at("a")->attr("href");
        $logger->debug( "DOM parser found " . $href );
    };

    if ( $href =~ /\/archive\/([0-9]*)\/?.*/ ) {
        return $1;
    }
    else {
        return "";
    }
}

# Uses the jsearch API to get the best json for a file.
sub tags_from_chaika_id {

    my $type = $_[0];
    my $ID   = $_[1];

    my $logger = LANraragi::Utils::Generic::get_logger( "Chaika", "plugins" );
    my $URL    = "$chaika_url/jsearch/?$type=$ID";
    my $ua     = Mojo::UserAgent->new;
    my $res    = $ua->get($URL)->result;

    my $textrep = $res->body;
    $logger->debug("Chaika API returned this JSON: $textrep");

    my $returned = parse_chaika_json( $res->json );
    $logger->info("Sending the following tags to LRR: $returned");

    return $returned;

}

# tags_from_sha1
# Uses chaika's SHA-1 search with the first page hash we have.
sub tags_from_sha1 {

    my $hash   = $_[0];
    my $logger = LANraragi::Utils::Generic::get_logger( "Chaika", "plugins" );
    my $URL    = "$chaika_url/jsearch/?sha1=$hash";

    # The jsearch API immediately returns a JSON.
    # Said JSON is an array containing multiple archive objects.
    # We just take the first one.
    my $ua       = Mojo::UserAgent->new;
    my $res      = $ua->get($URL)->result;
    my $returned = parse_chaika_json( $res->json->[0] );

    $logger->info("SHA-1 reverse search found the following tags: $returned");
    return $returned;
}

# Parses the JSON obtained from the Chaika API to get the tags.
sub parse_chaika_json {
    my $logger = LANraragi::Utils::Generic::get_logger( "Chaika", "plugins" );
    my $json = $_[0];

    # If the json contains a gallery id, we switch to it.
    # Gallery IDs often have more metadata stored.
    if ( $json->{"gallery"} ) {

        my $gID = $json->{"gallery"};
        $logger->debug("Gallery ID detected($gID), switching to it.");

        my $URL = "$chaika_url/jsearch/?gallery=$gID";
        my $ua  = Mojo::UserAgent->new;
        my $res = $ua->get($URL)->result;
        $json = $res->json;
    }

    my $tags = $json->{"tags"};
    my $res  = "";
    foreach my $tag (@$tags) {

        $res .= ", " unless $res eq "";

        #Replace underscores with spaces
        $tag =~ s/_/ /g;
        $res .= $tag;
    }

    return $res;

}

1;
