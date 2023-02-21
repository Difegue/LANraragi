# LANraragi::Plugin::Metadata::ComicInfo
use strict;
use warnings;
use utf8;
use Data::Dumper;
use File::Temp qw(tempfile);
use File::Copy "cp";

use Cwd qw( getcwd );

use Test::Trap;
use Test::More;
use Test::Deep;

my $cwd     = getcwd();
my $SAMPLES = "$cwd/tests/samples";
require "$cwd/tests/mocks.pl";

use_ok('LANraragi::Plugin::Metadata::ComicInfo');

note("00 - [れむ] 夜伽妻 [DL版]");
{
    my ( $fh, $filename ) = tempfile();
    cp( $SAMPLES . "/comicinfo/00_sample.xml", $fh );

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::ComicInfo::get_plugin_logger         = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::ComicInfo::extract_file_from_archive = sub { $filename };
    local *LANraragi::Plugin::Metadata::ComicInfo::is_file_in_archive        = sub { 1 };

    my %dummyhash = ( file_path => "test" );

    # Since this is calling the sub directly and not in an object context,
    # we pass a dummy string as first parameter to replace the object.
    my $returned_tags = LANraragi::Plugin::Metadata::ComicInfo::get_tags( "", \%dummyhash);

    my $expected_tags = "Ahegao, Bbw, Big Areolae, Big Ass, Big Breasts, Big Nipples, Big Penis, Blowjob, Bondage, Cheating, Crotch Tattoo, Dark Skin, Facial Hair, Filming, Glasses, Glasses, Gyaru, Hairy, Huge Breasts, Impregnation, Maid, Milf, Nakadashi, Netorare, Oil, Paizuri, Pregnant, Prostitution, Schoolgirl Uniform, Swinging, Tall Girl, Tankoubon, Very Long Hair, Voyeurism, Widow, X-Ray";
    is( $returned_tags,  $expected_tags, "correct tags" );
}

note("01 - COMIC Anthurium 2021-09 [Digital]");
{
    my ( $fh, $filename ) = tempfile();
    cp( $SAMPLES . "/comicinfo/01_sample.xml", $fh );

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::ComicInfo::get_plugin_logger         = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::ComicInfo::extract_file_from_archive = sub { $filename };
    local *LANraragi::Plugin::Metadata::ComicInfo::is_file_in_archive        = sub { 1 };

    my %dummyhash = ( file_path => "test" );

    # Since this is calling the sub directly and not in an object context,
    # we pass a dummy string as first parameter to replace the object.
    my $returned_tags = LANraragi::Plugin::Metadata::ComicInfo::get_tags( "", \%dummyhash);

    my $expected_tags = "Anthology, Beauty Mark, Big Breasts, Glasses, Group, Gyaru, Lolicon, Paizuri, Rape, Schoolboy Uniform, Schoolgirl Uniform";
    is( $returned_tags,  $expected_tags, "correct tags" );
}

note("02 - よつばと！ 第01巻");
{
    my ( $fh, $filename ) = tempfile();
    cp( $SAMPLES . "/comicinfo/02_sample.xml", $fh );

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::ComicInfo::get_plugin_logger         = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::ComicInfo::extract_file_from_archive = sub { $filename };
    local *LANraragi::Plugin::Metadata::ComicInfo::is_file_in_archive        = sub { 1 };

    my %dummyhash = ( file_path => "test" );

    # Since this is calling the sub directly and not in an object context,
    # we pass a dummy string as first parameter to replace the object.
    my $returned_tags = LANraragi::Plugin::Metadata::ComicInfo::get_tags( "", \%dummyhash);

    my $expected_tags = "Comedy, Shounen, Slice of Life";
    is( $returned_tags,  $expected_tags, "correct tags" );
}




done_testing();