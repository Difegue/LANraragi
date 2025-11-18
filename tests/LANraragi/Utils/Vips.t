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

done_testing();

1;