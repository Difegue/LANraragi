use strict;
use warnings;
use utf8;

use Test::More;

BEGIN { use_ok('LANraragi::Utils::Archive'); }

note('testing is_apple_signature_like_path...');
{
    my $input    = '__MACOSX/test.png';
    my $expected = 1;
    my $result   = LANraragi::Utils::Archive::is_apple_signature_like_path($input);

    is ( $result, $expected, "File pattern should match apple signature" );
}

{
    my $input    = 'folder/._image.png';
    my $expected = 1;
    my $result   = LANraragi::Utils::Archive::is_apple_signature_like_path($input);

    is ( $result, $expected, "File pattern should match apple signature 2" );
}

{
    my $input    = 'folder/image.png';
    my $expected = 0;
    my $result   = LANraragi::Utils::Archive::is_apple_signature_like_path($input);

    is ( $result, $expected, "Valid PNG should not match apple signature" );
}

{
    my $input    = 'folder/sub/cover.jpg';
    my $expected = 0;
    my $result   = LANraragi::Utils::Archive::is_apple_signature_like_path($input);

    is ( $result, $expected, "Valid JPG should not match apple signature" );
}

{
    my $input    = 'folder._cover.jpg';
    my $expected = 0;
    my $result   = LANraragi::Utils::Archive::is_apple_signature_like_path($input);

    is ( $result, $expected, "Valid JPG should not match apple signature 2" );
}

done_testing();
