package LANraragi::Model::Reader;

use strict;
use warnings;
use utf8;

use Redis;
use IPC::Cmd qw[can_run run];
use File::Basename;
use File::Path qw(remove_tree);
use Encode;
use File::Find::utf8 qw(find);
use URI::Escape;

use LANraragi::Model::Config;

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
    my $tempdir = "./public/temp";

    #Redis stuff: Grab archive path and update some things
    my $redis   = LANraragi::Model::Config::get_redis();
    my $dirname = LANraragi::Model::Config::get_userdir();

    #We opened this id in the reader, so we can't mark it as "new" anymore.
    $redis->hset( $id, "isnew", "none" );

    #Get the path from Redis.
    my $zipfile = $redis->hget( $id, "file" );
    $zipfile = LANraragi::Model::Utils::redis_decode($zipfile);

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
    #If it hasn't, we call unar to do it.
    unless ( -e $path ) #If the file hasn't been extracted, or if force-reload =1
    {
        my $unarcmd = "unar -D -o $path \"$zipfile\" ";           
        #Extraction using unar without creating extra folders.

        my ( $success, $error_message, $full_buf, $stdout_buf, $stderr_buf ) =
          run( command => $unarcmd, verbose => 0 );

        #Has the archive been extracted ? If not, stop here and print an error page.
        unless ( -e $path ) {
            my $errlog = join "<br/>", @$full_buf;
            $errlog = decode_utf8($errlog);
            $self->LRR_LOGGER->error("ERROR while unpacking archive: $errlog");
            die $errlog;
        }
    }

    $self->LRR_LOGGER->debug("Extracted archive successfully to $path");

    #Find the extracted images with a full search (subdirectories included), 
    #treat them and jam them into an array.
    my @images;
    find(
        {
            wanted => sub {

                $self->LRR_LOGGER->debug("Found $_ in extracted archive");

                #is it an image? readdir tends to read folder names too...
                if ( $_ =~ /^*.+\.(png|jpg|gif|bmp|jpeg|PNG|JPG|GIF|BMP)$/) {
                    push @images, $_;

                }
            },
            no_chdir    => 1,
            follow_fast => 1
        },
        $path
    );

    @images = sort { &expand($a) cmp &expand($b) } @images;

    #Convert page 1 into a thumbnail for the main reader index if it's not been done already
    #(Or if it fucked up for some reason).
    my $thumbname = $dirname . "/thumb/" . $id . ".jpg";

    unless ( -e $thumbname && $thumbreload eq "0" ) {

        $self->LRR_LOGGER->debug("Thumbnail not found at $thumbname ! (force-thumb flag = $thumbreload)");
        $self->LRR_LOGGER->debug("Regenerating from " . $images[0]);
        mkdir $dirname . "/thumb";

        my $shasum = LANraragi::Model::Utils::shasum( $images[0], 1 );
        $redis->hset( $id, "thumbhash", encode_utf8($shasum) );

        LANraragi::Model::Utils::generate_thumbnail( $images[0], $thumbname );
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

        #We also now need to strip the /public/ part, 
        #as it's not visible by clients.
        $imgpath =~ s!public/!!g;

        push @images_browser, $imgpath;
    }
                    

    #Build json (it's just the images array in a string)
    my $list = "{\"pages\": [\"" . join( "\",\"", @images_browser ) . "\"]}";
    return $list;

}

1;
