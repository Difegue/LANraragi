package LANraragi::Model::Reader;

use v5.36;
use experimental 'try';

use strict;
use warnings;
use utf8;

use Redis;
use File::Basename;
use File::Path qw(remove_tree make_path);
use File::Find qw(find);
use File::Copy qw(move);
use Mojo::JSON qw(encode_json);
use Data::Dumper;
use URI::Escape;

use LANraragi::Utils::Generic  qw(is_image);
use LANraragi::Utils::Logging  qw(get_logger);
use LANraragi::Utils::Archive  qw(get_filelist);
use LANraragi::Utils::Database qw(redis_decode);

# resize_image(image,quality, size_threshold)
# Convert an image to a cheaper on bandwidth format through ImageMagick.
# This will no-op if the ImageMagick bindings are unavailable.
sub resize_image ( $content, $quality, $threshold ) {

    no warnings 'experimental::try';
    my $img = undef;

    try {
        require Image::Magick;
        $img = Image::Magick->new;

        #Is the file size higher than the threshold?
        if ( ( (length($content) / 1024 * 10 ) / 10 ) > $threshold ) {

            # For JPEG, the size option (or jpeg:size option) provides a hint to the JPEG decoder
            # that it can reduce the size on-the-fly during decoding. This saves memory because
            # it never has to allocate memory for the full-sized image
            $img->Set( option => 'jpeg:size=1064x' );

            $img->BlobToImage($content);

            my ( $origw, $origh ) = $img->Get( 'width', 'height' );
            if ( $origw > 1064 ) {
                $img->Resize( geometry => '1064x' );
            }


            # Set format to jpeg and quality
            return $img->ImageToBlob(magick => "jpg", quality => $quality);
        } else {
            return $content;
        }
    } catch ($e) {

        # Magick is unavailable, do nothing
        my $logger = get_logger( "Reader", "lanraragi" );
        $logger->debug("ImageMagick is not available , skipping image resizing: $e");
        return $content;
    } finally {
        if (defined($img)) {
            undef $img;
        }
    }

}

# build_reader_JSON(mojo, id, forceReload)
# Opens the archive specified by its ID, and returns a json containing the page names.
sub build_reader_JSON ( $self, $id, $force ) {
    # Get the path from Redis.
    # Filenames are stored as they are on the OS, so no decoding!
    my $redis   = LANraragi::Model::Config->get_redis;
    my $archive = $redis->hget( $id, "file" );

    # Parse archive to get its list of images
    my ( $images, $sizes ) = get_filelist($archive);

    # Dereference arrays
    my @images = @$images;
    my @sizes  = @$sizes;

    $self->LRR_LOGGER->debug( "Files found in archive (encoding might be incorrect): \n " . Dumper @images );

    # Build a browser-compliant filepath array from @images
    my @images_browser;

    foreach my $imgpath (@images) {

        # Since we're using uri_escape_utf8 for escaping, we need to make sure the path is valid UTF8.
        # The good ole' redis_decode allows us to make sure of that.
        $imgpath = redis_decode($imgpath);

        # We need to sanitize the image's path, in case the folder contains illegal characters,
        # but uri_escape would also nuke the / needed for navigation. Let's solve this with a quick regex search&replace.
        # First, we encode all HTML characters...
        $imgpath = uri_escape_utf8($imgpath);

        # Then we bring the slashes back.
        $imgpath =~ s!%2F!/!g;

        # Bundle this path into an API call which will be used by the browser
        push @images_browser, $self->url_for("/api/archives/$id/page?path=$imgpath")->path_query;
    }

    # Update pagecount and sizes
    $redis->hset( $id, "pagecount", scalar @images );
    $redis->hset( $id, "filesizes", encode_json( \@sizes ) );
    $redis->quit();

    return {
        pages => \@images_browser,
    };
}

1;
