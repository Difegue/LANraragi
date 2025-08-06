package LANraragi::Utils::Archive;

use v5.36;
use experimental 'try';

use strict;
use warnings;
use utf8;

use Time::HiRes qw(gettimeofday);
use File::Basename;
use File::Path qw(remove_tree make_path);
use File::Find qw(finddepth);
use File::Copy qw(move);
use File::Temp qw(tempfile);
use Encode;
use Encode::Guess qw/euc-jp shiftjis 7bit-jis/;
use Redis;
use Cwd;
use Data::Dumper;
use Archive::Libarchive qw( ARCHIVE_OK );
use Archive::Libarchive::Extract;
use Archive::Libarchive::Peek;
use File::Temp qw(tempdir);

use LANraragi::Utils::TempFolder qw(get_temp);
use LANraragi::Utils::Logging    qw(get_logger);
use LANraragi::Utils::Generic    qw(is_image shasum_str);

# Utilitary functions for handling Archives.
# Relies on Libarchive, ImageMagick and GhostScript for PDFs.
use Exporter 'import';
our @EXPORT_OK =
  qw(is_file_in_archive extract_file_from_archive extract_single_file extract_thumbnail generate_thumbnail get_filelist);

sub is_pdf {
    my ( $filename, $dirs, $suffix ) = fileparse( $_[0], qr/\.[^.]*/ );
    return ( $suffix eq ".pdf" );
}

# use ImageMagick to make a thumbnail, height = 500px (view in index is 280px tall)
# If use_hq is true, the scale algorithm will be used instead of sample.
# If use_jxl is true, JPEG XL will be used instead of JPEG.
sub generate_thumbnail ( $data, $thumb_path, $use_hq, $use_jxl ) {

    no warnings 'experimental::try';
    my $img = undef;
    try {
        require Image::Magick;
        $img = Image::Magick->new;

        my $format = $use_jxl ? 'jxl' : 'jpg';

        # For JPEG, the size option (or jpeg:size option) provides a hint to the JPEG decoder
        # that it can reduce the size on-the-fly during decoding. This saves memory because
        # it never has to allocate memory for the full-sized image
        if ( $format eq 'jpg' ) {
            $img->Set( option => 'jpeg:size=500x' );
        }

        $img->BlobToImage($data);

        # Only use the first frame (relevant for animated gif/webp/whatever)
        $img = $img->[0];

        # The "-scale" resize operator is a simplified, faster form of the resize command.
        if ($use_hq) {
            $img->Scale( geometry => '500x1000' );
        } else {    # Sample is very fast due to not applying filters.
            $img->Sample( geometry => '500x1000' );
        }

        $img->Set( quality => "50", magick => $format );
        $img->Write($thumb_path);
    } catch ($e) {

        # Magick is unavailable, do nothing
        my $logger = get_logger( "Archive", "lanraragi" );
        $logger->debug("ImageMagick is not available , skipping thumbnail generation: $e");
    } finally {
        if (defined($img)) {
            undef $img;
        }
    }
}

sub extract_pdf ( $destination, $to_extract ) {

    my $logger = get_logger( "Archive", "lanraragi" );

    # Raw Perl strings won't necessarily work in a terminal command, so we must decode the filepath here
    $logger->debug("Decoding PDF filepath $to_extract before sending it to GhostScript");

    eval {
        # Try a guess to regular japanese encodings first
        $to_extract = decode( "Guess", $to_extract );
    };

    # Fallback to utf8
    $to_extract = decode_utf8($to_extract) if $@;

    make_path($destination);

    my $gscmd = "gs -dNOPAUSE -sDEVICE=jpeg -r200 -o \"$destination/\%d.jpg\" \"$to_extract\"";
    $logger->debug("Sending PDF $to_extract to GhostScript...");
    $logger->debug($gscmd);

    `$gscmd`;

    return $destination;
}

# Extracts a thumbnail from the specified archive ID and page. Returns the path to the thumbnail.
# Non-cover thumbnails land in a folder named after the ID.
# Specify $set_cover if you want the given to page to be placed as the cover thumbnail instead.
# Thumbnails will be generated at low quality by default unless you specify use_hq=1.
sub extract_thumbnail ( $thumbdir, $id, $page, $set_cover, $use_hq ) {

    my $logger = get_logger( "Archive", "lanraragi" );

    # JPG is used for thumbnails by default
    my $use_jxl = LANraragi::Model::Config->get_jxlthumbpages;
    my $format  = $use_jxl ? 'jxl' : 'jpg';

    # Another subfolder with the first two characters of the id is used for FS optimization.
    my $subfolder = substr( $id, 0, 2 );
    make_path("$thumbdir/$subfolder");

    my $redis = LANraragi::Model::Config->get_redis;
    my $file  = $redis->hget( $id, "file" );

    # Get first image from archive using filelist
    my ( $images, $sizes ) = get_filelist($file);

    # Dereference arrays
    my @filelist        = @$images;
    my $requested_image = $filelist[ $page > 0 ? $page - 1 : 0 ];

    die "Requested image not found: $id page $page" unless $requested_image;
    $logger->debug("Extracting thumbnail for $id page $page from $requested_image");

    # Extract requested image to temp dir if it doesn't already exist
    my $arcimg       = extract_single_file( $file, $requested_image );

    my $thumbname;
    unless ($set_cover) {

        # Non-cover thumbnails land in a dedicated folder.
        $thumbname = "$thumbdir/$subfolder/$id/$page.$format";
        make_path("$thumbdir/$subfolder/$id");
    } else {

        $thumbname = "$thumbdir/$subfolder/$id.$format";

        # For cover thumbnails, grab the SHA-1 hash for tag research.
        # That way, no need to repeat a costly extraction later.
        my $shasum = shasum_str( $arcimg, 1 );
        $logger->debug("Setting thumbnail hash: $shasum");
        $redis->hset( $id, "thumbhash", $shasum );
        $redis->quit();
    }

    # Thumbnail generation
    generate_thumbnail( $arcimg, $thumbname, $use_hq, $use_jxl );

    return $thumbname;
}

#magical sort function used below
sub expand {
    my $file = shift;
    $file =~ s{(\d+)}{sprintf "%04d", $1}eg;
    return lc($file);
}

# Returns a list of all the files contained in the given archive.
sub get_filelist ($archive) {

    my $logger = get_logger( "Archive", "lanraragi" );

    my @files = ();
    my @sizes = ();

    if ( is_pdf($archive) ) {

        # For pdfs, extraction returns images from 1.jpg to x.jpg, where x is the pdf pagecount.
        # Using -dNOSAFER or --permit-file-read is required since GS 9.50, see https://github.com/doxygen/doxygen/issues/7290
        my $pages = `gs -q -dNOSAFER -sDEVICE=jpeg -c "($archive) (r) file runpdfbegin pdfpagecount = quit"`;
        for my $num ( 1 .. $pages ) {
            push @files, "$num.jpg";
            push @sizes, 0;
        }
    } else {

        my $r = Archive::Libarchive::ArchiveRead->new;
        $r->support_filter_all;
        $r->support_format_all;

        my $ret = $r->open_filename( $archive, 10240 );
        if ( $ret != ARCHIVE_OK ) {
            $logger->error( "Couldn't open archive, libarchive says:" . $r->error_string );
            die $r->error_string;
        }

        my $e = Archive::Libarchive::Entry->new;
        while ( $r->next_header($e) == ARCHIVE_OK ) {

            my $filesize = ( $e->size_is_set eq 64 ) ? $e->size : 0;
            my $filename = $e->pathname;
            if ( is_image($filename) ) {
                push @files, $filename;
                push @sizes, $filesize;
            }
            $r->read_data_skip;
        }

    }

    @files = sort { &expand($a) cmp &expand($b) } @files;

    # Move front cover pages to the start of a gallery, and miscellaneous pages such as translator credits to the end.
    my @cover_pages  = grep { /^(?!.*(back|end|rear|recover|discover)).*cover.*/i } @files;
    my @credit_pages = grep { /^end_card_save_file|notes\.[^\.]*$|note\.[^\.]*$|^artist_info|credit|^999.*/i } @files;

    # Get all the leftover pages
    my %credit_hash = map  { $_ => 1 } @credit_pages;
    my %cover_hash  = map  { $_ => 1 } @cover_pages;
    my @other_pages = grep { !$credit_hash{$_} && !$cover_hash{$_} } @files;
    @files = ( @cover_pages, @other_pages, @credit_pages );

    # Return files and sizes in a hashref
    return ( \@files, \@sizes );
}

# Uses libarchive::peek to figure out if $archive contains $file.
# Returns the exact in-archive path of the file if it exists, undef otherwise.
sub is_file_in_archive ( $archive, $wantedname ) {

    my $logger = get_logger( "Archive", "lanraragi" );

    if ( is_pdf($archive) ) {
        $logger->debug("$archive is a pdf, no sense looking for specific files");
        return;
    }

    $logger->debug("Iterating files of archive $archive, looking for '$wantedname'");
    $Data::Dumper::Useqq = 1;

    my $peek = Archive::Libarchive::Peek->new( filename => $archive );
    my $found;
    my @files = $peek->files;

    for my $file (@files) {
        $logger->debug( "Found file " . Dumper($file) );
        my ( $name, $path, $suffix ) = fileparse( $file, qr/\.[^.]*/ );

        # If the end of the file contains $wantedname we're good
        if ( "$name$suffix" =~ /$wantedname$/ ) {
            $logger->debug("OK!");
            $found = $file;
            last;
        }
    }

    return $found;
}

# Extract $file from $archive to $destination and returns the filesystem path it's extracted to.
# If the file doesn't exist in the archive, this will still create a file, but empty.
sub extract_single_file_to_file ( $archive, $filepath, $destination ) {

    my $logger = get_logger( "Archive", "lanraragi" );

    my $outfile = "$destination/$filepath";
    $logger->debug("Output for single file extraction: $outfile");

    # Remove file from $outfile and hand the full directory to make_path
    my ( $name, $path, $suffix ) = fileparse( $outfile, qr/\.[^.]*/ );
    make_path($path);

    my $contents = extract_single_file( $archive, $filepath );

    open( my $fh, '>', $outfile )
      or die "Could not open file '$outfile' $!";
    print $fh $contents;
    close $fh;

    return $outfile;
}

sub extract_single_file ( $archive, $filepath ) {

    my $logger = get_logger( "Archive", "lanraragi" );

    # Remove file from $outfile and hand the full directory to make_path
    if ( is_pdf($archive) ) {

        # For pdfs the filenames are always x.jpg, so we pull the page number from that
        my $page = $filepath;
        $page =~ s/^(\d+).jpg$/$1/;

        my ( $fh, $outfile ) = tempfile();
        my $gscmd = "gs -dNOPAUSE -dFirstPage=$page -dLastPage=$page -sDEVICE=jpeg -r200 -o \"$outfile\" \"$archive\"";
        $logger->debug("Extracting page $filepath from PDF $archive");
        $logger->debug($gscmd);

        `$gscmd`;
        return Mojo::File->new($outfile)->slurp;
    } else {

        my $contents = "";
        my $peek     = Archive::Libarchive::Peek->new( filename => $archive );
        my @files    = $peek->files;

        for my $name (@files) {
            my $decoded_name = LANraragi::Utils::Database::redis_decode($name);

            # This sub can receive either encoded or raw filenames, so we have to test for both.
            if ( $decoded_name eq $filepath || $name eq $filepath ) {
                $logger->debug("Found file $filepath in archive $archive");
                $contents = $peek->file($name);
                last;
            }
        }
        return $contents;
    }
}

# Variant for plugins.
# Extracts the file to a folder in /temp/plugin.
sub extract_file_from_archive ( $archive, $filename ) {

    my $path = get_temp . "/plugin";
    mkdir $path;

    my $tmp = tempdir( DIR => $path, CLEANUP => 1 );
    return extract_single_file_to_file( $archive, $filename, $tmp );
}

1;
