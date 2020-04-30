package LANraragi::Plugin::Metadata::EHentai;

use strict;
use warnings;
no warnings 'uninitialized';

#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use URI::Escape;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::UserAgent;

#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_logger);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "E-Hentai",
        type        => "metadata",
        namespace   => "ehplugin",
        login_from  => "ehlogin",
        author      => "Difegue and others",
        version     => "2.5",
        description => "Searches g.e-hentai for tags matching your archive.",
        icon =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAABmJLR0QA/wD/AP+gvaeTAAAACXBI\nWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH4wYBFg0JvyFIYgAAAB1pVFh0Q29tbWVudAAAAAAAQ3Jl\nYXRlZCB3aXRoIEdJTVBkLmUHAAAEo0lEQVQ4y02UPWhT7RvGf8/5yMkxMU2NKaYIFtKAHxWloYNU\ncRDeQTsUFPwAFwUHByu4ODq4Oghdiri8UIrooCC0Lx01ONSKfYOioi1WpWmaxtTm5PTkfNzv0H/D\n/9oeePjdPNd13Y8aHR2VR48eEUURpmmiaRqmaXbOAK7r4vs+IsLk5CSTk5P4vo9hGIgIsViMra0t\nCoUCRi6XY8+ePVSrVTRN61yybZuXL1/y7t078vk8mUyGvXv3cuLECWZnZ1lbW6PdbpNIJHAcB8uy\nePr0KYZlWTSbTRKJBLquo5TCMAwmJia4f/8+Sini8Ti1Wo0oikin09i2TbPZJJPJUK/XefDgAefO\nnWNlZQVD0zSUUvi+TxAE6LqOrut8/fqVTCaDbdvkcjk0TSOdTrOysoLrujiOw+bmJmEYMjAwQLVa\nJZVKYXR1ddFut/F9H9M0MU0T3/dZXV3FdV36+/vp7u7m6NGj7Nq1i0qlwuLiIqVSib6+Pubn5wGw\nbZtYLIaxMymVSuH7PpZlEUURSina7TZBEOD7Pp8/fyYMQ3zfZ25ujv3795NOp3n48CE9PT3ouk4Q\nBBi/fv3Ctm0cx6Grq4utrS26u7sREQzDIIoifv78SU9PD5VKhTAMGRoaYnV1leHhYa5evUoQBIRh\niIigiQhRFKHrOs1mE9u2iaKIkydPYhgGAKZp8v79e+LxOPl8Htd1uXbtGrdv3yYMQ3ZyAODFixeb\nrVZLvn//Lq7rSqVSkfX1dREROXz4sBw/flyUUjI6OipXrlyRQ4cOSbPZlCiKxHVdCcNQHMcRz/PE\ndV0BGL53756sra1JrVaT9fV1cRxHRESGhoakr69PUqmUvHr1SsrlsuzI931ptVriuq78+fNHPM+T\nVqslhoikjh075p09e9ba6aKu6/T39zM4OMjS0hIzMzM0Gg12794N0LEIwPd9YrEYrusShiEK4Nmz\nZ41yudyVy+XI5/MMDAyQzWap1+tks1lEhIWFBQqFArZto5QiCAJc1+14t7m5STweRwOo1WoSBAEj\nIyMUi0WSySQiQiqV6lRoYWGhY3673e7sfRAEiAjZbBbHcbaBb9++5cCBA2SzWZLJJLZt43kesViM\nHX379g1d1wnDsNNVEQEgCAIajQZ3797dBi4tLWGaJq7rYpompVKJmZkZ2u12B3j58mWUUmiahoiw\nsbFBEASdD2VsbIwnT55gACil+PHjB7Ozs0xPT/P7929u3ryJZVmEYUgYhhQKBZRSiAie52EYBkop\nLMvi8ePHTE1NUSwWt0OZn5/3hoeHzRs3bqhcLseXL1+YmJjowGzbRtO07RT/F8jO09+8ecP58+dJ\nJBKcPn0abW5uThWLRevOnTv/Li4u8vr1a3p7e9E0jXg8zsePHymVSnz69Kmzr7quY9s2U1NTXLp0\nCc/zOHLkCPv27UPxf6rX63+NjIz8IyKMj48zPT3NwYMHGRwcpLe3FwARodVqcf36dS5evMj4+DhB\nEHDmzBkymQz6DqxSqZDNZr8tLy//DYzdunWL5eVlqtUqHz58IJVKkUwmaTQalMtlLly4gIjw/Plz\nTp06RT6fZ2Njg/8AqMV7tO07rnsAAAAASUVORK5CYII=",
        parameters => [
            { type => "string", desc => "Forced language to use in searches" },
            { type => "bool",   desc => "Save archive title" },
            { type => "bool",   desc => "Fetch using thumbnail first (falls back to title)" },
            { type => "bool",   desc => "Use ExHentai (enable to search for fjorded content without star cookie)" },
            {   type => "bool",
                desc => "Save the original Japanese title when available instead of the English or " . "romanised title"
            },
            { type => "bool", desc => "Fetch additional timestamp (time posted) and uploader metadata" },
            { type => "bool", desc => "Search expunged galleries as well" },

        ],
        oneshot_arg => "E-H Gallery URL (Will attach tags matching this exact gallery to your archive)"
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;    # Global info hash
    my ( $lang, $savetitle, $usethumbs, $enablepanda, $jpntitle, $additionaltags, $expunged ) = @_;    # Plugin parameters

    # Use the logger to output status - they'll be passed to a specialized logfile and written to STDOUT.
    my $logger = get_logger( "E-Hentai", "plugins" );

    # Work your magic here - You can create subroutines below to organize the code better
    my $gID    = "";
    my $gToken = "";
    my $domain = ( $enablepanda ? 'https://exhentai.org' : 'https://e-hentai.org' );

    # Quick regex to get the E-H archive ids from the provided url or source tag
    if ( $lrr_info->{oneshot_param} =~ /.*\/g\/([0-9]*)\/([0-z]*)\/*.*/ ) {
        $gID    = $1;
        $gToken = $2;
        $logger->debug("Skipping search and using gallery $gID / $gToken from oneshot args");
    } elsif ( $lrr_info->{existing_tags} =~ /.*source:e(?:x|-)hentai\.org\/g\/([0-9]*)\/([0-z]*)\/*.*/gi ) {
        $gID    = $1;
        $gToken = $2;
        $logger->debug("Skipping search and using gallery $gID / $gToken from source tag");
    } else {

        # Craft URL for Text Search on EH if there's no user argument
        ( $gID, $gToken ) = &lookup_gallery(
            $lrr_info->{archive_title},
            $lrr_info->{existing_tags},
            $lrr_info->{thumbnail_hash},
            $lrr_info->{user_agent},
            $domain, $lang, $usethumbs, $expunged
        );
    }

    # If an error occured, return a hash containing an error message.
    # LRR will display that error to the client.
    # Using the GToken to store error codes - not the cleanest but it's convenient
    if ( $gID eq "" ) {

        if ( $gToken ne "" ) {
            $logger->error($gToken);
            return ( error => $gToken );
        }

        $logger->info("No matching EH Gallery Found!");
        return ( error => "No matching EH Gallery Found!" );
    } else {
        $logger->debug("EH API Tokens are $gID / $gToken");
    }

    my ( $ehtags, $ehtitle ) = &get_tags_from_EH( $gID, $gToken, $jpntitle, $additionaltags );
    my %hashdata = ( tags => $ehtags );

    # Add source URL and title if possible
    if ( $hashdata{tags} ne "" ) {

        $hashdata{tags} .= ", source:" . ( split( '://', $domain ) )[1] . "/g/$gID/$gToken";
        if ($savetitle) { $hashdata{title} = $ehtitle; }
    }

    #Return a hash containing the new metadata - it will be integrated in LRR.
    return %hashdata;
}

######
## EH Specific Methods
######

sub lookup_gallery {

    my ( $title, $tags, $thumbhash, $ua, $domain, $defaultlanguage, $usethumbs, $expunged ) = @_;
    my $logger = get_logger( "E-Hentai", "plugins" );
    my $URL    = "";

    #Thumbnail reverse image search
    if ( $thumbhash ne "" && $usethumbs ) {

        $logger->info("Reverse Image Search Enabled, trying now.");

        #search with image SHA hash
        $URL =
            $domain
          . "?advsearch=1&f_sname=on&f_stags=on&f_sdt2=on&f_spf=&f_spt=&f_sfu=on&f_sft=on&f_sfl=on&f_shash="
          . $thumbhash
          . "&fs_covers=1&fs_similar=1";

        #Include expunged galleries in the search if the option is enabled.
        if ($expunged) {
            $URL = $URL . "&fs_exp=1";
        }

        #Add the language override, if it's defined.
        if ( $defaultlanguage ne "" ) {
            $URL = $URL . "&f_search=" . uri_escape_utf8("language:$defaultlanguage");
        }

        $logger->debug("Using URL $URL (archive thumbnail hash)");

        my ( $gId, $gToken ) = &ehentai_parse( $URL, $ua );

        if ( $gId ne "" && $gToken ne "" ) {
            return ( $gId, $gToken );
        }
    }

    #Regular text search
    $URL =
        $domain
      . "?advsearch=1&f_sname=on&f_stags=on&f_sdt2=on&f_spf=&f_spt=&f_sfu=on&f_sft=on&f_sfl=on"
      . "&f_search="
      . uri_escape_utf8( qw(") . $title . qw(") );

    #Include expunged galleries in the search if the option is enabled.
    if ($expunged) {
        $URL = $URL . "&f_sh=on";
    }

    #Add the language override, if it's defined.
    if ( $defaultlanguage ne "" ) {
        $URL = $URL . "+" . uri_escape_utf8("language:$defaultlanguage");
    }

    #Add artist tag from the OG tags if it exists
    if ( $tags =~ /.*artist:\s?([^,]*),*.*/gi ) {
        $URL = $URL . "+" . uri_escape_utf8("artist:$1");
    }

    $logger->debug("Using URL $URL (archive title)");
    return &ehentai_parse( $URL, $ua );
}

# ehentai_parse(URL, UA)
# Performs a remote search on e- or exhentai, and returns the ID/token matching the found gallery.
sub ehentai_parse() {

    my $URL    = $_[0];
    my $ua     = $_[1];
    my $logger = get_logger( "E-Hentai", "plugins" );

    my $response = $ua->max_redirects(5)->get($URL)->result;
    my $content  = $response->body;

    if ( index( $content, "Your IP address has been" ) != -1 ) {
        return ( "", "Temporarily banned from EH for excessive pageloads." );
    }

    my $gID    = "";
    my $gToken = "";

    my $dom = Mojo::DOM->new($content);

    eval {
        # Get the first row of the search results
        # The "glink" class is parented by a <a> tag containing the gallery link in href.
        # This works in Minimal, Minimal+ and Compact modes, which should be enough.
        my $firstgal = $dom->at(".glink")->parent->attr('href');

        # A EH link looks like xhentai.org/g/{gallery id}/{gallery token}
        my $url    = ( split( 'hentai.org/g/', $firstgal ) )[1];
        my @values = ( split( '/',             $url ) );

        $gID    = $values[0];
        $gToken = $values[1];
    };

    if ( index( $content, "You are opening" ) != -1 ) {
        my $rand = 15 + int( rand( 51 - 15 ) );
        $logger->info("Sleeping for $rand seconds due to EH excessive requests warning");
        sleep($rand);
    }

    #Returning shit yo
    return ( $gID, $gToken );
}

# get_tags_from_EH(gID, gToken, jpntitle, additionaltags)
# Executes an e-hentai API request with the given JSON and returns tags and title.
sub get_tags_from_EH {

    my ( $gID, $gToken, $jpntitle, $additionaltags ) = @_;
    my $uri = 'https://e-hentai.org/api.php';

    my $ua = Mojo::UserAgent->new;

    my $logger = get_logger( "E-Hentai", "plugins" );

    #Execute the request
    my $rep = $ua->post(
        $uri => json => {
            method    => "gdata",
            gidlist   => [ [ $gID, $gToken ] ],
            namespace => 1
        }
    )->result;

    my $jsonresponse = $rep->json;
    my $textrep      = $rep->body;
    $logger->debug("E-H API returned this JSON: $textrep");

    unless ( exists $jsonresponse->{"error"} ) {

        my $data    = $jsonresponse->{"gmetadata"};
        my $tags    = @$data[0]->{"tags"};
        my $ehtitle = @$data[0]->{ ( $jpntitle ? "title_jpn" : "title" ) };
        if ( $ehtitle eq "" && $jpntitle ) {
            $ehtitle = @$data[0]->{"title"};
        }
        my $ehcat = lc @$data[0]->{"category"};

        my $ehtags = join( ", ", @$tags );
        $ehtags = $ehtags . ", category:" . $ehcat;
        if ($additionaltags) {
            my $ehuploader  = @$data[0]->{"uploader"};
            my $ehtimestamp = @$data[0]->{"posted"};
            $ehtags = $ehtags . ", uploader:" . $ehuploader . ", timestamp:" . $ehtimestamp;
        }

        $logger->info("Sending the following tags to LRR: $ehtags");
        return ( $ehtags, $ehtitle );
    } else {

        #if an error occurs(no tags available) return empty strings.
        return ( "", "" );
    }
}

1;
