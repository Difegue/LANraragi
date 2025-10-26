use strict;
use warnings;
use utf8;

use Test::More;

BEGIN { use_ok('LANraragi::Utils::Archive'); }

subtest 'testing is_appledouble_like_path on macos junk files' => sub {
    ok( LANraragi::Utils::Archive::is_appledouble_like_path('__MACOSX/test.png'), '__MACOSX/ image matched' );
    ok( LANraragi::Utils::Archive::is_appledouble_like_path('folder/._image.png'), 'AppleDouble file matched' );
};

subtest 'testing is_appledouble_like_path on valid files' => sub {
    ok( !LANraragi::Utils::Archive::is_appledouble_like_path('folder/image.png'), 'PNG not matched' );
    ok( !LANraragi::Utils::Archive::is_appledouble_like_path('folder/sub/cover.jpg'), 'JPG not matched 1' );
    ok( !LANraragi::Utils::Archive::is_appledouble_like_path('folder._cover.jpg'), 'JPG not matched 2' );
};

done_testing();
