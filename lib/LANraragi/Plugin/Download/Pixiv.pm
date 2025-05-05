package LANraragi::Plugin::Download::Pixiv;

use strict;
use warnings;
no warnings 'uninitialized';

use Mojo::UserAgent;
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
        description => "Downloads the given Pixiv artwork and adds it to LANraragi.
            <br>
            <br><i class='fa fa-exclamation-circle'></i> Pixiv enforces a rate limit on API requests, and may suspend/ban your account for overuse.",

        # Downloader-specific metadata
        url_regex => "https?:\/\/(?:www\.)?pixiv\.net\/(?:[a-z]{2}\/)?artworks\/([0-9]+)"
    );

}

# Mandatory function to be implemented by your downloader
sub provide_url {
    shift;
    my $lrr_info        = shift;
    my $logger          = get_logger( "Pixiv Downloader", "plugins" );

    my $url = $lrr_info->{url};
    my $artwork_id = extract_artwork_id($url);
    unless ( $artwork_id ) {
        die "Invalid Pixiv URL. Expected format: https://www.pixiv.net/artworks/12345678, got $url\n";
    }
    $logger->info("Processing Pixiv artwork ID: $artwork_id");

    my $ua              = $lrr_info->{user_agent};
    my $tempdir         = $lrr_info->{tempdir};
    my $referer         = "https://www.pixiv.net/artworks/$artwork_id";
    my %metadata_result = fetch_artwork_metadata($ua, $artwork_id, $referer);
    if ( exists $metadata_result{error} ) {
        die $metadata_result{error} . "\n";
    }
    my $metadata = $metadata_result{metadata};
    unless ( $metadata && $metadata->{body} ) {
        die "Got invalid metadata response from artwork with ID $artwork_id\n";
    }
    my $artwork         = $metadata->{body};
    my $title           = $artwork->{title};
    my $pages_count     = $artwork->{pageCount};
    $logger->debug("Artwork title: $title, Pages: $pages_count");
    my $zip_filename    = "pixiv_${artwork_id}.zip";
    my $zip_path        = "$tempdir/$zip_filename";
    my $zip             = Archive::Zip->new();

    my $download_count  = 0;
    my $inner_result;
    if ( $pages_count == 1 ) {
        $inner_result   = add_single_page_artwork_to_zip($zip, $ua, $tempdir, $artwork, $referer);
        $download_count = $inner_result->{download_count};
    } elsif ( $pages_count > 1 ) {
        $inner_result   = add_multi_page_artwork_to_zip($zip, $ua, $tempdir, $artwork_id, $referer);
        $download_count = $inner_result->{download_count};
    } else {
        die "Invalid page count for artwork with ID $artwork_id: $pages_count\n";
    }
    if ( exists $inner_result->{error} ) {
        die "Failed to add artwork to ZIP archive for artwork with ID $artwork_id: " . $inner_result->{error} . "\n";
    }

    my $zip_status = $zip->writeToFileNamed($zip_path);
    unless ( $zip_status == AZ_OK ) {
        die "Failed to create ZIP archive for artwork with ID $artwork_id. ZIP status: $zip_status\n";
    }
    $logger->info("Created ZIP archive with $download_count images: $zip_filename");
    return (
        file_path => $zip_path
    );
}

######
## Pixiv Specific Methods
######

# sub sanitize_title {
#     my $title = shift;
#     $title =~ s/[^\w\s\-\.]/_/g;
#     return $title;
# }

sub add_single_page_artwork_to_zip {
    my ($zip, $ua, $tempdir, $artwork, $referer) = @_;
    my $logger              = get_logger( "Pixiv Downloader", "plugins" );
    my $download_count      = 0;
    my $img_url             = $artwork->{urls}->{original};
    unless ( $img_url ) {
        return { error => "Could not find image URL in single-page artwork metadata" };
    }

    my $filename            = basename($img_url);
    my $local_path          = "$tempdir/$filename";

    $logger->info("Downloading single image: $img_url");
    my $img_res = $ua->get($img_url => { Referer => $referer })->result;
    unless ( $img_res->is_success ) {
        my $err_code        = $img_res->code;
        my $err_msg         = $img_res->message;
        return { error => "Failed to download single-page artwork (status $err_code): $err_msg" };
    }
    image_res_to_zip($zip, $img_res, $local_path, $filename);
    $download_count++;
    return { download_count => $download_count };
}

sub add_multi_page_artwork_to_zip {
    my ($zip, $ua, $tempdir, $artwork_id, $referer) = @_;
    my $logger              = get_logger( "Pixiv Downloader", "plugins" );
    my $download_count      = 0;
    my $pages_api_url       = "https://www.pixiv.net/ajax/illust/$artwork_id/pages";
    my $pages_res           = $ua->get($pages_api_url => { Referer => $referer })->result;

    unless ( $pages_res->is_success ) {
        my $err_code        = $pages_res->code;
        my $err_msg         = $pages_res->message;
        return { error => "Failed to get pages metadata from multi-page artwork (status $err_code): $err_msg" };
    }

    my $pages_data = $pages_res->json;
    unless ( $pages_data && $pages_data->{body} ) {
        return { error => "Invalid pages metadata response from multi-page artwork" };
    }

    my @pages = @{$pages_data->{body}};
    for my $i (0..$#pages) {
        my $img_url         = $pages[$i]->{urls}->{original};
        my $filename        = sprintf("%03d_%s", $i, basename($img_url));
        my $local_path      = "$tempdir/$filename";

        $logger->info("Downloading page $i: $img_url");
        my $img_res = $ua->get($img_url => { Referer => $referer })->result;
        unless ( $img_res->is_success ) {
            my $err_code    = $img_res->code;
            my $err_msg     = $img_res->message;
            return { error => "Failed to download page $i (status $err_code): $err_msg" };
        }
        image_res_to_zip($zip, $img_res, $local_path, $filename);
        $download_count++;
    }
    return { download_count => $download_count };
}

# Extract file from image response and add it to zip archive
sub image_res_to_zip {
    my ($zip, $img_res, $local_path, $filename) = @_;
    open my $fh, '>', $local_path or die "Cannot open $local_path: $!";
    print $fh $img_res->body;
    close $fh;
    $zip->addFile($local_path, $filename);
}

# Fetch artwork metadata from Pixiv API
# Returns key-value pairs with either metadata on success or error on failure
sub fetch_artwork_metadata {
    my $ua              = shift;
    my $artwork_id      = shift;
    my $referer         = shift;
    my $api_url         = "https://www.pixiv.net/ajax/illust/$artwork_id";
    my $res             = $ua->get($api_url => { Referer => $referer })->result;
    unless ($res->is_success) {
        my $err_code    = $res->code;
        my $err_msg     = $res->message;
        return (error => "Failed to fetch artwork metadata from URL $api_url (status $err_code): $err_msg");
    }
    my $metadata;
    eval {
        $metadata = $res->json;
    };
    if ($@) {
        return (error => "Failed to parse metadata JSON response: $@");
    }
    return (metadata => $metadata);
}

sub extract_artwork_id {
    my $url = shift;
    if ($url =~ /artworks\/([0-9]+)/) {
        return $1;
    }
    return undef;
}

1;
