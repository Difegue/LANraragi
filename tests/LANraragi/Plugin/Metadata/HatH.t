# LANraragi::Plugin::Metadata::HatH
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
    'upload_time:2020-11-11 00:00', 'uploader:Katlan', 'language:english', 'language:translated',
    'artist:yyyy', 'male:dark skin', 'female:fox girl'
);

use_ok('LANraragi::Plugin::Metadata::HatH');

note('testing reading galleryinfo.txt...');
{
    # Copy the sample json to a temporary directory as it's deleted once parsed
    my ( $fh, $filename ) = tempfile();
    cp( $SAMPLES . "/hath/galleryinfo.txt", $fh );

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::HatH::get_plugin_logger         = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::HatH::extract_file_from_archive = sub { $filename };
    local *LANraragi::Plugin::Metadata::HatH::is_file_in_archive        = sub { 1 };

    my %dummyhash = ( file_path => "test" );

    my $saveTitle = 0;
    my $addextra  = 0;
    my $addother  = 0;
    my $addsource = '';
    my %hath_tags = trap { LANraragi::Plugin::Metadata::HatH::get_tags( "", \%dummyhash ); };

    is( $hath_tags{title}, "xxxxxxxxxx",             'gallery title' );
    is( $hath_tags{tags},  join( ", ", @tags_list ), 'gallery tag list' );
}

done_testing();
