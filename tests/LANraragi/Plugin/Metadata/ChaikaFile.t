# LANraragi::Plugin::Metadata::ChaikaFile
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
setup_redis_mock();

my @tags_list = (
    'full censorship',  'female:sole female', 'male:sole male',     'artist:kemuri haku',
    'female:tall girl', 'female:cunnilingus', 'male:shotacon',      'female:defloration',
    'female:nakadashi', 'female:x-ray',       'female:big breasts', 'language:translated',
    'language:english'
);
my @tags_list_extra = (
    'other:full censorship', 'female:sole female', 'male:sole male',                    'artist:kemuri haku',
    'female:tall girl',      'female:cunnilingus', 'male:shotacon',                     'female:defloration',
    'female:nakadashi',      'female:x-ray',       'female:big breasts',                'language:translated',
    'language:english',      'category:manga',     'download:/archive/27240/download/', 'gallery:23532',
    'timestamp:1521357552',  'source:chaika'
);

use_ok('LANraragi::Plugin::Metadata::ChaikaFile');

note('testing reading file without extra data...');
{
    # Copy the sample json to a temporary directory as it's deleted once parsed
    my ( $fh, $filename ) = tempfile();
    cp( $SAMPLES . "/chaika/001_gid_27240.json", $fh );

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::ChaikaFile::get_plugin_logger         = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::ChaikaFile::extract_file_from_archive = sub { $filename };
    local *LANraragi::Plugin::Metadata::ChaikaFile::is_file_in_archive        = sub { 1 };

    my %dummyhash = ( file_path => "test" );

    my $saveTitle = 0;
    my $addextra  = 0;
    my $addother  = 0;
    my $addsource = '';
    my %ko_tags = trap { LANraragi::Plugin::Metadata::ChaikaFile::get_tags( "", \%dummyhash, $addextra, $addother, $addsource ); };

    is( $ko_tags{title},
        "[Kemuri Haku] Zettai Seikou Keikaku | Absolute Intercourse Plan (COMIC Shitsurakuten 2016-03) [English] [Redlantern]",
        'gallery title'
    );
    is( $ko_tags{tags}, join( ", ", @tags_list ), 'gallery tag list' );
}

note('testing reading file with extra data...');
{
    # Copy the sample json to a temporary directory as it's deleted once parsed
    my ( $fh, $filename ) = tempfile();
    cp( $SAMPLES . "/chaika/001_gid_27240.json", $fh );

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::ChaikaFile::get_plugin_logger         = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::ChaikaFile::extract_file_from_archive = sub { $filename };
    local *LANraragi::Plugin::Metadata::ChaikaFile::is_file_in_archive        = sub { 1 };

    my %dummyhash = ( file_path => "test" );

    my $addextra  = 1;
    my $addother  = 1;
    my $addsource = 'chaika';

    my %ko_tags = trap { LANraragi::Plugin::Metadata::ChaikaFile::get_tags( "", \%dummyhash, $addextra, $addother, $addsource ); };

    is( $ko_tags{title},
        "[Kemuri Haku] Zettai Seikou Keikaku | Absolute Intercourse Plan (COMIC Shitsurakuten 2016-03) [English] [Redlantern]",
        'gallery title'
    );
    is( $ko_tags{tags}, join( ", ", @tags_list_extra ), 'gallery tag list' );
}

done_testing();
