# LANraragi::Plugin::Metadata::Hentag
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

use_ok('LANraragi::Plugin::Metadata::Hentag');

note("00 - no circles/characters");
{
    my ( $fh, $filename ) = tempfile();
    cp( $SAMPLES . "/hentag/00_sample.json", $fh );

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Hentag::get_plugin_logger         = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::Hentag::extract_file_from_archive = sub { $filename };
    local *LANraragi::Plugin::Metadata::Hentag::is_file_in_archive        = sub { 1 };

    my %dummyhash = ( file_path => "test" );

    # Since this is calling the sub directly and not in an object context,
    # we pass a dummy string as first parameter to replace the object.
    my %ko_tags = LANraragi::Plugin::Metadata::Hentag::get_tags( "", \%dummyhash, 1 );

    my $expected_title = "Isekai Rakuten Vol. 18";
    my $expected_tags =
      "artist:croriin, artist:hinasaki yo, artist:kakao, artist:shirai samoedo, female:big breasts, female:catgirl, female:cowgirl, female:dark skin, female:elf, female:horns, female:kemonomimi, female:lactation, female:milking, other:anthology, other:full censorship, language:japanese, url:https://e-hentai.org/g/2463137/dab23dcddd, url:https://exhentai.org/g/2463137/dab23dcddd";
    is( $ko_tags{title}, $expected_title, "correct title" );
    is( $ko_tags{tags},  $expected_tags, "correct tags" );
}

note("00 - no other");
{
    my ( $fh, $filename ) = tempfile();
    cp( $SAMPLES . "/hentag/01_sample.json", $fh );

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Hentag::get_plugin_logger         = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::Hentag::extract_file_from_archive = sub { $filename };
    local *LANraragi::Plugin::Metadata::Hentag::is_file_in_archive        = sub { 1 };

    my %dummyhash = ( file_path => "test" );

    # Since this is calling the sub directly and not in an object context,
    # we pass a dummy string as first parameter to replace the object.
    my %ko_tags = LANraragi::Plugin::Metadata::Hentag::get_tags( "", \%dummyhash, 1 );

    my $expected_title = "(C93) [Circle Shakunetsu (Sabaku Chitai)] Takebe Saori ga Shojo nanoni PinSalo de Hataraku Hon (Girls und Panzer) [Spanish] [Lanerte]";
    my $expected_tags =
      "series:girls und panzer, group:circle shakunetsu, artist:sabaku, character:saori takebe, male:dilf, male:facial hair, male:sole male, female:blowjob, female:clothed male nude female, female:focus blowjob, female:handjob, female:prostitution, female:sole female, language:spanish, url:https://e-hentai.org/g/2463143/4f5b5e3e61, url:https://exhentai.org/g/2463143/4f5b5e3e61";
    is( $ko_tags{title}, $expected_title, "correct title" );
    is( $ko_tags{tags},  $expected_tags, "correct tags" );
}


done_testing();
