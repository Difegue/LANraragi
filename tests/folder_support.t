use strict;
use warnings;
use utf8;
use Cwd;

use Test::More;
use File::Path qw(make_path remove_tree);
use File::Temp qw(tempdir);

my $cwd = getcwd;
require $cwd . "/tests/mocks.pl";
setup_redis_mock();

use_ok('LANraragi::Utils::Generic');
use_ok('LANraragi::Utils::Database');
use_ok('LANraragi::Utils::Archive');

# Create a temporary directory structure for testing
my $tmpdir = tempdir( CLEANUP => 1 );

# Structure:
#   leaf_with_images/       -> CONTENT (leaf, has images)
#     page1.jpg
#     page2.png
#   series/                 -> NOT content (has subdirs with images)
#     chapter1/             -> CONTENT (leaf, has images)
#       page1.jpg
#     chapter2/             -> CONTENT (leaf, has images)
#       page1.jpg
#   empty_folder/           -> NOT content (no images)
#   leaf_no_images/         -> NOT content (files but no images)
#     readme.txt

make_path("$tmpdir/leaf_with_images");
make_path("$tmpdir/series/chapter1");
make_path("$tmpdir/series/chapter2");
make_path("$tmpdir/empty_folder");
make_path("$tmpdir/leaf_no_images");

# Create dummy image files (just need to exist with correct extensions)
for my $f ("$tmpdir/leaf_with_images/page1.jpg", "$tmpdir/leaf_with_images/page2.png",
           "$tmpdir/series/chapter1/page1.jpg",
           "$tmpdir/series/chapter2/page1.jpg") {
    open my $fh, '>', $f or die "Cannot create $f: $!";
    print $fh "fake image data for $f\n";
    close $fh;
}

open my $fh, '>', "$tmpdir/leaf_no_images/readme.txt" or die $!;
print $fh "not an image";
close $fh;

# Test is_content_folder
subtest 'is_content_folder' => sub {
    ok( LANraragi::Utils::Generic::is_content_folder("$tmpdir/leaf_with_images"),
        "leaf_with_images is a content folder" );

    ok( !LANraragi::Utils::Generic::is_content_folder("$tmpdir/series"),
        "series is NOT a content folder (has subdirs with images)" );

    ok( LANraragi::Utils::Generic::is_content_folder("$tmpdir/series/chapter1"),
        "chapter1 is a content folder" );

    ok( LANraragi::Utils::Generic::is_content_folder("$tmpdir/series/chapter2"),
        "chapter2 is a content folder" );

    ok( !LANraragi::Utils::Generic::is_content_folder("$tmpdir/empty_folder"),
        "empty_folder is NOT a content folder" );

    ok( !LANraragi::Utils::Generic::is_content_folder("$tmpdir/leaf_no_images"),
        "leaf_no_images is NOT a content folder (no images)" );

    ok( !LANraragi::Utils::Generic::is_content_folder("$tmpdir/nonexistent"),
        "nonexistent path is NOT a content folder" );
};

# Test compute_id for directories
subtest 'compute_id for directory' => sub {
    my $id = LANraragi::Utils::Database::compute_id("$tmpdir/leaf_with_images");
    ok( defined $id && length($id) == 40, "compute_id returns a 40-char hex digest for a directory" );

    my $id2 = LANraragi::Utils::Database::compute_id("$tmpdir/leaf_with_images");
    is( $id, $id2, "compute_id is deterministic for the same directory" );

    my $id3 = LANraragi::Utils::Database::compute_id("$tmpdir/series/chapter1");
    isnt( $id, $id3, "different directories produce different IDs" );
};

# Test get_filelist for directories
subtest 'get_filelist for directory' => sub {
    my @files = LANraragi::Utils::Archive::get_filelist("$tmpdir/leaf_with_images", "test");
    is( scalar @files, 2, "leaf_with_images contains 2 image files" );

    my @ch1_files = LANraragi::Utils::Archive::get_filelist("$tmpdir/series/chapter1", "test");
    is( scalar @ch1_files, 1, "chapter1 contains 1 image file" );

    # Filenames should be relative paths
    for my $f (@files) {
        ok( $f !~ /^\Q$tmpdir\E/, "File path '$f' is relative, not absolute" );
    }
};

# Test extract_single_file for directories
subtest 'extract_single_file for directory' => sub {
    my @files = LANraragi::Utils::Archive::get_filelist("$tmpdir/leaf_with_images", "test");
    my $content = LANraragi::Utils::Archive::extract_single_file("$tmpdir/leaf_with_images", $files[0]);
    ok( defined $content && length($content) > 0, "extract_single_file returns content from directory" );
};

done_testing();
