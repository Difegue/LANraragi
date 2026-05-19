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

setup_redis_mock();

use_ok('LANraragi::Utils::Resizer');

note("resizer_factory returns VipsResizer when VIPS is available");
{
    local $ENV{LRR_DISABLE_VIPS} = 0;
    my $vips_mock = Test::MockModule->new('LANraragi::Utils::Vips');
    $vips_mock->redefine('is_vips_loaded', sub { 1 });

    my $resizer = LANraragi::Utils::Resizer::resizer_factory();
    isa_ok($resizer, 'LANraragi::Utils::VipsResizer',
        'Factory returns VipsResizer when VIPS is available');
}

note("resizer_factory returns ImageMagickResizer when LRR_DISABLE_VIPS is set");
{
    local $ENV{LRR_DISABLE_VIPS} = 1;
    my $vips_mock = Test::MockModule->new('LANraragi::Utils::Vips');
    $vips_mock->redefine('is_vips_loaded', sub { 1 });

    my $resizer = LANraragi::Utils::Resizer::resizer_factory();
    isa_ok($resizer, 'LANraragi::Utils::ImageMagickResizer',
        'Factory returns ImageMagickResizer when VIPS is disabled');
}

note("resizer_factory returns ImageMagickResizer when VIPS is not loaded");
{
    local $ENV{LRR_DISABLE_VIPS} = 0;
    my $vips_mock = Test::MockModule->new('LANraragi::Utils::Vips');
    $vips_mock->redefine('is_vips_loaded', sub { 0 });

    my $resizer = LANraragi::Utils::Resizer::resizer_factory();
    isa_ok($resizer, 'LANraragi::Utils::ImageMagickResizer',
        'Factory returns ImageMagickResizer when VIPS is not available');
}

note("get_resizer caches and returns the same instance");
{
    my $r1 = LANraragi::Utils::Resizer::get_resizer();
    my $r2 = LANraragi::Utils::Resizer::get_resizer();
    is($r1, $r2, 'get_resizer returns cached instance');
}

done_testing();
