package LANraragi::Model::Reader;

use strict;
use warnings;
use utf8;

use Redis;
use File::Basename;
use File::Path qw(remove_tree make_path);
use File::Find qw(find);
use File::Copy qw(move);
use Encode;
use Data::Dumper;
use URI::Escape;
use Image::Magick;

use LANraragi::Utils::Generic qw(is_image shasum);
use LANraragi::Utils::Archive qw(extract_archive generate_thumbnail);
use LANraragi::Utils::TempFolder qw(get_temp);
use LANraragi::Utils::Database qw(redis_decode);

#magical sort function used below
sub expand {
    my $file = shift;
    $file =~ s{(\d+)}{sprintf "%04d", $1}eg;
    return $file;
}

#resize_image(image,quality, size_threshold)
#convert an image to a cheaper on bandwidth format through ImageMagick.
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

#build_reader_JSON(mojo,id,forceReload,refreshThumbnail)
#Opens the archive specified by its ID, and returns a json containing the page names.
sub build_reader_JSON {

    my ( $self, $id, $force, $thumbreload ) = @_;
    my $tempdir = get_temp();

    #Redis stuff: Grab archive path and update some things
    my $redis   = LANraragi::Model::Config->get_redis;
    my $dirname = LANraragi::Model::Config->get_userdir;

    # Get the path from Redis.
    # Filenames are stored as they are on the OS, so no decoding!
    my $zipfile = $redis->hget( $id, "file" );

    #Get data from the path
    my ( $name, $fpath, $suffix ) = fileparse( $zipfile, qr/\.[^.]*/ );
    my $filename = $name . $suffix;

    my $path = $tempdir . "/" . $id;

    if ( -e $path && $force eq "1" ) {

        #If the file has been extracted and force-reload=1,
        #we wipe the extraction directory.
        remove_tree($path);
    }

    #Now, has our file been extracted to the temporary directory recently?
    #If it hasn't, we call libarchive to do it.
    #If the file hasn't been extracted, or if force-reload =1
    unless ( -e $path ) {

        my $outpath = "";
        eval { $outpath = extract_archive( $path, $zipfile ); };

        if ($@) {
            my $log = $@;
            $self->LRR_LOGGER->error("Error extracting archive : $log");
            die $log;
        } else {
            $self->LRR_LOGGER->debug("Extraction of archive to $outpath done");
            $path = $outpath;
        }

    }

    #Find the extracted images with a full search (subdirectories included),
    #treat them and jam them into an array.
    my @images;
    eval {
        find(
            sub {
                # Is it an image?
                if ( is_image($_) ) {
                    push @images, $File::Find::name;
                }
            },
            $path
        );
    };

    # TODO: @images = nsort(@images); would theorically be better, but Sort::Naturally's nsort puts letters before numbers,
    # which isn't what we want at all for pages in an archive.
    # To investigate further, perhaps with custom sorting algorithms?
    @images = sort { &expand($a) cmp &expand($b) } @images;

    $self->LRR_LOGGER->debug( "Files found in archive: \n " . Dumper @images );

    # Convert page 1 into a thumbnail for the main reader index
    my $subfolder = substr( $id, 0, 2 );
    my $thumbname = "$dirname/thumb/$subfolder/$id.jpg";

    unless ( -e $thumbname && $thumbreload eq "0" ) {

        my $shasum = shasum( $images[0], 1 );
        $redis->hset( $id, "thumbhash", encode_utf8($shasum) );

        $self->LRR_LOGGER->debug("Thumbnail not found at $thumbname! (force-thumb flag = $thumbreload)");
        $self->LRR_LOGGER->debug( "Regenerating from " . $images[0] );
        make_path("$dirname/thumb/$subfolder");

        generate_thumbnail( $images[0], $thumbname );
    }

    # Build a browser-compliant filepath array from @images
    my @images_browser;

    foreach my $imgpath (@images) {

        # Strip everything before the temporary folder/id folder as to only keep the relative path to it
        # i.e "/c/bla/lrr/temp/id/file.jpg" becomes "file.jpg"
        $imgpath =~ s!$path/!!g;

        $self->LRR_LOGGER->debug("Relative path to temp is $imgpath");

        # Since we're using uri_escape_utf8 for escaping, we need to make sure the path is valid UTF8.
        # The good ole' redis_decode allows us to make sure of that.
        $imgpath = redis_decode($imgpath);

        # We need to sanitize the image's path, in case the folder contains illegal characters,
        # but uri_escape would also nuke the / needed for navigation. Let's solve this with a quick regex search&replace.
        # First, we encode all HTML characters...
        $imgpath = uri_escape_utf8($imgpath);

        # Then we bring the slashes back.
        $imgpath =~ s!%2F!/!g;

        $self->LRR_LOGGER->debug("Post-escape: $imgpath");

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
