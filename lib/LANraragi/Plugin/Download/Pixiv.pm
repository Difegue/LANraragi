package LANraragi::Plugin::Download::Pixiv;

use strict;
use warnings;
no warnings 'uninitialized';

use Mojo::UserAgent;
use File::Temp qw(tempdir);
use File::Basename;
use Archive::Zip qw(:ERROR_CODES :CONSTANTS);

use LANraragi::Utils::Logging qw(get_logger);

# Meta-information about your plugin.
sub plugin_info {

    return (
        # Standard metadata
        name        => "Pixiv Downloader",
        type        => "download",
        namespace   => "pixivdl",
        login_from  => "pixivlogin",
        author      => "psilabs-dev",
        version     => "1.0",
        description =>
          "Downloads the given pixiv URL and adds it to LANraragi.",

        # Downloader-specific metadata
        url_regex => "https?:\/\/(?:www\.)?pixiv\.net\/(?:en\/)?artworks\/([0-9]+)"
    );

}

# Mandatory function to be implemented by your downloader
sub provide_url {
    shift;
    my $lrr_info = shift;
    my $logger   = get_logger( "Pixiv Downloader", "plugins" );
    my $url = $lrr_info->{url};
    my $artwork_id;
    if ($url =~ /artworks\/([0-9]+)/) {
        $artwork_id = $1;
    } else {
        return (error => "Invalid Pixiv URL. Expected format: https://www.pixiv.net/artworks/12345678");
    }
    $logger->info("Processing Pixiv artwork ID: $artwork_id");
    
    # Create a temporary directory for downloading images
    my $temp_dir = tempdir(CLEANUP => 0); # We need to keep this dir until LANraragi processes the file
    $logger->debug("Created temporary directory: $temp_dir");
    my $ua = $lrr_info->{user_agent};
    my $referer = "https://www.pixiv.net/artworks/$artwork_id";
    my $api_url = "https://www.pixiv.net/ajax/illust/$artwork_id";
    $logger->debug("Fetching artwork metadata from: $api_url");
    my $res = $ua->get($api_url => { Referer => $referer })->result;
    if (!$res->is_success) {
        return (error => "Failed to get artwork metadata: " . $res->message);
    }
    my $metadata = $res->json;
    if (!$metadata || !$metadata->{body}) {
        return (error => "Invalid metadata response from Pixiv");
    }
    my $artwork = $metadata->{body};
    my $title = $artwork->{title} || "pixiv_$artwork_id";
    my $pages_count = $artwork->{pageCount} || 1;
    $logger->info("Artwork title: $title, Pages: $pages_count");
    my $zip = Archive::Zip->new();
    my $download_count = 0;
    # For single-page artworks
    if ($pages_count == 1) {
        my $img_url = $artwork->{urls}->{original};
        if (!$img_url) {
            return (error => "Could not find image URL in artwork metadata");
        }        
        my $filename = basename($img_url);
        my $local_path = "$temp_dir/$filename";
        $logger->info("Downloading single image: $img_url");
        my $img_res = $ua->get($img_url => { Referer => $referer })->result;
        if ($img_res->is_success) {
            open my $fh, '>', $local_path or die "Cannot open $local_path: $!";
            print $fh $img_res->body;
            close $fh;
            $zip->addFile($local_path, $filename);
            $download_count++;
        } else {
            $logger->error("Failed to download image: " . $img_res->message);
        }
    } else {
        # For multi-page artworks
        my $pages_api_url = "https://www.pixiv.net/ajax/illust/$artwork_id/pages";
        my $pages_res = $ua->get($pages_api_url => { Referer => $referer })->result;        
        if (!$pages_res->is_success) {
            return (error => "Failed to get pages metadata: " . $pages_res->message);
        }
        my $pages_data = $pages_res->json;
        if (!$pages_data || !$pages_data->{body}) {
            return (error => "Invalid pages metadata response");
        }
        my @pages = @{$pages_data->{body}};
        for my $i (0..$#pages) {
            my $img_url = $pages[$i]->{urls}->{original};
            my $filename = sprintf("%03d_%s", $i, basename($img_url));
            my $local_path = "$temp_dir/$filename";
            $logger->info("Downloading page $i: $img_url");
            my $img_res = $ua->get($img_url => { Referer => $referer })->result;
            if ($img_res->is_success) {
                open my $fh, '>', $local_path or die "Cannot open $local_path: $!";
                print $fh $img_res->body;
                close $fh;
                $zip->addFile($local_path, $filename);
                $download_count++;
            } else {
                $logger->error("Failed to download page $i: " . $img_res->message);
            }
        }
    }
    if ($download_count == 0) {
        return (error => "Failed to download any images from this artwork");
    }
    # Create a sanitized title for the ZIP file
    $title =~ s/[^\w\s\-\.]/_/g;
    my $zip_filename = "pixiv_${artwork_id}.zip";
    my $zip_path = "$temp_dir/$zip_filename";
    if ($zip->writeToFileNamed($zip_path) != AZ_OK) {
        return (error => "Failed to create ZIP archive");
    }
    $logger->info("Created ZIP archive with $download_count images: $zip_filename");

    # With the file_path API extension, we can simply return the path to our ZIP file
    # LANraragi will handle copying it to the content directory
    return (file_path => $zip_path);
}

1;
