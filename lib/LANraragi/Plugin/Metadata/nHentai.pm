package LANraragi::Plugin::Metadata::nHentai;

use strict;
use warnings;

#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use URI::Escape;
use Mojo::JSON qw(decode_json);
use Mojo::UserAgent;
use Mojo::DOM;

#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_logger);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "nHentai",
        type        => "metadata",
        namespace   => "nhplugin",
        author      => "Difegue",
        version     => "1.7",
        description => "Searches nHentai for tags matching your archive. <br>Supports reading the ID from files formatted as \"{Id} Title\" and if not, tries to search for a matching gallery.",
        icon =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAIAAAAC64paAAAACXBIWXMAAAsTAAALEwEAmpwYAAAA\nB3RJTUUH4wYCFA8s1yKFJwAAAB1pVFh0Q29tbWVudAAAAAAAQ3JlYXRlZCB3aXRoIEdJTVBkLmUH\nAAACL0lEQVQ4y6XTz0tUURQH8O+59773nLFcaGWTk4UUVCBFiJs27VxEQRH0AyRo4x8Q/Qtt2rhr\nU6soaCG0KYKSwIhMa9Ah+yEhZM/5oZMG88N59717T4sxM8eZCM/ycD6Xwznn0pWhG34mh/+PA8mk\n8jO5heziP0sFYwfgMDFQJg4IUjmquSFGG+OIlb1G9li5kykgTgvzSoUCaIYlo8/Igcjpj5wOkARp\n8AupP0uzJLijCY4zzoXOxdBLshAgABr8VOp7bpAXDEI7IBrhdksnjNr3WzI4LaIRV9fk2iAaYV/y\nA1dPiYjBAALgpQxnhV2XzTCAGWGeq7ACBvCdzKQyTH+voAm2hGlpcmQt2Bc2K+ymAhWPxTzPDQLt\nOKo1FiNBQaArq9WNRQwEgKl7XQ1duzSRSn/88vX0qf7DPQddx1nI5UfHxt+m0sLYPiP3shRAG8MD\nok1XEEXR/EI2ly94nrNYWG6Nx0/2Hp2b94dv34mlZge1e4hVCJ4jc6tl9ZP803n3/i4lpdyzq2N0\n7M3DkSeF5ZVYS8v1qxcGz5+5eey4nPDbmGdE9FpGeWErVNe2tTabX3r0+Nk3PwOgXFkdfz99+exA\nMtFZITEt9F23mpLG0hYTVQCKpfKPlZ/rqWKpYoAPcTmpginW76QBbb0OBaBaDdjaDbNlJmQE3/d0\nMYoaybU9126oPkrEhpr+U2wjtoVVGBowkslEsVSupRKdu0Mduq7q7kqExjSS3V2dvwDLavx0eczM\neAAAAABJRU5ErkJggg==",
        parameters  => [ { type => "bool", desc => "Save archive title" } ],
        oneshot_arg => "nHentai Gallery URL (Will attach tags matching this exact gallery to your archive)"
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;    # Global info hash
    my ($savetitle) = @_;    # Plugin parameters

    my $logger = get_logger( "nHentai", "plugins" );

    # Work your magic here - You can create subs below to organize the code better
    my $galleryID = "";

    # Quick regex to get the nh gallery id from the provided url.
    if ( $lrr_info->{oneshot_param} =~ /.*\/g\/([0-9]*)\/.*/ ) {
        $galleryID = $1;
    } else {

        #Get Gallery ID by hand if the user didn't specify a URL
        $galleryID = get_gallery_id_from_title( $lrr_info->{archive_title} );
    }

    # Did we detect a nHentai gallery?
    if ( defined $galleryID ) {
        $logger->debug("Detected nHentai gallery id is $galleryID");
    } else {
        $logger->info("No matching nHentai Gallery Found!");
        return ( error => "No matching nHentai Gallery Found!" );
    }

    #If no tokens were found, return a hash containing an error message.
    #LRR will display that error to the client.
    if ( $galleryID eq "" ) {
        $logger->info("No matching nHentai Gallery Found!");
        return ( error => "No matching nHentai Gallery Found!" );
    }

    my ( $newtags, $newtitle ) = &get_tags_from_NH($galleryID);

    #Return a hash containing the new metadata - it will be integrated in LRR.
    if ( $savetitle && $newtags ne "" ) { return ( tags => $newtags, title => $newtitle ); }
    else                                { return ( tags => $newtags ); }
}

######
## NH Specific Methods
######

#get_gallery_id_from_title(title)
#Uses the website's search to find a gallery and returns its gallery ID.
sub get_gallery_id_from_title {

    my $title  = $_[0];
    my $logger = get_logger( "nHentai", "plugins" );

    my $gallery = "";

    if ( $title =~ /\{(\d*)\}.*$/gm ) {
        $gallery = $1;
        $logger->debug("Got $gallery from file.");
        return $gallery;
    }

    #Strip away hyphens and apostrophes as they apparently break search
    $title =~ s/-|'/ /g;

    my $URL = "https://nhentai.net/search/?q=" . uri_escape_utf8($title);

    $logger->debug("Using URL $URL to search on nH.");
    my $ua = Mojo::UserAgent->new;

    my $res = $ua->get($URL)->result;

    # Parse
    my $dom = Mojo::DOM->new( $res->body );

    # Get the first gallery url of the search results
    my $gURL = ( $dom->at('.cover') ) ? $dom->at('.cover')->attr('href') : "";

    if ( $gURL =~ /\/g\/(\d*)\//gm ) {
        $gallery = $1;
    }

    return $gallery;
}

# get_tags_from_NH(galleryID)
# Parses the JSON obtained from a nhentai allery page to get the tags.
sub get_tags_from_NH {

    my $gID      = $_[0];
    my $returned = "";

    my $logger = get_logger( "nHentai", "plugins" );

    my $URL = "https://nhentai.net/g/$gID/";
    my $ua  = Mojo::UserAgent->new;

    my $textrep = $ua->get($URL)->result->body;

    #Find the metadata JSON in the HTML and turn it into an object
    #It's located under a N.gallery JS object.
    my $jsonstring = "{}";
    if ( $textrep =~ /window\._gallery.*=.*JSON\.parse\((.*)\);/gmi ) {
        $jsonstring = $1;
    }

    $logger->debug("Tentative JSON: $jsonstring");

    # nH now provides their JSON with \uXXXX escaped characters.
    # The first pass of decode_json decodes those characters, but still outputs a string.
    # The second pass turns said string into an object properly so we can exploit it as a hash.
    my $json = decode_json $jsonstring;
    $json = decode_json $json;

    my $tags = $json->{"tags"};

    foreach my $tag (@$tags) {

        $returned .= ", " unless $returned eq "";

        #Try using the "type" attribute to craft a namespace.
        #The basic "tag" type the NH API adds by default will be ignored here.
        my $namespace = "";

        unless ( $tag->{"type"} eq "tag" ) {
            $namespace = $tag->{"type"} . ":";
        }

        $returned .= $namespace . $tag->{"name"};

    }
    $returned .= ", source:https://nhentai.net/g/$gID";

    $logger->info("Sending the following tags to LRR: $returned");

    # Use NH's "pretty" names (romaji titles without extraneous data we already have like (Event)[Artist], etc)
    return ( $returned, $json->{"title"}->{"pretty"} );

}

1;
