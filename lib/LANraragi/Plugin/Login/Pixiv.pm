package LANraragi::Plugin::Login::Pixiv;

use strict;
use warnings;
no warnings 'uninitialized';

use Mojo::UserAgent;
use LANraragi::Utils::Logging qw(get_logger);

#Meta-information about your plugin.
sub plugin_info {

    return (
		#Standard metadata
        name      => "Pixiv Login",
        type      => "login",
        namespace => "pixivlogin",
        author    => "psilabs-dev",
        version   => "0.1",
        description =>
          "Handles login to Pixiv. See https://github.com/Nandaka/PixivUtil2/wiki for how to obtain the cookie.",
        parameters => [
            { type => "string", desc => "Browser UserAgent (Default is 'Mozilla/5.0')" },
			{ type => "string", desc => "Cookie (PHP session ID)" }
        ]
    );

}


# Mandatory function to be implemented by your login plugin
# Returns a Mojo::UserAgent object only!
sub do_login {

    # Login plugins only receive the parameters entered by the user.
    shift;
    my ( $useragent, $php_session_id ) = @_;
    return get_user_agent( $useragent, $php_session_id );
}

# Returns the UA object created.
sub get_user_agent {

    my ( $useragent, $php_session_id ) = @_;

    # assign default user agent.
    if ( $useragent eq '' ) {
        $useragent = "Mozilla/5.0";
    }

    my $logger  = get_logger( "Pixiv Login", "plugins" );
    my $ua      = Mojo::UserAgent -> new;

    if ( $useragent ne "" && $php_session_id ne "") {

        # assign user agent.
        $ua -> transactor -> name($useragent);

        # add cookie
        $ua -> cookie_jar -> add(
            Mojo::Cookie::Response -> new(
                name    =>  "PHPSESSID",
                value   =>  $php_session_id,
                domain  =>  'pixiv.net',
                path    =>  '/'
            )
        )

    } else {
        $logger -> info("No cookies provided, returning blank UserAgent.");
    }

    return $ua;

}

1;