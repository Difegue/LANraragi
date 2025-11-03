package LANraragi::Utils::Archive;

use v5.36;
use experimental 'try';
use feature 'state';

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
use POSIX qw(strerror);

use LANraragi::Utils::TempFolder qw(get_temp);
use LANraragi::Utils::Logging    qw(get_logger);
use LANraragi::Utils::Generic    qw(is_image shasum_str);
use LANraragi::Utils::Redis      qw(redis_decode redis_encode);
use LANraragi::Utils::Path       qw(create_path);
use LANraragi::Utils::Resizer    qw(get_resizer);

# Utilitary functions for handling Archives.
# Relies on Libarchive (for zip, cbz) and GhostScript (for PDFs).
use Exporter 'import';
our @EXPORT_OK =
  qw(is_file_in_archive extract_file_from_archive extract_single_file extract_thumbnail generate_thumbnail get_filelist);

sub is_pdf {
    my ( $filename, $dirs, $suffix ) = fileparse( $_[0], qr/\.[^.]*/ );
    return ( $suffix eq ".pdf" );
}

# use a resizer to make a thumbnail, height = 500px (view in index is 280px tall)
# If use_hq is true, highest-quality resizing will be used (if the resizer support different quality levels).
# If use_jxl is true, JPEG XL will be used instead of JPEG.
sub generate_thumbnail ( $data, $thumb_path, $use_hq, $use_jxl ) {
    my $quality = 50;
    $quality = 80 if $use_hq;

    my $resized = get_resizer()->resize_thumbnail( $data, $quality, $use_hq, $use_jxl ? "jxl" : "jpg" );
    if ( defined($resized) ) {
        open my $fh, '>:raw', $thumb_path or die;
        print $fh $resized;
        close($resized);
    } else {
        my $logger = get_logger( "Archive", "lanraragi" );
        $logger->debug("Couldn't create thumbnail!");
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
    my @filelist        = get_filelist($file, $id);
    my $requested_image = $filelist[ $page > 0 ? $page - 1 : 0 ];

    die "Requested image not found: $id page $page" unless $requested_image;
    $logger->debug("Extracting thumbnail for $id page $page from $requested_image");

    # Extract requested image to temp dir if it doesn't already exist
    my $arcimg = extract_single_file( $file, $requested_image );

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
    no warnings 'experimental::try';
    try {
        generate_thumbnail( $arcimg, $thumbname, $use_hq, $use_jxl );
    } catch ($e) {
        $logger->error("Thumbnail generation failed for archive '$file' entry '$requested_image' -> '$thumbname': $e");
        die $e;
    }

    return $thumbname;
}

#magical sort function used below
sub expand {
    my $file = shift;
    $file =~ s{(\d+)}{sprintf "%04d", $1}eg;
    return lc($file);
}

# Returns a list of all the files contained in the given archive with corresponding archive ID.
sub get_filelist ($archive, $arcid) {

    my $logger = get_logger( "Archive", "lanraragi" );

    my @files = ();

    if ( is_pdf($archive) ) {

        # For pdfs, extraction returns images from 1.jpg to x.jpg, where x is the pdf pagecount.
        # Using -dNOSAFER or --permit-file-read is required since GS 9.50, see https://github.com/doxygen/doxygen/issues/7290

        $archive = decode_utf8($archive);    # Decode path before passing it to GhostScript

        my $pages = `gs -q -dNOSAFER -sDEVICE=jpeg -c "($archive) (r) file runpdfbegin pdfpagecount = quit"`;
        for my $num ( 1 .. $pages ) {
            push @files, "$num.jpg";
        }
    } else {

        my $r = Archive::Libarchive::ArchiveRead->new;
        $r->support_filter_all;
        $r->support_format_all;

        $archive = create_path( $archive );

        my $ret = $r->open_filename( $archive, 10240 );
        if ( $ret != ARCHIVE_OK ) {
            my $open_filename_errno     = $r->errno;
            my $open_filename_strerr    = strerror($open_filename_errno);
            my $archive_exists          = -e $archive ? 'yes' : 'no';
            my $archive_readable        = -r $archive ? 'yes' : 'no';
            my $archive_size            = -e $archive ? (-s _) : 'NA';
            my $open_filename_err   = "Couldn't open archive '$archive' (id:$arcid, exists:$archive_exists; readable:$archive_readable; size:$archive_size)"
                . "libarchive: " . $r->error_string . " (errno $open_filename_errno: $open_filename_strerr)";
            $logger->error($open_filename_err);
            die $r->open_filename_err;
        }

        my $e = Archive::Libarchive::Entry->new;
        while ( $r->next_header($e) == ARCHIVE_OK ) {

            my $filesize = ( $e->size_is_set eq 64 ) ? $e->size : 0;
            my $filename = $e->pathname;

            unless ( is_image($filename) ) {
                $r->read_data_skip;
                next;
            }

            if ( is_apple_signature_like_path($filename) ) {
                my $peek = Archive::Libarchive::Peek->new( filename => $archive );
                if ( is_apple_signature( $peek, $filename ) ) {
                    $r->read_data_skip;
                    next;
                }
            }

            push @files, $filename;
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

    # Return files
    return @files;
}

# is_apple_signature(peek, path)
# Uses libarchive::peek to check AppleDouble/AppleSingle magic.
# Returns 1 if the file header matches a known Apple fork format, else 0.
sub is_apple_signature ( $peek, $path ) {
    my $logger = get_logger( "Archive", "lanraragi" );
    unless ( defined $peek && defined $path ) {
        $logger->warn("path or peek are undefined. Skipping.");
        return 0;
    }

    $logger->debug("Checking Apple fork magic for: $path");
    my $data = eval { $peek->file($path) };
    if ( !$data ) {
        $logger->debug("Peek returned no data for $path; not ignoring by signature");
        return 0;
    }
    if ( length($data) < 8 ) {
        $logger->debug("Data too short (<8 bytes) for $path; not ignoring by signature");
        return 0;
    }

    my $prefix = substr( $data, 0, 8 );
    return 0 unless defined $prefix && length($prefix) >= 8;

    # https://ciderpress2.com/formatdoc/AppleSingle-notes.html
    # AppleSingle: 00 05 16 00, AppleDouble: 00 05 16 07; both big-endian
    my $is_applesingle = substr( $prefix, 0, 4 ) eq "\x00\x05\x16\x00";
    my $is_appledouble = substr( $prefix, 0, 4 ) eq "\x00\x05\x16\x07";

    if ($is_appledouble) {
        $logger->debug("AppleDouble magic matched for $path");
        return 1;
    }
    if ($is_applesingle) {
        $logger->debug("AppleSingle magic matched for $path");
        return 1;
    }

    $logger->debug("Apple fork magic not matched for $path");
    return 0;
}

# check if image file is garbage or should be ignored.
sub is_apple_signature_like_path ($path) {
    my $p = $path // '';
    return 1 if $p =~ m{(^|/)__MACOSX/};
    my ($name) = fileparse($p);
    return 1 if defined $name && $name =~ /^\._/;
    return 0;
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

    my $peek = Archive::Libarchive::Peek->new( filename => create_path($archive) );
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

        # Decode path before passing it to GhostScript
        $archive = decode_utf8($archive);
        $outfile = decode_utf8($outfile);

        my $gscmd = "gs -dNOPAUSE -dFirstPage=$page -dLastPage=$page -sDEVICE=jpeg -r200 -o \"$outfile\" \"$archive\"";
        $logger->debug("Extracting page $filepath from PDF $archive");
        $logger->debug($gscmd);

        `$gscmd`;
        return Mojo::File->new($outfile)->slurp;
    } else {

        my $contents = "";
        my $peek     = Archive::Libarchive::Peek->new( filename => create_path($archive) );

        # This sub can receive either encoded or raw filenames, so we have to test for both.
        $contents = $peek->file($filepath) // $peek->file(redis_encode($filepath));
        if (defined($contents)) {
            $logger->debug("Found file $filepath in archive $archive");
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
