package LANraragi::Plugin::Download::Chaika;

use strict;
use warnings;
no warnings 'uninitialized';

# Meta-information about your plugin.
sub plugin_info {

    return (
        # Standard metadata
        name        => "Chaika.moe Downloader",
        type        => "download",
        namespace   => "chaikadl",
        author      => "Difegue",
        version     => "1.0",
        description => "Downloads the given chaika.moe URL and adds it to LANraragi. No support for gallery links for now!",

        # Downloader-specific metadata
        # https://panda.chaika.moe/archive/_____/
        url_regex => "https?:\/\/panda.chaika.moe\/archive\/.*"
    );

}

# Mandatory function to be implemented by your downloader
sub provide_url {
    shift;
    my $lrr_info = shift;

    # Get the URL to download
    my $url = $lrr_info->{url};

    # Wow!
    return ( download_url => $url . "/download" );
}

1;
