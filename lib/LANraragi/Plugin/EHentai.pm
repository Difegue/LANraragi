package LANraragi::Plugin::EHentai;

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
use LANraragi::Plugin::ExHentai;

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "E-Hentai",
        type        => "metadata",
        namespace   => "ehplugin",
        author      => "Difegue",
        version     => "2.0",
        description => "Searches g.e-hentai for tags matching your archive. <br/>If you have an account that can access exhentai.org, adding the credentials here will make more archives available for parsing.",
        parameters  => (
            "Default language to use in searches <br/>(This will be overwritten if your archive has a language tag set)" => "string",
            "E-Hentai Username (used for ExHentai access)" => "string",
            "E-Hentai Password (used for ExHentai access)" => "string",
            "ADVANCED: You can use the cookie values below instead of a username/password. <br/>ipb_member_id cookie" => "string",
            "ipb_pass_hash cookie" => "string"
        ),
        oneshot_arg => "E-H Gallery URL (Will attach tags matching this exact gallery to your archive)"
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    # LRR gives your plugin the recorded title/tags/thumbnail hash for the file,
    # the filesystem path, and the custom arguments at the end if available.
    shift;
    my ( $title, $tags, $thumbhash, $file, $oneshotarg, @args ) = @_;

    # Use the logger to output status - they'll be passed to a specialized logfile and written to STDOUT.
    my $logger = LANraragi::Utils::Generic::get_logger( "E-Hentai", "plugins" );

    # Work your magic here - You can create subroutines below to organize the code better
    my $gID    = "";
    my $gToken = "";

    # Quick regex to get the E-H archive ids from the provided url.
    if ( $oneshotarg =~ /.*\/g\/([0-9]*)\/([0-z]*)\/*.*/ ) {
        $gID    = $1;
        $gToken = $2;
    }
    else {
        # Craft URL for Text Search on EH if there's no user argument
        ( $gID, $gToken ) =
          &lookup_by_title( $title, $tags, $thumbhash, @args );
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
    }
    else {
        $logger->debug("EH API Tokens are $gID / $gToken");
    }

    my $newtags = &get_tags_from_EH( $gID, $gToken );

    #Return a hash containing the new metadata - it will be integrated in LRR.
    return ( tags => $newtags );
}

######
## EH Specific Methods
######

sub lookup_by_title {

    my ( $title, $tags, $thumbhash, @args ) = @_;

    my $defaultlanguage = $args[0];
    my $exh_username    = $args[1];
    my $exh_pass        = $args[2];
    my $ipb_member_id   = $args[3];
    my $ipb_pass_hash   = $args[4];
    my $logger          = LANraragi::Utils::Generic::get_logger( "E-Hentai", "plugins" );
    my $URL             = "";

    # Try logging in to exhentai, fallback naturally to e-h if we can't
    my ( $ua, $domain ) = LANraragi::Plugin::ExHentai::get_user_agent($ipb_member_id, $ipb_pass_hash, $exh_username, $exh_pass);
    
    #Thumbnail reverse image search
    if ( $thumbhash ne "" ) {

        $logger->info("Reverse Image Search Enabled, trying first.");

        #search with image SHA hash
        $URL = $domain
          . "?f_shash=". $thumbhash
          . "&fs_covers=1&fs_similar=1";

        $logger->debug("Using URL $URL (archive thumbnail hash)");

        my ( $gId, $gToken ) = &ehentai_parse( $URL, $ua );

        if ( $gId ne "" && $gToken ne "" ) {
            return ( $gId, $gToken );
        }
    }

    #Regular text search
    $URL =
        $domain
      . "?advsearch=1&f_sname=on&f_stags=on&f_spf=&f_spt=&f_sft=on"
      . "&f_search="
      . uri_escape_utf8($title);

    #Get the language tag, if it exists.
    if ( $tags =~ /.*language:\s?([^,]*),*.*/gi ) {
        $URL = $URL . "+" . uri_escape_utf8("language:$1");
    }
    elsif ( $defaultlanguage ne "" ) {
            $URL = $URL . "+" . uri_escape_utf8("language:$defaultlanguage");
    }

    #Same for artist tag
    if ( $tags =~ /.*artist:\s?([^,]*),*.*/gi ) {
        $URL = $URL . "+" . uri_escape_utf8("artist:$1");
    }

    $logger->debug("Using URL $URL (archive title)");

    return &ehentai_parse( $URL, $ua );
}

# ehentai_parse(URL, UA)
# Performs a remote search on e- or exhentai, and builds the matching JSON to send to the API for data.
sub ehentai_parse() {

    my $URL = $_[0];
    my $ua  = $_[1];

    my $response = $ua->max_redirects(5)->get($URL)->result;
    my $content  = $response->body;

    if ( index( $content, "Your IP address has been" ) != -1 ) {
        return ( "", "Temporarily banned from EH for excessive pageloads." );
    }

    my $gID    = "";
    my $gToken = "";

    my $dom = Mojo::DOM->new( $content );

    eval {
        # Get the first row of the search results
        # The "glink" class is parented by a <a> tag containing the gallery link in href.
        # This works in Minimal, Minimal+ and Compact modes, which should be enough.
        my $firstgal = $dom->at(".glink")->parent->attr('href');

        # A EH link looks like xhentai.org/g/{gallery id}/{gallery token}
        my $url = ( split( 'hentai.org/g/', $firstgal ) )[1];
        my @values = ( split( '/', $url ) );

        $gID    = $values[0];
        $gToken = $values[1];
    };
    
    #Returning shit yo
    return ( $gID, $gToken );
}

# get_tags_from_EH(gID, gToken)
# Executes an e-hentai API request with the given JSON and returns
sub get_tags_from_EH {

    my $uri    = 'http://e-hentai.org/api.php';
    my $gID    = $_[0];
    my $gToken = $_[1];

    my $ua = Mojo::UserAgent->new;

    my $logger = LANraragi::Utils::Generic::get_logger( "E-Hentai", "plugins" );

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

        my $data = $jsonresponse->{"gmetadata"};
        my $tags = @$data[0]->{"tags"};

        my $return = join( ", ", @$tags );
        $logger->info("Sending the following tags to LRR: $return");
        return $return;
    }
    else {
        #if an error occurs(no tags available) return an empty string.
        return "";
    }
}

1;
