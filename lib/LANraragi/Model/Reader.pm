package LANraragi::Model::Reader;

use strict;
use warnings;
use utf8;

use Redis;
use File::Basename;
use File::Path qw(remove_tree make_path);
use File::Find qw(find);
use File::Copy qw(move);
use Data::Dumper;
use URI::Escape;
use Image::Magick;

use LANraragi::Utils::Generic qw(is_image shasum);
use LANraragi::Utils::Archive qw(extract_archive generate_thumbnail get_filelist);
use LANraragi::Utils::Database qw(redis_decode);

#magical sort function used below
sub expand {
    my $file = shift;
    $file =~ s{(\d+)}{sprintf "%04d", $1}eg;
    return $file;
}

# resize_image(image,quality, size_threshold)
# Convert an image to a cheaper on bandwidth format through ImageMagick.
sub resize_image {

    my ( $imgpath, $quality, $threshold ) = @_;
    my $img = Image::Magick->new;

    #Is the file size higher than the threshold?
    if ( ( int( ( -s $imgpath ) / 1024 * 10 ) / 10 ) > $threshold ) {
        $img->Read($imgpath);

        my ( $origw, $origh ) = $img->Get( 'width', 'height' );
        if ( $origw > 1064 ) {
            $img->Resize( geometry => '1064x' );
        }

        # Set format to jpeg and quality
        $img->Set( quality => $quality, magick => "jpg" );
        $img->Write($imgpath);
    }
    undef $img;
}

# build_reader_JSON(mojo, id, forceReload)
# Opens the archive specified by its ID, and returns a json containing the page names.
sub build_reader_JSON {

    my ( $self, $id, $force ) = @_;

    # Queue a full extract job into Minion.
    # This'll fill in the missing pages (or regen everything if force = 1)
    $self->minion->enqueue(
        extract_archive => [ $id, $force ],
        { priority => 4 }
    );

    # Get the path from Redis.
    # Filenames are stored as they are on the OS, so no decoding!
    my $redis = LANraragi::Model::Config->get_redis;
    my $archive = $redis->hget( $id, "file" );

    # Parse archive to get its list of images
    my @images = get_filelist($archive);

    # TODO: @images = nsort(@images); would theorically be better, but Sort::Naturally's nsort puts letters before numbers,
    # which isn't what we want at all for pages in an archive.
    # To investigate further, perhaps with custom sorting algorithms?
    @images = sort { &expand($a) cmp &expand($b) } @images;

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
        push @images_browser, "./api/archives/$id/page?path=$imgpath";
    }

    # Update pagecount
    $redis->hset( $id, "pagecount", scalar @images );
    $redis->quit();

    # Build json (it's just the images array in a string)
    my $list = "{\"pages\": [\"" . join( "\",\"", @images_browser ) . "\"]}";
    return $list;
}

1;
