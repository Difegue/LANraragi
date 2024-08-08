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

    my $expected_group_tag = "group:Achumuchi, group:Ashita, group:Cool Kyou Shinja, group:Danimaru, group:Eba, group:Emuo, group:Fushoku, group:Inukami Inoji, group:Itaba Hiroshi, group:Kaiduka, group:Ken Sogen, group:Kosuke Haruhito, group:Maeda Momo, group:Miyano Kintarou, group:Rei, group:Sasahiro, group:Sekine Hajime, group:Ushinomiya, group:Yamamoto Ahiru, group:Yamamoto Zenzen";
    my $expected_artist_tag = "artist:Achumuchi, artist:Ashita, artist:Cool Kyou Shinja, artist:Danimaru, artist:Eba, artist:Emuo, artist:Fushoku, artist:Inukami Inoji, artist:Itaba Hiroshi, artist:Kaiduka, artist:Ken Sogen, artist:Kosuke Haruhito, artist:Maeda Momo, artist:Miyano Kintarou, artist:Rei, artist:Sasahiro, artist:Sekine Hajime, artist:Ushinomiya, artist:Yamamoto Ahiru, artist:Yamamoto Zenzen";
    my $expected_source_tag = "source:https://nhentai.net/g/369909/";
    my $expected_lang_tag = "language:ja";
    my $expected_genre_tags = "Anal, Anthology, Beauty Mark, Big Breasts, Collar, Defloration, Eye-Covering Bang, Glasses, Gyaru, Huge Breasts, Incest, Inverted Nipples, Leotard, Long Tongue, Maid, Netorare, Pantyhose, Piercing, Ponytail, Robot, Schoolboy Uniform, Schoolgirl Uniform, Sister, Stockings, Sweating, Tomboy";
    my @tag_array = ($expected_group_tag, $expected_artist_tag, $expected_source_tag, $expected_lang_tag, $expected_genre_tags);
    my $expected_tags = join( ", ", @tag_array );
    is( $returned_tags,  $expected_tags, "correct tags" );
}

note("01 - 夜伽妻");
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

    my $expected_group_tag = "group:Remu";
    my $expected_artist_tag = "artist:Remu";
    my $expected_source_tag = "source:https://e-hentai.org/g/2470908/3dd0f5801e/";
    my $expected_lang_tag = "language:ja";
    my $expected_genre_tags = "Ahegao, Bbw, Big Areolae, Big Ass, Big Breasts, Big Nipples, Big Penis, Blowjob, Bondage, Cheating, Crotch Tattoo, Dark Skin, Facial Hair, Filming, Glasses, Glasses, Gyaru, Hairy, Huge Breasts, Impregnation, Maid, Milf, Nakadashi, Netorare, Oil, Paizuri, Pregnant, Prostitution, Schoolgirl Uniform, Swinging, Tall Girl, Tankoubon, Very Long Hair, Voyeurism, Widow, X-Ray";
    my @tag_array = ($expected_group_tag, $expected_artist_tag, $expected_source_tag, $expected_lang_tag, $expected_genre_tags);
    my $expected_tags = join( ", ", @tag_array );
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

    my $expected_group_tag = "group:あずまきよひこ";
    my $expected_artist_tag = "artist:あずまきよひこ";
    my $expected_lang_tag = "language:ja";
    my $expected_genre_tags = "Comedy, Shounen, Slice of Life";
    my @tag_array = ($expected_group_tag, $expected_artist_tag, $expected_lang_tag, $expected_genre_tags);
    my $expected_tags = join( ", ", @tag_array );
    is( $returned_tags,  $expected_tags, "correct tags" );
}

note("03 - 異種姦オーガズム");
{
    my ( $fh, $filename ) = tempfile();
    cp( $SAMPLES . "/comicinfo/03_sample.xml", $fh );

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::ComicInfo::get_plugin_logger         = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::ComicInfo::extract_file_from_archive = sub { $filename };
    local *LANraragi::Plugin::Metadata::ComicInfo::is_file_in_archive        = sub { 1 };

    my %dummyhash = ( file_path => "test" );

    # Since this is calling the sub directly and not in an object context,
    # we pass a dummy string as first parameter to replace the object.
    my $returned_tags = LANraragi::Plugin::Metadata::ComicInfo::get_tags( "", \%dummyhash);

    my $expected_group_tag = "group:7zu7";
    my $expected_lang_tag = "language:zh";
    my $expected_genre_tags = "translated, artist:7zu7, male:monster, Manga, Uploaded";
    my @tag_array = ($expected_group_tag, $expected_lang_tag, $expected_genre_tags);
    my $expected_tags = join( ", ", @tag_array );
    is( $returned_tags,  $expected_tags, "correct tags" );
}


done_testing();