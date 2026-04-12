use strict;
use warnings;
use utf8;

use Cwd qw(getcwd);
use Test::More;

my $cwd = getcwd();
require "$cwd/tests/mocks.pl";
setup_redis_mock();

BEGIN { use_ok('LANraragi::Utils::Path'); }

note('testing package_to_path...');

{
    my $result = LANraragi::Utils::Path::package_to_path("LANraragi::Plugin::Metadata::Example");
    is( $result, "LANraragi/Plugin/Metadata/Example.pm", "multi-segment package" );
}

{
    my $result = LANraragi::Utils::Path::package_to_path("Foo::Bar");
    is( $result, "Foo/Bar.pm", "two-segment package" );
}

{
    my $result = LANraragi::Utils::Path::package_to_path("Single");
    is( $result, "Single.pm", "single-segment package" );
}

done_testing();
