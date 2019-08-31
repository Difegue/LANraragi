package LANraragi::Model::Reader;

use strict;
use warnings;
use utf8;

use Redis;
use File::Basename;
use File::Path qw(remove_tree);
use File::Find qw(find);
use File::Copy qw(move);
use Encode;
use Data::Dumper;
use URI::Escape;

use LANraragi::Model::Config;
use LANraragi::Utils::Archive;
use LANraragi::Utils::Database;
use LANraragi::Utils::TempFolder;

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
        $img->Resize( geometry => '1064x' );
        $img->Set( quality => $quality );
        $img->Write($imgpath);
    }
}

#build_reader_JSON(mojo,id,forceReload,refreshThumbnail)
#Opens the archive specified by its ID and returns a json matching pages to their
sub build_reader_JSON {

    my ( $self, $id, $force, $thumbreload ) = @_;
    my $tempdir = LANraragi::Utils::TempFolder::get_temp;

    #Redis stuff: Grab archive path and update some things
    my $redis   = LANraragi::Model::Config::get_redis();
    my $dirname = LANraragi::Model::Config::get_userdir();

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
        eval {
            $outpath =
              LANraragi::Utils::Archive::extract_archive( $path, $zipfile );
        };

        if ($@) {
            my $log = $@;
            $self->LRR_LOGGER->error("Error extracting archive : $log");
            die $log;
        }
        else {
            $self->LRR_LOGGER->debug("Extraction of archive to $outpath done");
            $path = $outpath;
        }

    }

    #Find the extracted images with a full search (subdirectories included),
    #treat them and jam them into an array.
    my @images;
    eval { 
        find(sub {
                # Is it an image? 
                if ( LANraragi::Utils::Generic::is_image($_) ) {
                    push @images, $File::Find::name;
                }
            }, $path);
    };

    @images = sort { &expand($a) cmp &expand($b) } @images;

    $self->LRR_LOGGER->debug("Files found in archive: \n " . Dumper @images);

    #Convert page 1 into a thumbnail for the main reader index
    my $thumbname = $dirname . "/thumb/" . $id . ".jpg";
    unless ( -e $thumbname && $thumbreload eq "0" ) {

        my $shasum = LANraragi::Utils::Generic::shasum( $images[0], 1 );
        $redis->hset( $id, "thumbhash", encode_utf8($shasum) );

        $self->LRR_LOGGER->debug("Thumbnail not found at $thumbname ! (force-thumb flag = $thumbreload)");
        $self->LRR_LOGGER->debug("Regenerating from " . $images[0]);
        mkdir $dirname . "/thumb";

        LANraragi::Utils::Archive::generate_thumbnail( $images[0], $thumbname );
    }

    #Build a browser-compliant filepath array from @images
    my @images_browser;

    foreach my $imgpath (@images) {

#We need to sanitize the image's path, in case the folder contains illegal characters,
#but uri_escape would also nuke the / needed for navigation. Let's solve this with a quick regex search&replace.
#First, we encode all HTML characters...
        $imgpath = uri_escape_utf8($imgpath);

        #Then we bring the slashes back.
        $imgpath =~ s!%2F!/!g;

        #We also now need to strip everything before the /public/ part,
        #as it's not visible by clients.
        $imgpath =~ s!.*/public/!!g;

        push @images_browser, $imgpath;
    }

    #Build json (it's just the images array in a string)
    my $list = "{\"pages\": [\"" . join( "\",\"", @images_browser ) . "\"]}";
    return $list;

}

1;
