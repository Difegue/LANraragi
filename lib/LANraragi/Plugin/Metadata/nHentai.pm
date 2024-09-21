package LANraragi::Plugin::Metadata::nHentai;

use strict;
use warnings;

#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use URI::Escape;
use Mojo::JSON qw(decode_json);
use Mojo::UserAgent;
use File::Basename;

#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::Database qw(redis_decode);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "nHentai",
        type        => "metadata",
        namespace   => "nhplugin",
        login_from  => "nhentaicfbypass",
        author      => "Difegue and others",
        version     => "1.9",
        description => "Searches nHentai for tags matching your archive.
          <br>Supports reading the ID from files formatted as \"{Id} Title\" and if not, tries to search for a matching gallery.
          <br><i class='fa fa-exclamation-circle'></i> This plugin will use the source: tag of the archive if it exists.",
        icon =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAIAAAAC64paAAAACXBIWXMAAAsTAAALEwEAmpwYAAAA\nB3RJTUUH4wYCFA8s1yKFJwAAAB1pVFh0Q29tbWVudAAAAAAAQ3JlYXRlZCB3aXRoIEdJTVBkLmUH\nAAACL0lEQVQ4y6XTz0tUURQH8O+59773nLFcaGWTk4UUVCBFiJs27VxEQRH0AyRo4x8Q/Qtt2rhr\nU6soaCG0KYKSwIhMa9Ah+yEhZM/5oZMG88N59717T4sxM8eZCM/ycD6Xwznn0pWhG34mh/+PA8mk\n8jO5heziP0sFYwfgMDFQJg4IUjmquSFGG+OIlb1G9li5kykgTgvzSoUCaIYlo8/Igcjpj5wOkARp\n8AupP0uzJLijCY4zzoXOxdBLshAgABr8VOp7bpAXDEI7IBrhdksnjNr3WzI4LaIRV9fk2iAaYV/y\nA1dPiYjBAALgpQxnhV2XzTCAGWGeq7ACBvCdzKQyTH+voAm2hGlpcmQt2Bc2K+ymAhWPxTzPDQLt\nOKo1FiNBQaArq9WNRQwEgKl7XQ1duzSRSn/88vX0qf7DPQddx1nI5UfHxt+m0sLYPiP3shRAG8MD\nok1XEEXR/EI2ly94nrNYWG6Nx0/2Hp2b94dv34mlZge1e4hVCJ4jc6tl9ZP803n3/i4lpdyzq2N0\n7M3DkSeF5ZVYS8v1qxcGz5+5eey4nPDbmGdE9FpGeWErVNe2tTabX3r0+Nk3PwOgXFkdfz99+exA\nMtFZITEt9F23mpLG0hYTVQCKpfKPlZ/rqWKpYoAPcTmpginW76QBbb0OBaBaDdjaDbNlJmQE3/d0\nMYoaybU9126oPkrEhpr+U2wjtoVVGBowkslEsVSupRKdu0Mduq7q7kqExjSS3V2dvwDLavx0eczM\neAAAAABJRU5ErkJggg==",
        parameters  => [ { type => "bool", desc => "Fetch date uploaded and set timestamp tag" } ],
        oneshot_arg => "nHentai Gallery URL (Will attach tags matching this exact gallery to your archive)"
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;                      # Global info hash
    my $ua       = $lrr_info->{user_agent};    # UserAgent from login plugin
    my ($add_uploaded) = @_;                   # Parameters

    my $logger = get_plugin_logger();

    # Work your magic here - You can create subs below to organize the code better
    my $galleryID = "";

    # Quick regex to get the nh gallery id from the provided url or source tag.
    if ( $lrr_info->{oneshot_param} =~ /.*\/g\/([0-9]+).*/ ) {
        $galleryID = $1;
        $logger->debug("Skipping search and using gallery $galleryID from oneshot args");
    } elsif ( $lrr_info->{existing_tags} =~ /.*source:\s*(?:https?:\/\/)?nhentai\.net\/g\/([0-9]*).*/gi ) {

        # Matching URL Scheme like 'https://' is only for backward compatible purpose.
        $galleryID = $1;
        $logger->debug("Skipping search and using gallery $galleryID from source tag");
    } else {
        $logger->debug("Searching gallery by title (filename)");

        # lrr_info's file_path is taken straight from the filesystem, which might not be proper UTF-8.
        my $file_path = redis_decode($lrr_info->{file_path});

        #Get Gallery ID by hand if the user didn't specify a URL
        $galleryID = get_gallery_id_from_title( $file_path, $ua );
    }

    # Did we detect a nHentai gallery?
    if ( !$galleryID ) {
        my $message = "No matching nHentai Gallery Found!";
        $logger->info($message);
        die "${message}\n";
    }

    $logger->debug("Detected nHentai gallery ID is $galleryID");

    my %hashdata = get_tags_from_NH( $galleryID, $ua, $add_uploaded );

    $logger->info( "Sending the following tags to LRR: " . $hashdata{tags} );

    #Return a hash containing the new metadata - it will be integrated in LRR.
    return %hashdata;
}

######
## NH Specific Methods
######

#Uses the website's search to find a gallery and returns its content.
sub get_gallery_dom_by_title {

    my ( $title, $ua ) = @_;

    my $logger = get_plugin_logger();

    #Strip away hyphens and apostrophes as they apparently break search
    $title =~ s/-|'/ /g;

    my $URL = "https://nhentai.net/search/?q=" . uri_escape_utf8($title);

    $logger->debug("Using URL $URL to search on nH.");

    my $res = $ua->get($URL)->result;
    $logger->debug( "Got response " . $res->body );

    if ( $res->is_error ) {
        my $code = $res->code;
        die "Search gallery by title failed! (Code: $code)\n";
    }

    return $res->dom;
}

sub get_gallery_id_from_title {

    my ( $file, $ua ) = @_;
    my ( $title, $filepath, $suffix ) = fileparse( $file, qr/\.[^.]*/ );

    my $logger = get_plugin_logger();

    if ( $title =~ /\{(\d*)\}.*$/gm ) {
        $logger->debug("Got $1 from file.");
        return $1;
    }

    my $dom = get_gallery_dom_by_title( $title, $ua );

    if ($dom) {

        # Get the first gallery url of the search results
        my $gURL =
          ( $dom->at('.cover') )
          ? $dom->at('.cover')->attr('href')
          : "";

        $logger->debug("Got $gURL from parsing.");
        if ( $gURL =~ /\/g\/(\d*)\//gm ) {
            return $1;
        }
    }

    return;
}

# retrieves html page from NH
sub get_html_from_NH {

    my ( $gID, $ua ) = @_;

    my $URL = "https://nhentai.net/g/$gID/";

    my $res = $ua->get($URL)->result;

    if ( $res->is_error ) {
        my $code = $res->code;
        die "Error retrieving gallery from nHentai! (Code: $code)\n";
    }

    return $res->body;
}

#Find the metadata JSON in the HTML and turn it into an object
#It's located under a N.gallery JS object.
sub get_json_from_html {

    my ($html) = @_;

    my $logger = get_plugin_logger();

    my $jsonstring = "{}";
    if ( $html =~ /window\._gallery.*=.*JSON\.parse\((.*)\);/gmi ) {
        $jsonstring = $1;
    }

    $logger->debug("Tentative JSON: $jsonstring");

    # nH now provides their JSON with \uXXXX escaped characters.
    # The first pass of decode_json decodes those characters, but still outputs a string.
    # The second pass turns said string into an object properly so we can exploit it as a hash.
    my $json = decode_json $jsonstring;
    $json = decode_json $json;

    return $json;
}

sub get_tags_from_json {

    my ($json) = @_;

    my @json_tags = @{ $json->{"tags"} };
    my @tags      = ();

    foreach my $tag (@json_tags) {

        my $namespace = $tag->{"type"};
        my $name      = $tag->{"name"};

        if ( $namespace eq "tag" ) {
            push( @tags, $name );
        } else {
            push( @tags, "$namespace:$name" );
        }
    }

    return @tags;
}

sub get_title_from_json {
    my ($json) = @_;
    return $json->{"title"}{"pretty"};
}

sub get_upload_from_json {
    my ($json) = @_;
    return $json->{"upload_date"};
}

sub get_tags_from_NH {

    my ( $gID, $ua, $add_uploaded ) = @_;

    my %hashdata = ( tags => "" );

    my $html = get_html_from_NH( $gID, $ua );
    my $json = get_json_from_html($html);

    if ($json) {
        my @tags = get_tags_from_json($json);
        if ($add_uploaded) {
            my @upload = get_upload_from_json($json);
            push( @tags, "timestamp:@upload");
        }
        push( @tags, "source:nhentai.net/g/$gID" ) if ( @tags > 0 );

        # Use NH's "pretty" names (romaji titles without extraneous data we already have like (Event)[Artist], etc)
        $hashdata{tags}  = join( ', ', @tags );
        $hashdata{title} = get_title_from_json($json);
    }

    return %hashdata;
}

1;
