package LANraragi::Plugin::ExHentai;

use strict;
use warnings;

use URI::Escape;
use Mojo::UserAgent;

use LANraragi::Utils::Generic;

# Subpackage of LANraragi::Plugin::EHentai, handles sadpanda logins. This is not a plugin!
# This can also be used by other plugins if necessary. (e.g for downloaders)

# get_user_agent(ipb cookies, ehentai logins)
# Try crafting a Mojo::UserAgent object that can access Exhentai.
# Returns the UA object created, alongside the domainname it can access. (e-h or ex)
sub get_user_agent {

    my ($ipb_member_id, $ipb_pass_hash, $exh_username, $exh_pass) = @_;

    my $logger = LANraragi::Utils::Generic::get_logger( "ExHentai", "plugins" );
    my $domain = "http://e-hentai.org/";
    my $ua = Mojo::UserAgent->new;

    # Pre-emptively ignore the "yay" cookie if it gets added for some reason
    # fucking shit panda I hate this
    $ua->cookie_jar->ignore(
        sub {
            my $cookie = shift;
            return 0 unless my $name = $cookie->name;
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

    return ($ua, $domain);

}

#exhentai_cookie(userAgent, idCookie, passCookie)
#Try accessing exhentai directly with the provided cookie values.
#If successful, the domain used by the plugin is changed to exhentai.
sub exhentai_cookie {

    my ($ua, $ipb_member_id, $ipb_pass_hash) = @_;
    my $domain = "http://e-hentai.org";
    my $logger = LANraragi::Utils::Generic::get_logger( "ExHentai", "plugins" );
    
    #Setup the needed cookies with the e-hentai domain
    #They should translate to exhentai cookies with the igneous value generated
    $ua->cookie_jar->add(
        Mojo::Cookie::Response->new(
            name   => 'ipb_member_id',
            value  => $ipb_member_id,
            domain => 'e-hentai.org',
            path   => '/'
        )
    );

    $ua->cookie_jar->add(
        Mojo::Cookie::Response->new(
            name   => 'ipb_pass_hash',
            value  => $ipb_pass_hash,
            domain => 'e-hentai.org',
            path   => '/'
        )
    );

    $ua->cookie_jar->add(
        Mojo::Cookie::Response->new(
            name   => 'ipb_coppa',
            value  => '0',
            domain => 'forums.e-hentai.org',
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

    my ($ua, $exh_username, $exh_pass) = @_;
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

    #$logger->debug( "E-Hentai login response is " . $loginresult );

    if ( index( $loginresult, "You are now logged in as:" ) != -1 ) {

        $logger->info("Login successful! Trying to access ExHentai...");
        $domain = "http://exhentai.org" unless &check_panda($ua) == 0;
    }
    else {

        if ( index( $loginresult, "The captcha was not" ) != -1 ){
            $logger->info("Automatic login was blocked by a CAPTCHA request!".
                " Try logging in manually with this computer or another computer on the same network.".
                " If that fails, you can try configuring the plugin with ipb_* cookies instead.");
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

    #Since we ignore the yay cookie, we might only get an endless loop of yay-cookie setting responses instead of the panda.
    #We can also get a fucked igneous cookie if the account is banned.
    if ( index ($headers, "Set-Cookie: yay=louder;") != -1 ||
         index ($headers, "igneous=mystery") != -1) {
        #oh no
        $logger->info(
            "Got a Sad Panda! ExHentai will not be used for this request.");
        return 0;    
    } else {
        $logger->info("ExHentai status OK! Moving on.");
        return 1;
    }
}

1;
