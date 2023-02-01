package LANraragi::Utils::Archive;

use strict;
use warnings;
use utf8;

use feature qw(say);
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
use Archive::Libarchive qw( ARCHIVE_OK );
use Archive::Libarchive::Extract;
use Archive::Libarchive::Peek;
use File::Temp qw(tempdir);

use LANraragi::Utils::TempFolder qw(get_temp);
use LANraragi::Utils::Logging qw(get_logger);
use LANraragi::Utils::Generic qw(is_image shasum);

# Utilitary functions for handling Archives.
# Relies on Libarchive, ImageMagick and GhostScript for PDFs.
use Exporter 'import';
our @EXPORT_OK =
  qw(is_file_in_archive extract_file_from_archive extract_single_file extract_archive extract_thumbnail generate_thumbnail get_filelist);

sub is_pdf {
    my ( $filename, $dirs, $suffix ) = fileparse( $_[0], qr/\.[^.]*/ );
    return ( $suffix eq ".pdf" );
}

# generate_thumbnail(original_image, thumbnail_location, use_hq)
# use ImageMagick to make a thumbnail, height = 500px (view in index is 280px tall)
# If use_hq is true, the scale algorithm will be used instead of sample.
sub generate_thumbnail {

    my ( $orig_path, $thumb_path, $use_hq ) = @_;
    my $img = Image::Magick->new;

    # For JPEG, the size option (or jpeg:size option) provides a hint to the JPEG decoder
    # that it can reduce the size on-the-fly during decoding. This saves memory because
    # it never has to allocate memory for the full-sized image
    $img->Set( option => 'jpeg:size=500x' );

    # If the image is a gif, only take the first frame
    if ( $orig_path =~ /\.gif$/ ) {
        $img->Read( $orig_path . "[0]" );
    } else {
        $img->Read($orig_path);
    }

    # The "-scale" resize operator is a simplified, faster form of the resize command.
    if ($use_hq) {
        $img->Scale( geometry => '500x1000' );
    } else {    # Sample is very fast due to not applying filters.
        $img->Sample( geometry => '500x1000' );
    }
    $img->Set( quality => "50", magick => "jpg" );
    $img->Write($thumb_path);
    undef $img;
}

# extract_archive(path, archive_to_extract, force)
# Extract the given archive to the given path.
# This sub won't re-extract files already present in the destination unless force = 1.
sub extract_archive {

    my ( $destination, $to_extract, $force_extract ) = @_;
    my $logger = get_logger( "Archive", "lanraragi" );
    $logger->debug("Fully extracting archive $to_extract");

    # PDFs are handled by Ghostscript (alas)
    if ( is_pdf($to_extract) ) {
        return extract_pdf( $destination, $to_extract );
    }

    # Prepare libarchive with a callback to skip over existing files (unless force=1)
    my $ae = Archive::Libarchive::Extract->new(
        filename => $to_extract,
        entry    => sub {
            my $e = shift;
            if ($force_extract) { return 1; }

            my $filename = $e->pathname;
            if ( -e "$destination/$filename" ) {
                $logger->debug("$filename already exists in $destination");
                return 0;
            }
            $logger->debug("Extracting $filename");

            # Pre-emptively create the file to signal we're working on it
            open( my $fh, ">", "$destination/$filename" )
              or
              $logger->error("Couldn't create placeholder file $destination/$filename (might be a folder?), moving on nonetheless");
            close $fh;
            return 1;
        }
    );

    # Extract to $destination. This method throws if extraction fails.
    $ae->extract( to => $destination );

    # Get extraction folder
    my $result_dir = $ae->to;
    my $cwd        = getcwd();

    # chdir back to the base cwd in case finddepth died midway
    chdir $cwd;

    # Return the directory we extracted the files to.
    return $result_dir;
}

sub extract_pdf {
    my ( $destination, $to_extract ) = @_;
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

    my $gscmd = "gs -dNOPAUSE -sDEVICE=jpeg -r200 -o '$destination/\%d.jpg' '$to_extract'";
    $logger->debug("Sending PDF $to_extract to GhostScript...");
    $logger->debug($gscmd);

    `$gscmd`;

    return $destination;
}

# extract_thumbnail(thumbnaildir, id, page, use_hq)
# Extracts a thumbnail from the specified archive ID and page. Returns the path to the thumbnail.
# Non-cover thumbnails land in a folder named after the ID. Specify page=0 if you want the cover.
# Thumbnails will be generated at low quality by default unless you specify use_hq=1.
sub extract_thumbnail {

    my ( $thumbdir, $id, $page, $use_hq ) = @_;
    my $logger = get_logger( "Archive", "lanraragi" );

    # Another subfolder with the first two characters of the id is used for FS optimization.
    my $subfolder = substr( $id, 0, 2 );
    my $thumbname = "$thumbdir/$subfolder/$id.jpg";
    make_path("$thumbdir/$subfolder");

    my $redis = LANraragi::Model::Config->get_redis;

    my $file = $redis->hget( $id, "file" );
    my $temppath = tempdir();

    # Get first image from archive using filelist
    my ( $images, $sizes ) = get_filelist($file);

    # Dereference arrays
    my @filelist = @$images;
    my $requested_image = $filelist[ $page > 0 ? $page - 1 : 0 ];

    die "Requested image not found" unless $requested_image;
    $logger->debug("Extracting thumbnail for $id page $page from $requested_image");

    # Extract first image to temp dir
    my $arcimg = extract_single_file( $file, $requested_image, $temppath );

    if ( $page > 0 ) {

        # Non-cover thumbnails land in a dedicated folder.
        $thumbname = "$thumbdir/$subfolder/$id/$page.jpg";
        make_path("$thumbdir/$subfolder/$id");
    } else {

        # For cover thumbnails, grab the SHA-1 hash for tag research.
        # That way, no need to repeat a costly extraction later.
        my $shasum = shasum( $arcimg, 1 );
        $redis->hset( $id, "thumbhash", $shasum );
        $redis->quit();
    }

    # Thumbnail generation
    generate_thumbnail( $arcimg, $thumbname, $use_hq );

    # Clean up safe folder
    remove_tree($temppath);
    return $thumbname;
}

#magical sort function used below
sub expand {
    my $file = shift;
    $file =~ s{(\d+)}{sprintf "%04d", $1}eg;
    return lc($file);
}

# get_filelist($archive)
# Returns a list of all the files contained in the given archive.
sub get_filelist {

    my $archive = $_[0];
    my @files   = ();
    my @sizes   = ();

    if ( is_pdf($archive) ) {

        # For pdfs, extraction returns images from 1.jpg to x.jpg, where x is the pdf pagecount.
        # Using -dNOSAFER or --permit-file-read is required since GS 9.50, see https://github.com/doxygen/doxygen/issues/7290
        my $pages = `gs -q -dNOSAFER -c "($archive) (r) file runpdfbegin pdfpagecount = quit"`;
        for my $num ( 1 .. $pages ) {
            push @files, "$num.jpg";
            push @sizes, 0;
        }
    } else {

        my $r = Archive::Libarchive::ArchiveRead->new;
        $r->support_filter_all;
        $r->support_format_all;

        my $ret = $r->open_filename( $archive, 10240 );
        die unless ( $ret == ARCHIVE_OK );

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
    my @cover_pages      = grep { /^(?!.*(back|end|rear|recover)).*cover.*/i } @files;
    my @credit_pages     = grep { /^999999|^bumper|^ramble\.[^\.]*$|^end_card_save_file|notes\.[^\.]*$|note\.[^\.]*$|^artist_info|credit|999nhnl\.|^group\.[^\.]*$/i } @files;
    # Get all the leftover pages
    my %credit_hash = map { $_ => 1 } @credit_pages;
    my %cover_hash = map { $_ => 1 } @cover_pages;
    my @other_pages = grep { !$credit_hash{$_} && !$cover_hash{$_} } @files;
@files = ( @cover_pages, @other_pages, @credit_pages );
    # Return files and sizes in a hashref
    return ( \@files, \@sizes );
}

# is_file_in_archive($archive, $file)
# Uses libarchive::peek to figure out if $archive contains $file.
# Returns the exact in-archive path of the file if it exists, undef otherwise.
sub is_file_in_archive {

    my ( $archive, $wantedname ) = @_;
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

# extract_single_file ($archive, $file, $destination)
# Extract $file from $archive to $destination and returns the filesystem path it's extracted to.
# If the file doesn't exist in the archive, this will still create a file, but empty.
sub extract_single_file {

    my ( $archive, $filepath, $destination ) = @_;
    my $logger = get_logger( "Archive", "lanraragi" );

    my $outfile = "$destination/$filepath";
    $logger->debug("Output for single file extraction: $outfile");

    # Remove file from $outfile and hand the full directory to make_path
    my ( $name, $path, $suffix ) = fileparse( $outfile, qr/\.[^.]*/ );
    make_path($path);

    if ( is_pdf($archive) ) {

        # For pdfs the filenames are always x.jpg, so we pull the page number from that
        my $page = $filepath;
        $page =~ s/^(\d+).jpg$/$1/;

        my $gscmd = "gs -dNOPAUSE -dFirstPage=$page -dLastPage=$page -sDEVICE=jpeg -r200 -o '$outfile' '$archive'";
        $logger->debug("Extracting page $filepath from PDF $archive");
        $logger->debug($gscmd);

        `$gscmd`;
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

        open( my $fh, '>', $outfile )
          or die "Could not open file '$outfile' $!";
        print $fh $contents;
        close $fh;
    }

    return $outfile;
}

# extract_file_from_archive($archive, $file)
# Variant for plugins.
# Extracts the file with a timestamp to a folder in /temp/plugin.
sub extract_file_from_archive {

    my ( $archive, $filename ) = @_;

    # Timestamp extractions in microseconds
    my ( $seconds, $microseconds ) = gettimeofday;
    my $stamp = "$seconds-$microseconds";
    my $path  = get_temp . "/plugin/$stamp";
    mkdir get_temp . "/plugin";
    mkdir $path;

    return extract_single_file( $archive, $filename, $path );
}

1;
