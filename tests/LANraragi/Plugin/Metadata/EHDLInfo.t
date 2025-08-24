use strict;
use warnings;

use Cwd        qw( getcwd );
use File::Temp qw(tempfile);
use File::Copy "cp";

use Mojolicious;
use LANraragi::Model::Config;

use Test::More;
use Test::Deep;
use Test::Trap;

my $cwd = getcwd();

require "$cwd/tests/mocks.pl";
setup_redis_mock();
my $SAMPLES = "${cwd}/tests/samples/ehdl";

use_ok('LANraragi::Plugin::Metadata::EHDLInfo');

note("reading info_translated.txt, wanting default title");
{
    my ( $fh, $filename ) = tempfile();
    cp( "${SAMPLES}/info_translated.txt", $fh );

    my $params = { japanese_title => 0 };
    my %res    = LANraragi::Plugin::Metadata::EHDLInfo::read_file->( $filename, $params );

    like( $res{title}, qr/^\[Peter Mittsuru\] Married Couple Swap/, 'title' );
    like( $res{tags},  qr/source:e-hentai\.org\/g\/3369723/,        'source URL' );
    like( $res{tags},  qr/category:Manga,/,                         'category' );
    like( $res{tags},  qr/artist:peter mitsuru,/,                   'artist' );
    like( $res{tags},  qr/male:kimono,/,                            'male' );
    like( $res{tags},  qr/female:big breasts,/,                     'female' );
    like( $res{tags},  qr/other:multi/,                             'other' );
    like( $res{tags},  qr/timestamp:\d{10}/,                        'timestamp' );
    like( $res{tags},  qr/language:english,/,                       'language is english' );
    unlike( $res{tags}, qr/language:japanese/, 'japanese language is not present' );
    ok( !exists $res{'summary'}, 'summary not present' );
    ok( !-e $filename,           'file deleted' );
}

note("reading info_translated.txt, wanting original title");
{
    my ( $fh, $filename ) = tempfile();
    cp( "${SAMPLES}/info_translated.txt", $fh );

    my $params = { japanese_title => 1 };
    my %res    = LANraragi::Plugin::Metadata::EHDLInfo::read_file->( $filename, $params );

    like( $res{title}, qr/^\[Peter Mittsuru\] Married Couple Swap/, 'returned default title because original is missing' );
    ok( !exists $res{'summary'}, 'summary not present' );
    ok( exists $res{'tags'},     'tags are present' );
    ok( !-e $filename,           'file deleted' );
}

note("reading info_original.txt, wanting default title");
{
    my ( $fh, $filename ) = tempfile();
    cp( "${SAMPLES}/info_original.txt", $fh );

    my $params = { japanese_title => 0 };
    my %res    = LANraragi::Plugin::Metadata::EHDLInfo::read_file->( $filename, $params );

    like( $res{title}, qr/^\[Endou Hiroto\] Tsunagari Zakari/, 'title' );
    like( $res{tags},  qr/source:exhentai\.org\/g\/3363593/,   'source URL' );
    like( $res{tags},  qr/category:Manga,/,                    'category' );
    like( $res{tags},  qr/artist:endou hiroto,/,               'artist' );
    like( $res{tags},  qr/female:maid,/,                       'female' );
    like( $res{tags},  qr/other:full color,/,                  'other' );
    like( $res{tags},  qr/language:japanese,/,                 'language is japanese' );
    ok( !exists $res{'summary'}, 'summary not present' );
    ok( !-e $filename,           'file deleted' );
}

note("reading info_original.txt, wanting original title");
{
    my ( $fh, $filename ) = tempfile();
    cp( "${SAMPLES}/info_original.txt", $fh );

    my $params = { japanese_title => 1 };
    my %res    = LANraragi::Plugin::Metadata::EHDLInfo::read_file->( $filename, $params );

    like( $res{title}, qr/\p{Script=Han}|\p{Script=Katakana}|\p{Script=Hiragana}/u, 'title' );    # this is as far as I can go :)
    ok( !exists $res{'summary'}, 'summary not present' );
    ok( exists $res{'tags'},     'tags are present' );
    ok( !-e $filename,           'file deleted' );
}

note("reading info_pipe.txt");
{
    my ( $fh, $filename ) = tempfile();
    cp( "${SAMPLES}/info_pipe.txt", $fh );

    my $params = { japanese_title => 1 };
    my %res    = LANraragi::Plugin::Metadata::EHDLInfo::read_file->( $filename, $params );

    like( $res{tags}, qr/artist:kemigawa mondo | kemigawa,/,                       'has pipe' );
    like( $res{tags}, qr/parody:super mario brothers | super mario bros.,/,        'has pipe and dot' );
    like( $res{tags}, qr/parody:sousou no frieren | frieren beyond journeys end,/, 'has pipe' );
    like( $res{tags}, qr/parody:ssss.gridman,/,                                    'has dot' );
    like( $res{tags}, qr/female:swimsuit/,                                         'has last word of the row' );

}

# used the example from issue #319, don't know where to find an original file
note("reading info_flat.txt");
{
    my ( $fh, $filename ) = tempfile();
    cp( "${SAMPLES}/info_flat.txt", $fh );

    my $params = { japanese_title => 0 };
    my %res    = LANraragi::Plugin::Metadata::EHDLInfo::read_file->( $filename, $params );

    is( $res{title},   "Chika-chan's Funtime", 'title' );
    is( $res{summary}, "endless pleasure...",  'summary' );
    like( $res{tags}, qr/artist:Arai Togami/, 'Flat: Artist tag present' );
    like( $res{tags}, qr/language:english/,   'Flat: Language tag present' );
    unlike( $res{tags}, qr/tag:.*/, 'prefix "tag:" is absent' );
    ok( !-e $filename, 'file deleted' );
}

note("reading info_invalid.txt");
{
    my ( $fh, $filename ) = tempfile();
    cp( "${SAMPLES}/info_invalid.txt", $fh );

    trap { LANraragi::Plugin::Metadata::EHDLInfo::read_file->( $filename, {} ); };

    is( $trap->exit,   undef, 'no exit code' );
    is( $trap->stdout, '',    'no STDOUT' );
    is( $trap->stderr, '',    'no STDERR' );
    like( $trap->die, qr/^Unknown file format/, 'unknown file format' );
    ok( !-e $filename, 'file deleted' );
}

note("read_file dies when file is not present");
{
    trap { LANraragi::Plugin::Metadata::EHDLInfo::read_file->( "${SAMPLES}/missing.txt", {} ); };

    is( $trap->exit,   undef, 'no exit code' );
    is( $trap->stdout, '',    'no STDOUT' );
    is( $trap->stderr, '',    'no STDERR' );
    like( $trap->die, qr/^Could not open.*missing\.txt/, 'could not open file' );
}

note("checking title and summary management in get_tags");
{
    my $lrr_info    = { file_path => "/a/file.txt" };
    my %parsed_data = (
        title   => 'Title Here',
        summary => 'Something magic here',
        tags    => 'one,two,three'
    );

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::EHDLInfo::get_plugin_logger         = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::EHDLInfo::extract_file_from_archive = sub { return; };
    local *LANraragi::Plugin::Metadata::EHDLInfo::is_file_in_archive        = sub { 1 };
    local *LANraragi::Plugin::Metadata::EHDLInfo::read_file                 = sub {
        return %parsed_data;
    };

    note('requesting both title and summanry');
    my $params = { replace_title => 1, save_summary => 1 };
    my %res    = LANraragi::Plugin::Metadata::EHDLInfo::get_tags->( undef, $lrr_info, $params );
    cmp_deeply( \%res, \%parsed_data, 'tags, title and summary returned' );

    note('requesting title only');
    $params = { replace_title => 1, save_summary => 0 };
    %res    = LANraragi::Plugin::Metadata::EHDLInfo::get_tags->( undef, $lrr_info, $params );
    ok( exists $res{tags},     'tags returned' );
    ok( exists $res{title},    'title returned' );
    ok( !exists $res{summary}, 'summary not returned' );

    note('requesting summary only');
    $params = { replace_title => 0, save_summary => 1 };
    %res    = LANraragi::Plugin::Metadata::EHDLInfo::get_tags->( undef, $lrr_info, $params );
    ok( exists $res{tags},    'tags returned' );
    ok( !exists $res{title},  'title not returned' );
    ok( exists $res{summary}, 'summary returned' );

    note('excluding both title and summary');
    $params = { replace_title => 0, save_summary => 0 };
    %res    = LANraragi::Plugin::Metadata::EHDLInfo::get_tags->( undef, $lrr_info, $params );
    ok( exists $res{tags},     'tags returned' );
    ok( !exists $res{title},   'title not returned' );
    ok( !exists $res{summary}, 'summary not returned' );
}

done_testing();
