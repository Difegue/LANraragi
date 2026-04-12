use strict;
use warnings;
use utf8;

use Cwd qw(getcwd);
use File::Spec;
use Test::More;

my $cwd = getcwd();
require "$cwd/tests/mocks.pl";
setup_redis_mock();

BEGIN { use_ok('LANraragi::Utils::Path'); }

note('testing package_to_path...');

{
    my $result   = LANraragi::Utils::Path::package_to_path("LANraragi::Plugin::Metadata::Example");
    my $expected = File::Spec->catfile("LANraragi", "Plugin", "Metadata", "Example") . ".pm";
    is( $result, $expected, "multi-segment package" );
}

{
    my $result   = LANraragi::Utils::Path::package_to_path("Foo::Bar");
    my $expected = File::Spec->catfile("Foo", "Bar") . ".pm";
    is( $result, $expected, "two-segment package" );
}

{
    my $result   = LANraragi::Utils::Path::package_to_path("Single");
    my $expected = File::Spec->catfile("Single") . ".pm";
    is( $result, $expected, "single-segment package" );
}

done_testing();
