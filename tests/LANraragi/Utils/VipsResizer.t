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

use Image::Magick;

setup_redis_mock();

use_ok('LANraragi::Utils::VipsResizer');

my $image_path = "$cwd/tests/samples/reader.jpg";
open my $fh, '<:raw', $image_path or die "Cannot open $image_path: $!";
my $image_data = do {
    local $/;
    <$fh>
};
close $fh;

note("testing page resizing");
{
    my $resizer = LANraragi::Utils::VipsResizer->new;

    my $resized_data = $resizer->resize_page($image_data, 80, 'jpg');
    ok(defined $resized_data, "Image was resized");

    my $img = Image::Magick->new;
    $img->BlobToImage($resized_data);
    my $width = $img->Get('width');
    is($width, 1064, "Page image width is 1064");
}

note("testing thumbnail resizing");
{
    my $resizer = LANraragi::Utils::VipsResizer->new;

    my $resized_data = $resizer->resize_thumbnail($image_data, 80, 0, 'jpg');
    ok(defined $resized_data, "Image was resized");

    my $img = Image::Magick->new;
    $img->BlobToImage($resized_data);
    my $width = $img->Get('width');
    is($width, 500, "Thumbnail width is 500");
}

done_testing();
