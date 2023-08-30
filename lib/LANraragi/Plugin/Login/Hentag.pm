package LANraragi::Plugin::Login::Hentag;

use strict;
use warnings;
no warnings 'uninitialized';

use Mojo::UserAgent;
use LANraragi::Utils::Logging qw(get_logger);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name      => "Hentag",
        type      => "login",
        namespace => "hentaglogin",
        author    => "Moort",
        version   => "1.0",
        description =>
          "Handles login to Hentag. If you have an account with contraversial content enabled, hentag online lookup can parse more archives",
        parameters => [
            { type => "int",    desc => "hx cookie value" },
            { type => "string", desc => "hu cookie value" },
        ]
    );

}

# Mandatory function to be implemented by your login plugin
# Returns a Mojo::UserAgent object only!
sub do_login {

    # Login plugins only receive the parameters entered by the user.
    shift;
    my ( $hx, $hu ) = @_;
    return get_user_agent( $hx, $hu );
}

# get_user_agent(ipb cookies)
# Try crafting a Mojo::UserAgent object that can access Hentag.
# Returns the UA object created.
sub get_user_agent {

    my ( $hx, $hu ) = @_;

    my $logger = get_logger( "Hentag Login", "plugins" );
    my $ua     = Mojo::UserAgent->new;

    if ( $hx ne "" && $hu ne "" ) {
        $logger->info("Cookies provided ($hx $hu)!");

        #Setup the needed cookies with both domains
        $ua->cookie_jar->add(
            Mojo::Cookie::Response->new(
                name   => 'hx',
                value  => $hx,
                domain => 'hentag.com',
                path   => '/'
            )
        );

        $ua->cookie_jar->add(
            Mojo::Cookie::Response->new(
                name   => 'hu',
                value  => $hu,
                domain => 'hentag.com',
                path   => '/'
            )
        );

    } else {
        $logger->info("No cookies provided, returning blank UserAgent.");
    }

    return $ua;

}

1;
