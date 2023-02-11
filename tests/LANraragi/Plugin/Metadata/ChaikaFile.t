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

use_ok('LANraragi::Plugin::Metadata::ChaikaFile');

my @tags_list= (
    'female:sole female', 'male:sole male', 'artist:kemuri haku', 'full censorship',
    'male:shotacon', 'female:defloration', 'female:nakadashi', 'female:big breasts',
    'language:translated', 'language:english'
);

use_ok('LANraragi::Plugin::Metadata::ChaikaFile');

note ( 'testing reading file ...' );
{
    # Copy the sample json to a temporary directory as it's deleted once parsed
    my ( $fh, $filename ) = tempfile();
    cp( $SAMPLES . "/chaika/001_gid_27240.json", $fh );

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::ChaikaFile::get_plugin_logger         = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::ChaikaFile::extract_file_from_archive = sub { $filename };
    local *LANraragi::Plugin::Metadata::ChaikaFile::is_file_in_archive        = sub { 1 };

    my %dummyhash = ( file_path => "test" );

    my %ko_tags = trap { LANraragi::Plugin::Metadata::ChaikaFile::get_tags( "", \%dummyhash, 1 ); };

    is( $ko_tags{title}, "[Kemuri Haku] Zettai Seikou Keikaku | Absolute Intercourse Plan (COMIC Shitsurakuten 2016-03) [English] [Redlantern]", 'gallery title');
    is( $ko_tags{tags}, join(", ", @tags_list), 'gallery tag list');
}

done_testing();
