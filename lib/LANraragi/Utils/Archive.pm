package LANraragi::Utils::Archive;

use strict;
use warnings;
use utf8;

use Time::HiRes qw(gettimeofday);
use File::Basename;
use File::Path qw(remove_tree);
use File::Find qw(finddepth);
use File::Copy qw(move);
use Encode;
use Encode::Guess qw/euc-jp shiftjis 7bit-jis/;
use Redis;
use Cwd;
use Data::Dumper;
use Image::Scale;
use Archive::Peek::Libarchive;
use Archive::Extract::Libarchive;

use LANraragi::Model::Config;
use LANraragi::Utils::TempFolder;

#Utilitary functions for handling Archives.
#Relies on Libarchive.

#generate_thumbnail(original_image, thumbnail_location)
#use Image::Scale to make a thumbnail, width = 200px
sub generate_thumbnail {

    my ( $orig_path, $thumb_path ) = @_;

    my $img = Image::Scale->new($orig_path) || die "Invalid image file";
    $img->resize_gd( { width => 200 } );
    $img->save_jpeg($thumb_path);

}

#extract_archive(path, archive_to_extract)
#Extract the given archive to the given path.
sub extract_archive {

    my ( $path, $zipfile ) = @_;

    # build an Archive::Extract object
    my $ae = Archive::Extract::Libarchive->new( archive => $zipfile );

    #Extract to $path. Report if it fails.
    my $ok = $ae->extract( to => $path ) or die $ae->error;
    
    #Rename files and folders to an encoded version
    my $cwd = getcwd();

    finddepth(sub {
        unless ($_ eq '.') {

            my $filename = $_;
            eval {
                # Try a guess to regular japanese encodings first
                $filename = decode ("Guess", $filename);
            };
            # Fallback to utf8
            $filename = decode_utf8($filename) if $@;

            # Re-encode the result to ASCII and move the file to said result name. 
            # Use Encode's coderef feature to map non-ascii characters to their Unicode codepoint equivalent.
            $filename = encode("ascii", $filename, sub{ sprintf "%04X", shift });
            
            if (length $filename > 254) {
                $filename = substr( $filename, 0, 254 );
            }

            move($_, $filename);
        }
    }, $ae->extract_path);
    
    # chdir back to the base cwd in case finddepth died midway
    chdir $cwd;

    # dir that was extracted to
    return $ae->extract_path;
}

#extract_thumbnail(dirname, id)
#Finds the first image for the specified archive ID and makes it the thumbnail.
sub extract_thumbnail {

    my ( $dirname, $id ) = @_;
    my $thumbname = $dirname . "/thumb/" . $id . ".jpg";

    mkdir $dirname;
    mkdir $dirname . "/thumb";
    my $redis = LANraragi::Model::Config::get_redis();

    my $file = $redis->hget( $id, "file" );
    my $temppath = LANraragi::Utils::TempFolder::get_temp . "/thumb";

    #Clean thumb temp to prevent file mismatch errors.
    remove_tree( $temppath, { error => \my $err } );
    mkdir $temppath;

    #Get all the files of the archive
    my $peek = Archive::Peek::Libarchive->new( filename => $file );
    my @files = $peek->files();
    my @extracted;

    #Filter out non-images
    foreach my $file (@files) {

        if ( $file =~ /^(.*\/)*.+\.(png|jpg|gif|bmp|jpeg|PNG|JPG|GIF|BMP)$/ ) {
            push @extracted, $file;
        }
    }

    @extracted = sort { lc($a) cmp lc($b) } @extracted;

    #Get the first file of the list and spit it out into a file
    my $contents = $peek->file( $extracted[0] );

#The name sometimes comes with the folder as a bonus, so we use basename to filter it out.
    my ( $filename, $dirs, $suffix ) = fileparse( $extracted[0] );
    my $arcimg = $temppath . '/' . $filename . $suffix;

    open( my $fh, '>', $arcimg )
      or die "Could not open file '$arcimg' $!";
    print $fh $contents;
    close $fh;

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
#Uses libarchive::peek to figure out if $archive contains $file.
#Returns 1 if it does exist, 0 otherwise.
sub is_file_in_archive {

    my ( $archive, $wantedname ) = @_;

    my $logger = LANraragi::Utils::Generic::get_logger( "Archive", "lanraragi" );
    $logger->debug("Iterating files of archive $archive, looking for '$wantedname'");
    $Data::Dumper::Useqq = 1;

    my $peek = Archive::Peek::Libarchive->new( filename => $archive );
    my $found = 0;
    $peek->iterate(
        sub {
            my $name = $_[0];
            $logger->debug("Found file " . Dumper($name));

            if ( $name =~ /$wantedname$/ ) {
                $found = 1;
            }
        }
    );

    return $found;

}

#extract_file_from_archive($archive, $file)
#Extract $file from $archive and returns the filesystem path it's extracted to.
#If the file doesn't exist in the archive, this will still create a file, but empty.
sub extract_file_from_archive {

    my ( $archive, $filename ) = @_;

    #Timestamp extractions in microseconds 
    my ( $seconds, $microseconds ) = gettimeofday;
    my $stamp = "$seconds-$microseconds";
    my $path  = LANraragi::Utils::TempFolder::get_temp . "/plugin/$stamp";
    mkdir LANraragi::Utils::TempFolder::get_temp . "/plugin";
    mkdir $path;

    my $peek = Archive::Peek::Libarchive->new( filename => $archive );
    my $contents = "";
    $peek->iterate(
        sub {
            my ( $file, $data ) = @_;

            if ( $file =~ /$filename$/ ) {
                $contents = $data;
            }
        }
    );

    my $outfile = $path . "/" . $filename;

    open( my $fh, '>', $outfile )
      or die "Could not open file '$outfile' $!";
    print $fh $contents;
    close $fh;

    return $outfile;
}

1;
