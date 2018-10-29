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

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name      => "E-Hentai",
        namespace => "ehplugin",
        author    => "Difegue",
        version   => "1.5",
        description =>
          "Searches g.e-hentai for tags matching your archive. <br/>"
          . "If you have an account that can access exhentai.org, adding the credentials here will make more archives available for parsing.",

#If your plugin uses/needs custom arguments, input their name here.
#This name will be displayed in plugin configuration next to an input box for global arguments, and in archive edition for one-shot arguments.
        oneshot_arg =>
"E-H Gallery URL (Will attach tags matching this exact gallery to your archive)",
        global_args => [
"Default language to use in searches <br/>(This will be overwritten if your archive has a language tag set)",
            "E-Hentai Username (used for ExHentai access)",
            "E-Hentai Password (used for ExHentai access)",
            "ADVANCED: ipb_member_id cookie <br/>(will override username/password access method)",
            "ADVANCED: ipb_pass_hash cookie <br/>(will override username/password access method)"
          ]

    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    #LRR gives your plugin the recorded title/tags/thumbnail hash for the file,
    #the filesystem path, and the custom arguments at the end if available.
    shift;
    my ( $title, $tags, $thumbhash, $file, $oneshotarg, @args ) = @_;

#Use the logger to output status - they'll be passed to a specialized logfile and written to STDOUT.
    my $logger = LANraragi::Utils::Generic::get_logger( "E-Hentai", "plugins" );

#Work your magic here - You can create subroutines below to organize the code better
    my $gID    = "";
    my $gToken = "";

    #Quick regex to get the E-H archive ids from the provided url.
    if ( $oneshotarg =~ /.*\/g\/([0-9]*)\/([0-z]*)\/*.*/ ) {
        $gID    = $1;
        $gToken = $2;
    }
    else {
        #Craft URL for Text Search on EH if there's no user argument
        ( $gID, $gToken ) =
          &lookup_by_title( $title, $tags, $thumbhash, @args );
    }

   #If an error occured, return a hash containing an error message.
   #LRR will display that error to the client.
   #Using the GToken to store error codes - not the cleanest but it's convenient
    if ( $gID eq "" ) {

        if ( $gToken eq "Banned" ) {
            $logger->error(
                "Temporarily banned from EH for excessive pageloads.");
            return ( error =>
                  "Temporarily banned from EH for excessive pageloads." );
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
 
    my $domain = "http://e-hentai.org/";
    my $ua     = Mojo::UserAgent->new;

    my $logger = LANraragi::Utils::Generic::get_logger( "E-Hentai", "plugins" );

    # Pre-emptively ignore the "yay" cookie if it gets added for some reason
    # fucking shit panda I hate this
    $ua->cookie_jar->ignore(
        sub {
            my $cookie = shift;
            return undef unless my $name = $cookie->name;
            return $name eq 'yay';
        }
    );

    if ($ipb_member_id ne "" && $ipb_pass_hash ne "") {
        #Try opening exhentai with the provided cookies.
        #An igneous cookie should automatically generate.
        $logger->info( "Exhentai cookies provided! Trying direct access.");
        ( $ua, $domain ) = &exhentai_cookie ($ua, $ipb_member_id, $ipb_pass_hash);

    } elsif ( $exh_username ne "" && $exh_pass ne "" ) {
        #Attempt a login through the e-hentai forums. 
        #If the account is legit, we should obtain EX access.
        $logger->info( "E-Hentai credentials present, trying to login as user "
              . $exh_username );
        ( $ua, $domain ) = &exhentai_login( $ua, $exh_username, $exh_pass );
    }

    my $URL = "";

    #Thumbnail reverse image search
    if ( $thumbhash ne "" ) {

        $logger->info("Reverse Image Search Enabled, trying first.");

        #search with image SHA hash
        $URL =
            $domain
          . "?f_doujinshi=1&f_manga=1&f_artistcg=1&f_gamecg=1&f_western=1&f_non-h=1&f_imageset=1&f_cosplay=1&f_asianporn=1&f_misc=1"
          . "&f_shash="
          . $thumbhash
          . "&fs_similar=1";

        $logger->debug("Using URL $URL (archive thumbnail hash)");

        my ( $gId, $gToken ) = &ehentai_parse( $URL, $ua );

        if ( $gId ne "" && $gToken ne "" ) {
            return ( $gId, $gToken );
        }
    }

    #Regular text search
    $URL =
        $domain
      . "?f_doujinshi=1&f_manga=1&f_artistcg=1&f_gamecg=1&f_western=1&f_non-h=1&f_imageset=1&f_cosplay=1&f_asianporn=1&f_misc=1"
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

#exhentai_cookie(userAgent, idCookie, passCookie)
#Try accessing exhentai directly with the provided cookie values.
#If successful, the domain used by the plugin is changed to exhentai.
sub exhentai_cookie {

    my ($ua, $ipb_member_id, $ipb_pass_hash) = @_;
    my $domain = "http://e-hentai.org";
    my $logger = LANraragi::Utils::Generic::get_logger( "ExHentai", "plugins" );
    
    #Setup the needed cookies with the e-hentai domain
    $ua->cookie_jar->add(
        Mojo::Cookie::Response->new(
            name   => 'ipb_member_id',
            value  => $ipb_member_id,
            domain => '.e-hentai.org',
            path   => '/'
        )
    );

    $ua->cookie_jar->add(
        Mojo::Cookie::Response->new(
            name   => 'ipb_pass_hash',
            value  => $ipb_pass_hash,
            domain => '.e-hentai.org',
            path   => '/'
        )
    );

    $logger->info("Trying to access ExHentai with provided cookies...");
    $domain = "http://exhentai.org" unless &check_panda($ua) == 0;

    #Return the updated UserAgent and the domain the rest of the plugin'll use
    return ( $ua, $domain );
}

#exhentai_login(userAgent, login, password)
#Attempt a login to the E-Hentai forums with the given credentials.
#If successful, the domain used by the plugin is changed to exhentai.
sub exhentai_login {

    my $ua           = $_[0];
    my $exh_username = $_[1];
    my $exh_pass     = $_[2];
    my $domain = "http://e-hentai.org";
    my $logger = LANraragi::Utils::Generic::get_logger( "ExHentai", "plugins" );

    $logger->debug(
        "Logging in with credentials: " . $exh_username . "/" . $exh_pass );

    my $loginresult = $ua->max_redirects(5)->post(
        'https://forums.e-hentai.org/index.php?act=Login&CODE=01' =>
          { Referer => 'https://e-hentai.org/bounce_login.php?b=d&bt=1-1' } =>
          form => {
            CookieDate       => "1",
            b                => "d",
            bt               => "1-1",
            UserName         => $exh_username,
            PassWord         => $exh_pass,
            ipb_login_submit => "Login!"
          }
    )->result->body;

    $logger->debug( "E-Hentai login response is " . $loginresult );

    if ( index( $loginresult, "You are now logged in as:" ) != -1 ) {

        $logger->info("Login successful! Trying to access ExHentai...");
        $domain = "http://exhentai.org" unless &check_panda($ua) == 0;
    }
    else {

        if ( index( $loginresult, "The captcha was not" ) != -1 ){
            $logger->info("Automatic login was blocked by a CAPTCHA request!".
                " Try logging in manually with this computer or another computer on the same network.");
        }
        $logger->info(
            "Couldn't login! ExHentai will not be used for this request.");
    }

    #Return the updated UserAgent and the domain the rest of the plugin'll use
    return ( $ua, $domain );
}

#check_panda(useragent)
#Try to access exhentai with the given useragent.
#Returns true (1) if access was successful.
sub check_panda() {

    my $ua = $_[0];
    my $logger = LANraragi::Utils::Generic::get_logger( "Panda Check", "plugins" );

    #The initial exhentai load will redirect a few times, tell mojo to follow them
    my $res = $ua->max_redirects(5)->get("https://exhentai.org")
        ->result;
    my $headers = $res->headers->to_string;
    $logger->debug( "Exhentai headers: " . $headers );

    #Since we ignore the yay cookie, we might only get an endless loop of yay-cookie setting responses.
    #We can also just get the panda if we have a fucked igneous cookie.
    if ( index( $headers, "sadpanda.jpg" ) != -1 || 
         index ($headers, "Set-Cookie: yay=louder;") != -1) {
        #oh no
        $logger->info(
            "Got a Sad Panda! ExHentai will not be used for this request.");
        return 0;    
    } else {
        $logger->info("ExHentai status OK! Moving on.");
        return 1;
    }
}

#eHentaiLookup(URL)
#Performs a remote search on e- or exhentai, and builds the matching JSON to send to the API for data.
sub ehentai_parse() {

    my $URL = $_[0];
    my $ua  = $_[1];

    my $response = $ua->max_redirects(5)->get($URL)->result;
    my $content  = $response->body;

    if ( index( $content, "Your IP address has been" ) != -1 ) {
        return ( "", "Banned" );
    }

    my $gID    = "";
    my $gToken = "";

 #now for the parsing of the HTML we obtained.
 #the first occurence of <tr class="gtr0"> matches the first row of the results.
 #If it doesn't exist, what we searched isn't on E-hentai.
    my @benis = split( '<tr class="gtr0">', $content );

#Inside that <tr>, we look for <div class="it5"> . the <a> tag inside has an href to the URL we want.
    my @final = split( '<div class="it5">', $benis[1] );

    my $url = ( split( 'hentai.org/g/', $final[1] ) )[1];

    my @values = ( split( '/', $url ) );

    $gID    = $values[0];
    $gToken = $values[1];

    #Returning shit yo
    return ( $gID, $gToken );
}

#getTagsFromEHAPI(gID, gToken)
#Executes an e-hentai API request with the given JSON and returns
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
