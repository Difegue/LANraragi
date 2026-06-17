use strict;
use warnings;
use v5.36;

use Test::More;
use Test::MockModule qw(strict);
use Cwd qw(getcwd);

my $cwd = getcwd();
require "$cwd/tests/mocks.pl";

my $module = Test::MockModule->new('LANraragi::Utils::Logging');
$module->redefine('get_logger', get_logger_mock());

use LANraragi::Utils::Vips;

if (!LANraragi::Utils::Vips::is_vips_loaded) {
    plan skip_all => "libvips is not installed";
};

use_ok('LANraragi::Utils::Vips');

note("test loading an image");
{
    my $image_path = "$cwd/tests/samples/reader.jpg";
    my $img = LANraragi::Utils::Vips::new_from_file($image_path);
    isnt($img, undef, "Should get an image");
    is(LANraragi::Utils::Vips::width($img), 2233, "Should be correct width");
    is(LANraragi::Utils::Vips::height($img), 1828, "Should be correct height");
}


note("test creating a blank image");
{
    my $img = LANraragi::Utils::Vips::black(320, 200);
    isnt($img, undef, "Should get an image");
    is(LANraragi::Utils::Vips::width($img), 320, "Should be correct width");
    is(LANraragi::Utils::Vips::height($img), 200, "Should be correct height");
}

note("test reading a pdf");
{
    my $doc_path = "$cwd/tests/samples/doc.pdf";
    my $pdf = LANraragi::Utils::Vips::new_from_file($doc_path);
    is(LANraragi::Utils::Vips::get_n_pages($pdf), 4, "Should get 4 pages");
    LANraragi::Utils::Vips::unref_image($pdf);

    # 0 = first page, 3 = last (fourth) page
    my $p4 = LANraragi::Utils::Vips::pdfload_page_dpi($doc_path, 3, 72);
    is(LANraragi::Utils::Vips::width($p4), 231, "Should be 231 pixels wide in 72 DPI");
    LANraragi::Utils::Vips::unref_image($p4);

    $p4 = LANraragi::Utils::Vips::pdfload_page_dpi($doc_path, 3, 90);
    is(LANraragi::Utils::Vips::width($p4), 288, "Should be 288 pixels wide in 90 DPI");
}

done_testing();

1;