package LANraragi::Plugin::Download::Koushoku;

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
        name      => "Koushoku Downloader",
        type      => "download",
        namespace => "kskdl",

        #login_from => "ehlogin",
        author      => "Difegue",
        version     => "1.0",
        description => "Downloads the given KSK URL and adds it to LANraragi.",

        # Downloader-specific metadata
        # https://ksk.moe/view/____/_________
        url_regex => "https?:\/\/ksk.moe\/view\/.*\/.*"
    );

}

# Mandatory function to be implemented by your downloader
sub provide_url {
    shift;
    my $lrr_info = shift;
    my $logger = get_logger( "KSK Downloader", "plugins" );

    # Get the URL to download
    # We don't really download anything here, we just use the E-H URL to get an archiver URL that can be downloaded normally.
    my $url    = $lrr_info->{url};
    my $ua     = $lrr_info->{user_agent};
    my $gID    = "";
    my $gToken = "";

    $logger->debug($url);
    if ( $url =~ /.*\/view\/([0-9]*)\/([0-z]*)\/*.*/ ) {
        $gID    = $1;
        $gToken = $2;
    } else {
        return ( error => "Not a valid Koushoku URL!" );
    }

    $logger->debug("gID: $gID, gToken: $gToken");

# Sadly, we need to look at the original page to get the hash key to get a download URL. (and get cookies in case those are needed?)
# It's DOM parsing time again!
    my $response = $ua->max_redirects(5)->get($url)->result;
    my $content  = $response->body;
    my $dom      = Mojo::DOM->new($content);
    my $hash     = "";

    eval {
        # Hash is stuck in the value of the "Original" DL button.
        $hash = $dom->at(".original")->attr('value');
    };

    if ( $hash eq "" ) {
        return ( error => "Couldn't retrieve download hash from URL $gID/$gToken" );
    }

    # POST to the download endpoint to get the download URL
    # https://ksk.moe/download/11537/d951ca197324
    my $downloadURL = "https:\/\/ksk.moe\/download\/$gID\/$gToken";
    $logger->info("Download form URL: $downloadURL, hash: $hash");

    # First redirect should be our download URL.
    my $finalURL = URI->new();

    eval {
        $response = $ua->max_redirects(0)->post( $downloadURL => form => { hash => $hash } )->result;
        $content = $response->body;
        if ( $response->code == 302 ) {
            $logger->debug( "Redirect/location header: " . $response->headers->location );
            $finalURL = URI->new( $response->headers->location );
        }
    };

    if ( $@ || $finalURL eq "" ) {
        return ( error => "Couldn't proceed with an original size download: <pre>$content</pre>" );
    }

    # All done!
    return ( download_url => $finalURL->as_string );
}

1;
