package LANraragi::Plugin::Metadata::Pixiv;

use strict;
use warnings;

# Plugins can freely use all Perl packages already installed on the system 
# Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use Mojo::DOM;
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
        description => "Retrieve metadata of a Pixiv artwork by its artwork ID.
            <br>Supports ID extraction from these file formats: \"{Id} Title\" or \"pixiv_{Id} Title\".
            <br>
            <br><i class='fa fa-exclamation-circle'></i> Pixiv enforces a rate limit on API requests, and may suspend/ban your account for overuse.
        ",
        icon        => "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAMCAgICAgMCAgIDAwMDBAYEBAQEBAgGBgUGCQgKCgkICQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/2wBDAQMDAwQDBAgEBAgQCwkLEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBD/wAARCAAUABQDAREAAhEBAxEB/8QAGQAAAgMBAAAAAAAAAAAAAAAAAwYABAUH/8QAJBAAAgICAgICAgMAAAAAAAAAAQIDBAUGABESIQcxImETQVH/xAAZAQACAwEAAAAAAAAAAAAAAAADBgACCAX/xAAoEQABBAEDAgYDAQAAAAAAAAABAgMEEQAFITESUQYTFEFhkTJxocH/2gAMAwEAAhEDEQA/ANfRvi3MbpRvZxrlfG4jHQT2J7U35PIsKB5FhjHuRgpHf0B5DsjvmrNV15nTHERwkrcWQABwOo0Co8AE/smjQzIWkeHn9VbXIKghpAUSTyekWQkckgV2G4s4fXNI1LeMkuuarsuQizVgEUYsnTSKG5IB2Iw6SN/GzdevIEE+uxwc3VJmlteqltJLQ/IoUSUjvRAsD3rf4wkHSYOru+khOqDp/ELSAFHtYUaJ9rFfOJFmtPTsy07UTRTQO0ciMOirKeiD+wRzvIWl1IWg2DuP1i642ppZbWKINEfIzpnwOHt5LaaE14QVzqeV/OTyMcRaNQXIUE/0O+gT64q+LKbajuJTZ85virNE7b/6cbvB9uPSWlKpPkO83QsDfa/4MFoFHVNE2jH7tsm54u5Dhplu16OLaSaxbmT2ie0VY18gO2Yj19A8Jq7szVYi4EVhSS4OkqXQSkHk8kk1wB95XRmYWjzG9QlyEqDZ6glFlSiNwOAAL5JPHtiHn8vNsGdyOesoqS5G3LbdV+laRyxA/XvjBEjJhx0R07hAA+hWLU2SqbJckrFFair7N4ClksjjWkbHX7NUzRmKQwyshdD9qej7B/w8u6y09QdSDW4sXR74Np91iy0opsUaJFjtt7ZX4XBZOTJn/9k=",
        #If your plugin uses/needs custom arguments, input their name here. 
        #This name will be displayed in plugin configuration next to an input box for global arguments, and in archive edition for one-shot arguments.
        oneshot_arg => "Pixiv artwork URL or illustration ID (e.g. pixiv.net/en/artworks/123456 or 123456.)",
        parameters  => [
            { type => 'string', desc => 'Comma-separated list of languages to support. Options: jp, en. Empty string defaults to original tags (jp) only.' }
        ],
        cooldown    => 1
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
        $logger -> debug("Retrieved Pixiv illustration ID = $illust_id");

        #Work your magic here - You can create subroutines below to organize the code better
        my %metadata = get_metadata_from_illust_id( $illust_id, $ua , $tag_languages_str );

        #Otherwise, return the tags you've harvested.
        $logger -> info( "Sending the following tags to LRR: " . $metadata{tags} );
        return %metadata;
    } else {
        $logger -> error( "Failed to extract Pixiv ID!" );
    }

}

######
## Pixiv Specific Methods
######

# sanitize the text according to the search syntax: https://sugoi.gitbook.io/lanraragi/basic-operations/searching
sub sanitize {

    my ( $text ) = @_;
    my $sanitized_text = $text;

    # replace nonseparator characters with empty str.
    $sanitized_text =~ s/["?*%\$:]//g;

    # replace underscore with space.
    $sanitized_text =~ s/[_]/ /g;

    # if a dash is preceded by space, remove; otherwise keep.
    $sanitized_text =~ s/ -/ /g;

    if ( $sanitized_text ne $text ) {
        my $logger = get_plugin_logger();
        $logger -> info("\"$text\" was sanitized.");
    }

    return $sanitized_text;

}

sub find_illust_id {

    my ( $lrr_info ) = @_;

    my $oneshot_param = $lrr_info -> {"oneshot_param"};
    my $archive_title = $lrr_info -> {"archive_title"};
    my $logger = get_plugin_logger();

    if (defined $oneshot_param) {
        # case 1: "$illust_id" i.e. string of digits.
        if ($oneshot_param =~ /^\d+$/) {
            return $oneshot_param;
        }
        # case 2: URL-based embedding
        if ($oneshot_param =~ m{.*pixiv\.net/.*artworks/(\d+)}) {
            return $1;
        }
    }

    if (defined $archive_title) {
        # case 3: archive title extraction (strong pattern matching)
        # use strong pattern matching if using multiple metadata plugins and archive title needs to exclusively call the pixiv plugin.
        if ($archive_title =~ /pixiv_\{(\d*)\}.*$/) {
            return $1;
        }

        # case 4: archive title extraction (weak pattern matching)
        if ($archive_title =~ /^\{(\d*)\}.*$/) {
            return $1;
        }
    }

    return "";

}

sub get_illustration_dto_from_json {
    # retrieve relevant data obj from json obj
    my ( $json, $illust_id ) = @_;
    return %{$json -> {'illust'} -> { $illust_id }};
}

sub get_manga_data_from_dto {
    # get manga-based data and return as an array.
    my ( $dto ) = @_;
    my @manga_data;

    if ( exists $dto -> {"seriesNavData"} && defined $dto -> {"seriesNavData"} ) {
        my %series_nav_data = %{ $dto -> {"seriesNavData"} };

        my $series_id = $series_nav_data{"seriesId"};
        my $series_title = $series_nav_data{"title"};
        my $series_order = $series_nav_data{"order"};

        $series_title = sanitize($series_title);

        if ( defined $series_id && defined $series_title && defined $series_order ) {
            push @manga_data, (
                "series_id:$series_id",
                "series_title:$series_title",
                "series_order:$series_order",
            )
        }
    }

    return @manga_data;
}

sub get_pixiv_tags_from_dto {

    my ( $dto, $tag_languages_str ) = @_;
    my @tags;

    # extract tag languages.
    my @tag_languages;
    if ( $tag_languages_str eq "" ) {
        push @tag_languages, "jp";
    } else {
        @tag_languages = split(/,/, $tag_languages_str);
        for (@tag_languages) {
            s/^\s+//;
            s/\s+$//;
        }
    }

    foreach my $item ( @{$dto -> {"tags"} -> {"tags"}} ) {
            
        # iterate over tagging language.
        foreach my $tag_language ( @tag_languages ) {

            if ($tag_language eq 'jp') {
                # add original/jp tags.
                my $orig_tag = $item -> {"tag"};
                $orig_tag = sanitize($orig_tag);
                push @tags, $orig_tag;

            } 
            else {
                # add translated tags.
                my $translated_tag = $item -> {"translation"} -> { $tag_language };
                $translated_tag = sanitize($translated_tag);
                push @tags, $translated_tag;
            }
        }
    }

    return @tags;
}

sub get_hash_metadata_from_json {

    my ( $json, $illust_id, $tag_languages_str ) = @_;
    my $logger = get_plugin_logger();
    my %hashdata;

    # get illustration metadata.
    my %illust_dto = get_illustration_dto_from_json($json, $illust_id);
    my @lrr_tags;

    my @manga_data = get_manga_data_from_dto( \$illust_dto );
    my @pixiv_tags = get_pixiv_tags_from_dto( \$illust_dto, $tag_languages_str );
    push (@lrr_tags, @manga_data);
    push (@lrr_tags, @pixiv_tags);

    # add source
    my $source = "https://pixiv.net/artworks/$illust_id";

    push @lrr_tags, "source:$source";

    # add general metadata.
    my $user_id = $illust_dto{"userId"};
    my $user_name = $illust_dto{"userName"};
    $user_name = sanitize($user_name);

    push @lrr_tags, ("user_id:$user_id", "artist:$user_name");

    # add time-based metadata.
    my $create_date = $illust_dto{"createDate"};
    my $upload_date = $illust_dto{"uploadDate"};
    $create_date =~ s/(\+\d{2}:\d{2})$//;
    $upload_date =~ s/(\+\d{2}:\d{2})$//;
    my $create_date_epoch = Time::Piece -> strptime( $create_date, "%Y-%m-%dT%H:%M:%S" ) -> epoch;
    my $upload_date_epoch = Time::Piece -> strptime( $upload_date, "%Y-%m-%dT%H:%M:%S" ) -> epoch;

    push @lrr_tags, ("date_created:$create_date_epoch", "date_uploaded:$upload_date_epoch");

    $hashdata{lrr_tags} = join( ', ', @lrr_tags );

    # change title.
    my $illust_title = $illust_dto{"illustTitle"};
    $illust_title = sanitize($illust_title);
    $hashdata{title} = $illust_title;

    return %hashdata;

}

sub get_json_from_html {

    my ( $html ) = @_;
    my $logger = get_plugin_logger();

    # get 'content' body.
    my $dom = Mojo::DOM -> new($html);
    my $jsonstring = $dom -> at('meta#meta-preload-data') -> attr('content');
    
    # my $jsonstring = "{}";
    # if ( $html =~ /<meta name="preload-data" id="meta-preload-data" content='(.*?)'>/ ) {
    #     $jsonstring = $1;
    # }
    
    $logger -> debug("Tentative JSON: $jsonstring");
    my $json = decode_json $jsonstring;
    return $json;

}

sub get_html_from_illust_id {

    my ( $illust_id, $ua ) = @_;
    my $logger = get_plugin_logger();

    # illustration ID to URL.
    my $URL = "https://www.pixiv.net/en/artworks/$illust_id/";

    while (1) {

        my $res = $ua -> get (
            $URL => {
                Referer => "https://www.pixiv.net"
            }
        ) -> result;
        my $code = $res -> code;
        $logger -> debug("Received code $code.");

        # handle 3xx.
        if ( $code == 301 ) {
            $URL = $res -> headers -> location;
            $logger -> debug("Redirecting to $URL");
            next;
        }
        if ( $code == 302 ) {
            my $location = $res -> headers -> location;
            $URL = "pixiv.net$location";
            $logger -> debug("Redirecting to $URL");
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