package LANraragi::Plugin::Download::EHentai;

use strict;
use warnings;
no warnings 'uninitialized';

use URI;
use Mojo::UserAgent;

use LANraragi::Utils::Logging qw(get_logger);

# Meta-information about your plugin.
sub plugin_info {

    return (
        # Standard metadata
        name       => "E*Hentai Downloader",
        type       => "download",
        namespace  => "ehdl",
        login_from => "ehlogin",
        author     => "Difegue",
        version    => "1.1",
        description =>
          "Downloads the given e*hentai URL and adds it to LANraragi. This uses GP to call the archiver, so make sure you have enough!",

        # Downloader-specific metadata
        url_regex => "https?:\/\/e(-|x)hentai.org\/g\/.*\/.*"
    );

}

# Mandatory function to be implemented by your downloader
sub provide_url {
    shift;
    my $lrr_info = shift;
    my $logger   = get_logger( "EH Downloader", "plugins" );

    # Get the URL to download
    # We don't really download anything here, we just use the E-H URL to get an archiver URL that can be downloaded normally.
    my $url     = $lrr_info->{url};
    my $gID     = "";
    my $gToken  = "";
    my $archKey = "";
    my $domain  = ( $url =~ /.*exhentai\.org/gi ) ? 'https://exhentai.org' : 'https://e-hentai.org';

    $logger->debug($url);
    if ( $url =~ /.*\/g\/([0-9]*)\/([0-z]*)\/*.*/ ) {
        $gID    = $1;
        $gToken = $2;
    } else {
        return ( error => "Not a valid E-H URL!" );
    }

    $logger->debug("gID: $gID, gToken: $gToken");

    my $archiverurl = "$domain\/archiver.php?gid=$gID&token=$gToken";
    $logger->info("Archiver URL: $archiverurl");

    # Do a quick GET to check for potential errors
    my $archiverHtml = $lrr_info->{user_agent}->max_redirects(5)->get($archiverurl)->result->body;
    if ( index( $archiverHtml, "Invalid archiver key" ) != -1 ) {
        return ( error => "Invalid archiver key. ($archiverurl)" );
    }
    if ( index( $archiverHtml, "This page requires you to log on." ) != -1 ) {
        return ( error => "Invalid E*Hentai login credentials. Please make sure the login plugin has proper settings set." );
    }

    # We only use original downloads, so we POST directly to the archiver form with dltype="org"
    # and dlcheck ="Download+Original+Archive"
    $response = $lrr_info->{user_agent}->max_redirects(5)->post(
        $archiverurl => form => {
            dltype  => 'org',
            dlcheck => 'Download+Original+Archive'
        }
    )->result;

    $content = $response->body;
    $logger->debug("/archiver.php result: $content");

    if ($content =~ /.*Insufficient funds.*/gim) {
        $logger->debug("Not enough GP, aborting download.");
        return ( error => "You do not have enough GP to download this URL." );
    }

    my $finalURL = URI->new();
    eval {
        # Parse that to get the final URL
        if ( $content =~ /.*document.location = "(.*)".*/gim ) {
            $finalURL = URI->new($1);
            $logger->info("Final URL obtained: $finalURL");
        }
    };

    if ( $@ || $finalURL eq "" ) {
        return ( error => "Couldn't proceed with an original size download: <pre>$content</pre>" );
    }

    # Set URL query parameters to ?start=1 to automatically trigger the download.
    $finalURL->query("start=1");

    # All done!
    return ( download_url => $finalURL->as_string );
}

1;
