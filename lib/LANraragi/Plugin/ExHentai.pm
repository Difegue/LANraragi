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
