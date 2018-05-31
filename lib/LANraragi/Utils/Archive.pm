package LANraragi::Utils::Archive;

use strict;
use warnings;
use utf8;

use File::Basename;
use Encode;
use Redis;
use Image::Magick;

use LANraragi::Model::Config;

#Utilitary functions for handling Archives.
#Relies a lot on unar/lsar.

#generate_thumbnail(original_image, thumbnail_location)
#use ImageMagick to make a thumbnail, width = 200px
sub generate_thumbnail {

    my ( $orig_path, $thumb_path ) = @_;
    my $img = Image::Magick->new;

    $img->Read($orig_path);
    $img->Thumbnail( geometry => '200x' );
    $img->Write($thumb_path);
}

#extract_thumbnail(dirname, id)
#Finds the first image for the specified archive ID and makes it the thumbnail.
sub extract_thumbnail {

    my ( $dirname, $id ) = @_;
    my $thumbname = $dirname . "/thumb/" . $id . ".jpg";

    mkdir $dirname . "/thumb";
    my $redis = LANraragi::Model::Config::get_redis();

    my $file = $redis->hget( $id, "file" );
    $file = LANraragi::Utils::Database::redis_decode($file);

    my $path = "./public/temp/thumb";

    #Clean thumb temp to prevent file mismatch errors.
    unlink glob $path . "/*.*";

    #Get lsar's output, jam it in an array, and use it as @extracted.
    my $vals = `lsar "$file"`;
    my @lsarout = split /\n/, $vals;
    my @extracted;

    #The -i 0 option on unar doesn't always return the first image.
    #We use the lsar output to find the first image.
    foreach my $lsarfile (@lsarout) {

        #is it an image? lsar can give us folder names.
        if (
            $lsarfile =~ /^(.*\/)*.+\.(png|jpg|gif|bmp|jpeg|PNG|JPG|GIF|BMP)$/ )
        {
            push @extracted, $lsarfile;
        }
    }

    @extracted = sort { lc($a) cmp lc($b) } @extracted;

    #unar sometimes crashes on certain folder names inside archives.
    #To solve that, we replace folder names with the wildcard * through regex.
    my $unarfix = $extracted[0];
    $unarfix =~ s/[^\/]+\//*\//g;

    #let's extract now.
    my $res = `unar -D -o $path "$file" "$unarfix"`;

    if ($?) {
        return "Error extracting thumbnail: $res";
    }

    #Path to the first image of the archive
    my $arcimg = $path . '/' . $extracted[0];

    #While we have the image, grab its SHA-1 hash for tag research.
    #That way, no need to repeat the costly extraction later.
    my $shasum = LANraragi::Utils::Generic::shasum( $arcimg, 1 );
    $redis->hset( $id, "thumbhash", encode_utf8($shasum) );

    #Thumbnail generation
    generate_thumbnail( $arcimg, $thumbname );

    #Delete the previously extracted file.
    unlink $arcimg;
    return $thumbname;
}

#is_file_in_archive($archive, $file)
#Uses lsar to figure out if $archive contains $file.
#Returns 1 if it does exist, 0 otherwise.
sub is_file_in_archive {

    my ( $archive, $filename ) = @_;

    #Get lsar's output, jam it in an array, and use it as @extracted.
    my $vals = `lsar "$archive"`;
    my @lsarout = split /\n/, $vals;
    my @extracted;

    #Sort on the lsar output to find the file
    foreach my $lsarfile (@lsarout) {
        if ( $lsarfile eq $filename ) {
            return 1;
        }
    }

    #Found nothing
    return 0;
}

#extract_file_from_archvie($archive, $file)
#Extract $file from $archive. Extracted files go to /temp/plugin.
sub extract_file_from_archive {

    my ( $archive, $filename ) = @_;
    my $path = "./public/temp/plugin";

    `unar -D -o $path "$archive" "$filename"`;

}

1;
