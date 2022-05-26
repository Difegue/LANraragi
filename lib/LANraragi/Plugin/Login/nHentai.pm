package LANraragi::Plugin::Login::nHentai;

use strict;
use warnings;
no warnings 'uninitialized';

use Mojo::UserAgent;
use LANraragi::Utils::Logging qw(get_logger);

#Meta-information about your plugin.
sub plugin_info {

    return (
		#Standard metadata
        name      => "nHentai CF Bypass",
        type      => "login",
        namespace => "nhentaicfbypass",
        author    => "Pheromir",
        version   => "0.1",
        description =>
          "Bypasses the Cloudflare Javascript-challenge by re-using cookies from your browser. Both CF cookies and the user-agent must originate from the same webbrowser.",
        parameters => [
              { type => "string", desc => "Browser UserAgent string (Can be found at http://useragentstring.com/ for your browser)" },
			{ type => "string", desc => "csrftoken cookie for domain nhentai.net" },
			{ type => "string", desc => "cf_clearance cookie for domain nhentai.net" }
        ]
    );

}


# Mandatory function to be implemented by your login plugin
# Returns a Mojo::UserAgent object only!
sub do_login {

    # Login plugins only receive the parameters entered by the user.
    shift;
    my ( $useragent, $csrftoken, $cf_clearance ) = @_;
    return get_user_agent( $useragent, $csrftoken, $cf_clearance );
}

# get_user_agent(useragent, cf cookies)
# Try crafting a Mojo::UserAgent object that can access nHentai.
# Returns the UA object created.
sub get_user_agent {

    my ( $useragent, $csrftoken, $cf_clearance ) = @_;

    my $logger = get_logger( "nHentai Cloudflare Bypass", "plugins" );
    my $ua     = Mojo::UserAgent->new;

    if ( $useragent ne "" && $csrftoken ne "" && $cf_clearance ne "") {
        $logger->info("Useragent and Cookies provided ($useragent $csrftoken $cf_clearance)!");
        $ua->transactor->name($useragent);

        #Setup the needed cookies
        $ua->cookie_jar->add(
            Mojo::Cookie::Response->new(
                name   => 'csrftoken',
                value  => $csrftoken,
                domain => 'nhentai.net',
                path   => '/'
            )
        );

        $ua->cookie_jar->add(
            Mojo::Cookie::Response->new(
                name   => 'cf_clearance',
                value  => $cf_clearance,
                domain => 'nhentai.net',
                path   => '/'
            )
        );

    } else {
        $logger->info("No cookies provided, returning blank UserAgent.");
    }

    return $ua;

}

1;