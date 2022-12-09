package LANraragi::Plugin::Login::EHentai;

use strict;
use warnings;
no warnings 'uninitialized';

use Mojo::UserAgent;
use LANraragi::Utils::Logging qw(get_logger);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name      => "E-Hentai",
        type      => "login",
        namespace => "ehlogin",
        author    => "Difegue",
        version   => "2.3",
        description =>
          "Handles login to E-H. If you have an account that can access fjorded content or exhentai, adding the credentials here will make more archives available for parsing.",
        parameters => [
            { type => "int",    desc => "ipb_member_id cookie" },
            { type => "string", desc => "ipb_pass_hash cookie" },
            { type => "string", desc => "star cookie (optional, if present you can view fjorded content without exhentai)" },
            { type => "string", desc => "igneous cookie(optional, if present you can view exhentai outside Europe and America)" }
        ]
    );

}

# Mandatory function to be implemented by your login plugin
# Returns a Mojo::UserAgent object only!
sub do_login {

    # Login plugins only receive the parameters entered by the user.
    shift;
    my ( $ipb_member_id, $ipb_pass_hash, $star ,$igneous ) = @_;
    return get_user_agent( $ipb_member_id, $ipb_pass_hash, $star ,$igneous );
}

# get_user_agent(ipb cookies)
# Try crafting a Mojo::UserAgent object that can access E-Hentai.
# Returns the UA object created.
sub get_user_agent {

    my ( $ipb_member_id, $ipb_pass_hash, $star, $igneous ) = @_;

    my $logger = get_logger( "E-Hentai Login", "plugins" );
    my $ua     = Mojo::UserAgent->new;

    if ( $ipb_member_id ne "" && $ipb_pass_hash ne "" ) {
        $logger->info("Cookies provided ($ipb_member_id $ipb_pass_hash $star $igneous)!");

        #Setup the needed cookies with both domains
        #They should translate to exhentai cookies with the igneous value generated
        $ua->cookie_jar->add(
            Mojo::Cookie::Response->new(
                name   => 'ipb_member_id',
                value  => $ipb_member_id,
                domain => 'exhentai.org',
                path   => '/'
            )
        );

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
                domain => 'exhentai.org',
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
                name   => 'star',
                value  => $star,
                domain => 'exhentai.org',
                path   => '/'
            )
        );

        $ua->cookie_jar->add(
            Mojo::Cookie::Response->new(
                name   => 'igneous',
                value  => $igneous,
                domain => 'exhentai.org',
                path   => '/'
            )
        );
        

        $ua->cookie_jar->add(
            Mojo::Cookie::Response->new(
                name   => 'star',
                value  => $star,
                domain => 'e-hentai.org',
                path   => '/'
            )
        );

        $ua->cookie_jar->add(
            Mojo::Cookie::Response->new(
                name   => 'igneous',
                value  => $igneous,
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
    } else {
        $logger->info("No cookies provided, returning blank UserAgent.");
    }

    return $ua;

}

1;