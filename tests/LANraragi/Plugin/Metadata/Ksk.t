# LANraragi::Plugin::Metadata::Ksk
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

use_ok('LANraragi::Plugin::Metadata::Ksk');

note("test not fetching title or assuming language");
{
    my ( $fh, $filename ) = tempfile();
    cp( $SAMPLES . "/ksk/fake.yaml", $fh );

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Ksk::get_plugin_logger         = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::Ksk::extract_file_from_archive = sub { $filename };
    local *LANraragi::Plugin::Metadata::Ksk::is_file_in_archive        = sub { 1 };

    my %dummyhash = ( file_path => "test" );

    my %ko_tags = LANraragi::Plugin::Metadata::Ksk::get_tags( "", \%dummyhash, 0, 0 );
    my $expected_tags =
      "Harry Potter, Ebony Dark'ness Dementia Raven Way, Draco Malfoy, artist:xXMidnightEssenceXx, artist:bloodytearz666, series:Harry Potter, magazine:My Immortal - Genesis, source:https://www.fanfiction.net/s/6829556/1/My-Immortal";
    is( $ko_tags{title}, undef,          "Title is not overwritten" );
    is( $ko_tags{tags},  $expected_tags, "Language is missing" );

}

note("test fetching title, not assuming language");
{
    my ( $fh, $filename ) = tempfile();
    cp( $SAMPLES . "/ksk/fake.yaml", $fh );

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Ksk::get_plugin_logger         = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::Ksk::extract_file_from_archive = sub { $filename };
    local *LANraragi::Plugin::Metadata::Ksk::is_file_in_archive        = sub { 1 };

    my %dummyhash = ( file_path => "test" );

    my %ko_tags = LANraragi::Plugin::Metadata::Ksk::get_tags( "", \%dummyhash, 1, 0 );
    my $expected_tags =
      "Harry Potter, Ebony Dark'ness Dementia Raven Way, Draco Malfoy, artist:xXMidnightEssenceXx, artist:bloodytearz666, series:Harry Potter, magazine:My Immortal - Genesis, source:https://www.fanfiction.net/s/6829556/1/My-Immortal";
    is( $ko_tags{title}, "My Immortal",  "Title is overwritten" );
    is( $ko_tags{tags},  $expected_tags, "Language is missing" );
}

note("test fetching title, assuming language");
{
    my ( $fh, $filename ) = tempfile();
    cp( $SAMPLES . "/ksk/fake.yaml", $fh );

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Ksk::get_plugin_logger         = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::Ksk::extract_file_from_archive = sub { $filename };
    local *LANraragi::Plugin::Metadata::Ksk::is_file_in_archive        = sub { 1 };

    my %dummyhash = ( file_path => "test" );

    my %ko_tags = LANraragi::Plugin::Metadata::Ksk::get_tags( "", \%dummyhash, 1, 1 );
    my $expected_tags =
      "Harry Potter, Ebony Dark'ness Dementia Raven Way, Draco Malfoy, artist:xXMidnightEssenceXx, artist:bloodytearz666, series:Harry Potter, magazine:My Immortal - Genesis, language:english, source:https://www.fanfiction.net/s/6829556/1/My-Immortal";
    is( $ko_tags{title}, "My Immortal",  "Title is overwritten" );
    is( $ko_tags{tags},  $expected_tags, "Language is present" );
}

done_testing();
