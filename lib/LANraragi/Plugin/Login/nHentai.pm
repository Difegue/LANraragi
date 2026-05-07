package LANraragi::Plugin::Login::nHentai;

use v5.38;

use Mojo::UserAgent;

use LANraragi::Utils::Generic qw(get_version);
use LANraragi::Utils::Logging qw(get_logger);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "nHentai",
        type        => "login",
        namespace   => "nhapiauth",
        author      => "Guerra24",
        version     => "1.0",
        description => "Authenticates the nHentai API using an API Key. You can generate one in your profile's settings.",
        parameters  => [
            { type => "string", desc => "API Key" }
        ]
    );

}

# Mandatory function to be implemented by your login plugin
# Returns a Mojo::UserAgent object only!
sub do_login {
    # Login plugins only receive the parameters entered by the user.
    shift;
    my ( $key ) = @_;

    my $logger = get_logger( "nHentai API Auth", "plugins" );
    my $ua     = Mojo::UserAgent->new;

    my $version_info = get_version;
    my $version = $version_info->{version};
    my $homepage = $version_info->{homepage};
    $ua->transactor->name("LANraragi/$version (+$homepage)");

    if ( $key ) {

        $logger->info("API Key provided ($key)!");

        $ua->on(start => sub ($ua, $tx) {
            $tx->req->headers->header("Authorization" => "Key $key");
        });

    } else {
        $logger->info("No API Key provided");
    }

    return $ua;
}

1;