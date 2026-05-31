use strict;
use warnings;
use utf8;

use Test::More;
use Test::Deep;
use Mojo::Path;

BEGIN { use_ok('LANraragi::Utils::Routing'); }

note('testing is_traversal_safe ...');
{
    my $p = Mojo::Path->new("/js/safe/path");
    my $result = LANraragi::Utils::Routing::is_traversal_safe($p);
    is( $result, 1, "Simple safe path should pass" );
}

{
    my $p = Mojo::Path->new("/js/../robots.txt");
    my $result = LANraragi::Utils::Routing::is_traversal_safe($p);
    is( $result, 1, "Traversal within directory should pass" );
}

{
    my $p = Mojo::Path->new("/js/foo/./bar");
    my $result = LANraragi::Utils::Routing::is_traversal_safe($p);
    is( $result, 1, "Path with dot segments should pass" );
}

{
    my $p = Mojo::Path->new("/js/../../etc/passwd");
    my $result = LANraragi::Utils::Routing::is_traversal_safe($p);
    is( $result, 0, "Path traversing past root should be blocked" );
}

{
    my $p = Mojo::Path->new("/../absolute");
    my $result = LANraragi::Utils::Routing::is_traversal_safe($p);
    is( $result, 0, "Path with leading parent traversal should be blocked" );
}

done_testing();
