package LANraragi::Utils::Archive;

use strict;
use warnings;
use utf8;

use Time::HiRes qw(gettimeofday);
use File::Basename;
use File::Path qw(remove_tree make_path);
use File::Find qw(finddepth);
use File::Copy qw(move);
use Encode;
use Encode::Guess qw/euc-jp shiftjis 7bit-jis/;
use Redis;
use Cwd;
use Data::Dumper;
use Image::Magick;
use Archive::Peek::Libarchive;
use Archive::Extract::Libarchive;

use LANraragi::Utils::TempFolder qw(get_temp);
use LANraragi::Utils::Logging qw(get_logger);
use LANraragi::Utils::Generic qw(is_image shasum);

# Utilitary functions for handling Archives.
# Relies on Libarchive and ImageMagick.
use Exporter 'import';
our @EXPORT_OK = qw(is_file_in_archive extract_file_from_archive extract_archive extract_thumbnail generate_thumbnail);

sub is_pdf {
    my ( $filename, $dirs, $suffix ) = fileparse( $_[0], qr/\.[^.]*/ );
    return ( $suffix eq ".pdf" );
}

# generate_thumbnail(original_image, thumbnail_location)
# use ImageMagick to make a thumbnail, height = 500px (view in index is 280px tall)
sub generate_thumbnail {

    my ( $orig_path, $thumb_path ) = @_;
    my $img = Image::Magick->new;

    $img->Read($orig_path);
    $img->Thumbnail( geometry => '500x1000' );
    $img->Set( quality => "50", magick => "jpg" );
    $img->Write($thumb_path);
    undef $img;
}

#extract_archive(path, archive_to_extract)
#Extract the given archive to the given path.
sub extract_archive {

    my ( $destination, $to_extract ) = @_;

    # PDFs are handled by Ghostscript (alas)
    if ( is_pdf($to_extract) ) {
        return extract_pdf( $destination, $to_extract );
    }

    # build an Archive::Extract object
    my $ae = Archive::Extract::Libarchive->new( archive => $to_extract );

    #Extract to $destination. Report if it fails.
    my $ok = $ae->extract( to => $destination ) or die $ae->error;

    #Rename files and folders to an encoded version
    my $cwd = getcwd();

    finddepth(
        sub {
            unless ( $_ eq '.' ) {

                my $filename = $_;
                eval {
                    # Try a guess to regular japanese encodings first
                    $filename = decode( "Guess", $filename );
                };

                # Fallback to utf8
                $filename = decode_utf8($filename) if $@;

                # Re-encode the result to ASCII and move the file to said result name.
                # Use Encode's coderef feature to map non-ascii characters to their Unicode codepoint equivalent.
                $filename = encode( "ascii", $filename, sub { sprintf "%04X", shift } );

                if ( length $filename > 254 ) {
                    $filename = substr( $filename, 0, 254 );
                }

                move( $_, $filename );
            }
        },
        $ae->extract_path
    );

    # chdir back to the base cwd in case finddepth died midway
    chdir $cwd;

    # dir that was extracted to
    return $ae->extract_path;
}

sub extract_pdf {
    my ( $destination, $to_extract ) = @_;

    make_path($destination);
    my $logger = get_logger( "Archive", "lanraragi" );

    my $gscmd = "gs -dNOPAUSE -sDEVICE=jpeg -r200 -o '$destination/\%d.jpg' '$to_extract'";
    $logger->debug("Sending PDF $to_extract to GhostScript...");
    $logger->debug($gscmd);

    `$gscmd`;

    return $destination;
}

#extract_thumbnail(dirname, id)
#Finds the first image for the specified archive ID and makes it the thumbnail.
sub extract_thumbnail {

    my ( $dirname, $id ) = @_;

    # Another subfolder with the first two characters of the id is used for FS optimization.
    my $subfolder = substr($id, 0, 2);
    my $thumbname = "$dirname/thumb/$subfolder/$id.jpg";

    make_path("$dirname/thumb/$subfolder");
    my $redis = LANraragi::Model::Config->get_redis;

    my $file     = $redis->hget( $id, "file" );
    my $temppath = get_temp . "/thumb/$id/";

    # Make sure the thumb temp dir exists
    make_path($temppath);

    my $arcimg = "";
    if ( is_pdf($file) ) {
        $arcimg = extract_page_pdf( $file, $temppath );
    } else {
        $arcimg = extract_page_libarchive( $file, $temppath );
    }

    #While we have the image, grab its SHA-1 hash for tag research.
    #That way, no need to repeat the costly extraction later.
    my $shasum = shasum( $arcimg, 1 );
    $redis->hset( $id, "thumbhash", encode_utf8($shasum) );
    $redis->quit();

    #Thumbnail generation
    generate_thumbnail( $arcimg, $thumbname );

    #Delete the previously extracted file.
    unlink $arcimg;

    # Clean up safe folder
    remove_tree($temppath);
    return $thumbname;
}

sub extract_page_pdf {

    my ( $file, $temppath ) = @_;
    mkdir $temppath;
    my $output = $temppath . "pdf_first_page.jpg";

    my $logger = get_logger( "Archive", "lanraragi" );

    my $gscmd = "gs -dNOPAUSE -dLastPage=1 -sDEVICE=jpeg -r72 -o '$output' '$file'";
    $logger->debug("Sending PDF $file to GhostScript...");
    $logger->debug($gscmd);

    `$gscmd`;

    return $output;
}

sub extract_page_libarchive {

    my ( $file, $temppath ) = @_;

    # Get all the files of the archive
    my $peek  = Archive::Peek::Libarchive->new( filename => $file );
    my @files = $peek->files();
    my @extracted;

    # Filter out non-images
    foreach my $file (@files) {
        if ( is_image($file) ) {
            push @extracted, $file;
        }
    }

    @extracted = sort { lc($a) cmp lc($b) } @extracted;

    # Get the first file of the list and spit it out into a file
    my $contents = $peek->file( $extracted[0] );

    # The name sometimes comes with the folder as a bonus, so we use basename to filter it out.
    my ( $filename, $dirs, $suffix ) = fileparse( $extracted[0], qr/\.[^.]*/ );

    # Move the extracted file to a safe folder to avoid concurrent overwrites
    my $arcimg = $temppath . $filename . $suffix;

    open( my $fh, '>', $arcimg )
      or die "Could not open file '$arcimg' $!";
    print $fh $contents;
    close $fh;

    return $arcimg;
}

#is_file_in_archive($archive, $file)
#Uses libarchive::peek to figure out if $archive contains $file.
#Returns 1 if it does exist, 0 otherwise.
sub is_file_in_archive {

    my ( $archive, $wantedname ) = @_;

    my $logger = get_logger( "Archive", "lanraragi" );

    if ( is_pdf($archive) ) {
        $logger->debug("$archive is a pdf, no sense looking for specific files");
        return 0;
    }

    $logger->debug("Iterating files of archive $archive, looking for '$wantedname'");
    $Data::Dumper::Useqq = 1;

    my $peek  = Archive::Peek::Libarchive->new( filename => $archive );
    my $found = 0;
    $peek->iterate(
        sub {
            my $name = $_[0];
            $logger->debug( "Found file " . Dumper($name) );

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
    my $path  = get_temp . "/plugin/$stamp";
    mkdir get_temp . "/plugin";
    mkdir $path;
    my $contents = "";

    unless ( is_pdf($archive) ) {
        my $peek = Archive::Peek::Libarchive->new( filename => $archive );
        $peek->iterate(
            sub {
                my ( $file, $data ) = @_;

                if ( $file =~ /$filename$/ ) {
                    $contents = $data;
                }
            }
        );
    }

    my $outfile = $path . "/" . $filename;

    open( my $fh, '>', $outfile )
      or die "Could not open file '$outfile' $!";
    print $fh $contents;
    close $fh;

    return $outfile;
}

1;
