use strict;
use warnings;
use utf8;

use Test::More;
use Archive::Tar;
use File::Temp qw(tempdir);
use Mojo::File 'path';

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

note('testing get_filelist on archive...');
{
    local $ENV{LRR_FORCE_DEBUG}     = 1;
    my $tmpdir                      = tempdir(CLEANUP => 1);
    my $tarpath                     = "$tmpdir/test.tar";

    my $tar                         = Archive::Tar->new;
    my $img_path                    = 'tests/samples/reader.jpg';
    my $img_data                    = path($img_path)->slurp;
    $tar->add_data('cover.jpg', $img_data);
    $tar->write($tarpath);
    my @files = LANraragi::Utils::Archive::get_filelist($tarpath, 'arcid-ok');

    is_deeply(\@files, ['cover.jpg'], 'get_filelist returns the image entry from tar');
}

note('testing is_embedded_thumbnail_path...');
{
    my %cases = (
        'thumb.webp'    => 1,
        'THUMB.JPG'     => 1,
        'sub/thumb.jpg' => 0,
        'thumbnail.jpg' => 0,
        '01.jpg'        => 0,
    );

    for my $input ( sort keys %cases ) {
        my $result = LANraragi::Utils::Archive::is_embedded_thumbnail_path($input);
        is ( $result, $cases{$input}, "Embedded thumbnail check for '$input'" );
    }
}

note('testing get_filelist ignores embedded thumbnail...');
{
    local $ENV{LRR_FORCE_DEBUG}     = 1;
    my $tmpdir                      = tempdir(CLEANUP => 1);
    my $tarpath                     = "$tmpdir/test.tar";

    my $tar                         = Archive::Tar->new;
    my $img_data                    = path('tests/samples/reader.jpg')->slurp;
    $tar->add_data('01.jpg', $img_data);
    $tar->add_data('thumb.webp', $img_data);
    $tar->write($tarpath);
    my @files = LANraragi::Utils::Archive::get_filelist($tarpath, 'arcid-thumb');

    is_deeply(\@files, ['01.jpg'], 'get_filelist skips thumb.webp at the archive root');
}

note('testing get_filelist on missing archive...');
{
    local $ENV{LRR_FORCE_DEBUG}     = 1;
    my $tmpdir                      = tempdir(CLEANUP => 1);
    my $missing                     = "$tmpdir/does_not_exist.zip";

    eval {
        LANraragi::Utils::Archive::get_filelist($missing, 'arcid-missing');
        1;
    };
    my $died = $@;

    ok($died, 'get_filelist died for missing archive');
    like($died, qr/Couldn't open archive/, 'error message mentions open failure');
}

done_testing();
