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
        description => "Handles login to fakku.",
        parameters  => [ { type => "string", desc => "fakku_sid cookie value" }, { type => "string", desc => 'Useragent value' } ]
    );

}

sub do_login {

    shift;
    my ( $fakku_sid, $useragent ) = @_;

    my $logger = get_logger( "Fakku Login", "plugins" );
    my $ua     = Mojo::UserAgent->new;

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

        $ua->transactor->name($useragent);
    } else {
        $logger->info("No cookies provided, returning blank UserAgent.");
    }

    return $ua;
}
1;
