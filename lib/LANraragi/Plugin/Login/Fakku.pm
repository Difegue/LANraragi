package LANraragi::Plugin::Login::Fakku;

use strict;
use warnings;
no warnings 'uninitialized';

use Mojo::UserAgent;
use LANraragi::Utils::Logging qw(get_logger);

sub plugin_info {

    return (
        name        => "Fakku",
        type        => "login",
        namespace   => "fakkulogin",
        author      => "Nodja, Nixis198",
        version     => "0.2",
        description =>
          "Handles login to FAKKU. If the FAKKU metadata plugin stops working, update your 'fakku_sid' cookie and add your own Useragent.",
        parameters => [ { type => "string", desc => "fakku_sid cookie value" }, { type => "string", desc => 'Useragent value' } ]
    );

}

sub do_login {

    shift;
    my ( $fakku_sid, $useragentcustom ) = @_;

    my $useragent;
    my $useragentdefault =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';

    my $logger = get_logger( "Fakku Login", "plugins" );
    my $ua     = Mojo::UserAgent->new;

    # If the user didn't provide a useragent use the default one
    if ( $useragentcustom eq "" ) {
        $useragent = $useragentdefault;
    } else {
        $useragent = $useragentcustom;
    }

    if ( $fakku_sid ne "" && $useragent ne "" ) {
        $logger->info("Cookie provided ($fakku_sid)!");
        $ua->cookie_jar->add(
            Mojo::Cookie::Response->new(
                name   => 'fakku_sid',
                value  => $fakku_sid,
                domain => 'fakku.net',
                path   => '/'
            )
        );

        $logger->debug("Using Useragent: ($useragent)!");
        $ua->transactor->name($useragent);
    } else {
        $logger->info("No cookies provided, returning blank UserAgent.");
    }

    return $ua;
}
1;
