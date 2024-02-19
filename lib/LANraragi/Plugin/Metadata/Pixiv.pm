package LANraragi::Plugin::Metadata::Pixiv;

use strict;
use warnings;

# Plugins can freely use all Perl packages already installed on the system 
# Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use Mojo::JSON qw(decode_json);
use Mojo::UserAgent;

use Time::Piece;
use Time::Local;

# You can also use LRR packages when fitting.
# All packages are fair game, but only functions explicitly exported by the Utils packages are supported between versions.
# Everything else is considered internal API and can be broken/renamed between versions.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_plugin_logger);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "Pixiv",
        type        => "metadata",
        namespace   => "pixivmetadata",
        login_from  => "pixivlogin",
        author      => "psilabs-dev",
        version     => "0.1",
        description => "Retrieve metadata of a Pixiv artwork by its artwork ID.",
        icon        => "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAMCAgICAgMCAgIDAwMDBAYEBAQEBAgGBgUGCQgKCgkICQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/2wBDAQMDAwQDBAgEBAgQCwkLEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBD/wAARCAAUABQDAREAAhEBAxEB/8QAGQAAAgMBAAAAAAAAAAAAAAAAAwYABAUH/8QAJBAAAgICAgICAgMAAAAAAAAAAQIDBAUGABESIQcxImETQVH/xAAZAQACAwEAAAAAAAAAAAAAAAADBgACCAX/xAAoEQABBAEDAgYDAQAAAAAAAAABAgMEEQAFITESUQYTFEFhkTJxocH/2gAMAwEAAhEDEQA/ANfRvi3MbpRvZxrlfG4jHQT2J7U35PIsKB5FhjHuRgpHf0B5DsjvmrNV15nTHERwkrcWQABwOo0Co8AE/smjQzIWkeHn9VbXIKghpAUSTyekWQkckgV2G4s4fXNI1LeMkuuarsuQizVgEUYsnTSKG5IB2Iw6SN/GzdevIEE+uxwc3VJmlteqltJLQ/IoUSUjvRAsD3rf4wkHSYOru+khOqDp/ELSAFHtYUaJ9rFfOJFmtPTsy07UTRTQO0ciMOirKeiD+wRzvIWl1IWg2DuP1i642ppZbWKINEfIzpnwOHt5LaaE14QVzqeV/OTyMcRaNQXIUE/0O+gT64q+LKbajuJTZ85virNE7b/6cbvB9uPSWlKpPkO83QsDfa/4MFoFHVNE2jH7tsm54u5Dhplu16OLaSaxbmT2ie0VY18gO2Yj19A8Jq7szVYi4EVhSS4OkqXQSkHk8kk1wB95XRmYWjzG9QlyEqDZ6glFlSiNwOAAL5JPHtiHn8vNsGdyOesoqS5G3LbdV+laRyxA/XvjBEjJhx0R07hAA+hWLU2SqbJckrFFair7N4ClksjjWkbHX7NUzRmKQwyshdD9qej7B/w8u6y09QdSDW4sXR74Np91iy0opsUaJFjtt7ZX4XBZOTJn/9k=",
        #If your plugin uses/needs custom arguments, input their name here. 
        #This name will be displayed in plugin configuration next to an input box for global arguments, and in archive edition for one-shot arguments.
        oneshot_arg => "Pixiv artwork URL (e.g. pixiv.net/en/artworks/123456.)",
        parameters  => [
            { type => 'string', desc => 'Comma-separated list of languages to support. Options: jp, en. Empty string defaults to original tags (jp) only.' }
        ]
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift; # Global info hash, contains various metadata provided by LRR
    my $ua = $lrr_info -> {user_agent};
    my $logger = get_plugin_logger();
    my ( $tag_languages_str ) = @_;

    my $illust_id = find_illust_id( $lrr_info );
    if ($illust_id ne '') {
        $logger -> info("Pixiv illustration ID = $illust_id");

        #Work your magic here - You can create subroutines below to organize the code better
        my %metadata = get_metadata_from_illust_id( $illust_id, $ua , $tag_languages_str );

        #Otherwise, return the tags you've harvested.
        $logger->info( "Sending the following tags to LRR: " . $metadata{tags} );
        return %metadata;
    } else {
        $logger -> error( "Failed to extract Pixiv ID!" );
    }

}

######
## Pixiv Specific Methods
######

sub find_illust_id {

    my ( $lrr_info ) = @_;

    my $oneshot_param = $lrr_info -> {"oneshot_param"};
    my $archive_title = $lrr_info -> {"archive_title"};
    my $logger = get_plugin_logger();

    # case 1: "$illust_id" i.e. string of digits.
    if ($oneshot_param =~ /^\d+$/) {
        return $oneshot_param;
    }
    # case 2: URL-based embedding
    if ($oneshot_param =~ m{(?:pixiv\.net|www\.pixiv\.net)/.*/artworks/(\d+)}) {
        return $1;
    }
    # case 3: no oneshot param, get id by title.
    if ($archive_title =~ /\{(\d*)\}.*$/) {
        return $1;
    }

    return "";

}

sub get_hash_metadata_from_json {

    my ( $json, $illust_id, $tag_languages_str ) = @_;
    my $logger = get_plugin_logger();
    my %hashdata;

    # extract tag languages.
    my @tag_languages;
    if ( $tag_languages_str eq "" ) {
        push @tag_languages, "jp";
    } else {
        @tag_languages = map {
            s/^\s+//;
            s/\s+$//;
            $_
        } split(/,/, $tag_languages_str);
    }

    # get illustration metadata.
    my %illust_metadata = %{$json -> {"illust"} -> { $illust_id }};
    my @tags;

    # get illustration type.
    my $illust_type = $illust_metadata{"illustType"};

    # manga-specific metadata.
    if ( exists $illust_metadata{"seriesNavData"} && defined $illust_metadata{"seriesNavData"} ) {
        my %series_nav_data = %{ $illust_metadata{"seriesNavData"} };

        my $series_id = $series_nav_data{"seriesId"};
        my $series_title = $series_nav_data{"title"};
        my $series_order = $series_nav_data{"order"};

        if ( defined $series_id && defined $series_title && defined $series_order ) {
            push @tags, (
                "series_id:$series_id",
                "series_title:$series_title",
                "series_order:$series_order",
            )
        }
    }

    # add tag data.
    foreach my $item ( @{$illust_metadata{"tags"}{"tags"}} ) {
        
        # iterate over tagging language.
        foreach my $tag_language ( @tag_languages ) {

            if ($tag_language eq 'jp') {
                # add original/jp tags.
                my $orig_tag = $item -> {"tag"};
                push @tags, $orig_tag;

            } 
            else {
                # add translated tags.
                my $translated_tag = $item -> {"translation"} -> { $tag_language };
                push @tags, $translated_tag;
            }
        }
    }

    # add source
    my $source = "https://pixiv.net/artworks/$illust_id";

    push @tags, "source:$source";

    # add general metadata.
    
    my $user_id = $illust_metadata{"userId"};
    my $user_name = $illust_metadata{"userName"};

    push @tags, ("user_id:$user_id", "artist:$user_name");

    # add time-based metadata.
    my $create_date = $illust_metadata{"createDate"};
    my $upload_date = $illust_metadata{"uploadDate"};
    $create_date =~ s/(\+\d{2}:\d{2})$//;
    $upload_date =~ s/(\+\d{2}:\d{2})$//;
    my $create_date_epoch = Time::Piece -> strptime( $create_date, "%Y-%m-%dT%H:%M:%S" ) -> epoch;
    my $upload_date_epoch = Time::Piece -> strptime( $upload_date, "%Y-%m-%dT%H:%M:%S" ) -> epoch;

    push @tags, ("date_created:$create_date_epoch", "date_uploaded:$upload_date_epoch");

    $hashdata{tags} = join( ', ', @tags );

    # change title.
    my $illust_title = $illust_metadata{"illustTitle"};
    $hashdata{title} = $illust_title;

    return %hashdata;

}

sub get_json_from_html {

    my ( $html ) = @_;
    my $logger = get_plugin_logger();

    # get 'content' body.
    my $jsonstring = "{}";
    if ( $html =~ /<meta name="preload-data" id="meta-preload-data" content='(.*?)'>/ ) {
        $jsonstring = $1;
    }
    
    $logger -> debug("Tentative JSON: $jsonstring");
    my $json = decode_json $jsonstring;
    return $json;

}

sub get_html_from_illust_id {

    my ( $illust_id, $ua ) = @_;
    my $logger = get_plugin_logger();

    # illustration ID to URL.
    my $URL = "https://www.pixiv.net/en/artworks/$illust_id/";
    $logger -> info("URL = $URL");

    while (1) {

        my $res = $ua -> get (
            $URL => {
                Referer => "https://www.pixiv.net"
            }
        ) -> result;
        my $code = $res -> code;
        $logger -> info("Received code $code.");

        # handle 3xx.
        if ( $code == 301 ) {
            $URL = $res -> headers -> location;
            $logger -> info("Redirecting to $URL");
            next;
        }
        if ( $code == 302 ) {
            my $location = $res -> headers -> location;
            $URL = "pixiv.net$location";
            $logger -> info("Redirecting to $URL");
            next;
        }

        # handle 4xx.
        if ( $res -> is_error ) {
            my $code = $res -> code;
            return "error ($code) ";
        }

        # handle 2xx.
        return $res -> body;

    }

}

sub get_metadata_from_illust_id {
    my ( $illust_id, $ua, $tag_languages_str ) = @_;
    my $logger = get_plugin_logger();

    # initialize hash.
    my %hashdata = ( tags => "" );

    my $html = get_html_from_illust_id( $illust_id, $ua );

    if ( $html =~ /^error/ ) {
        return ( error => "Error retrieving HTML from Pixiv Illustration: $html");
    }

    my $json = get_json_from_html( $html );
    if ($json) {
        %hashdata = get_hash_metadata_from_json( $json, $illust_id, $tag_languages_str );
    }

    return %hashdata;

}

1;