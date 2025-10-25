# LANraragi::Plugin::Metadata::EHentai
use strict;
use warnings;
use utf8;
use Data::Dumper;

use Cwd qw( getcwd );
use Mojo::JSON qw(decode_json encode_json);
use Mojo::File;

use Test::More;
use Test::Deep;

my $cwd = getcwd();
my $SAMPLES = "$cwd/tests/samples";
require "$cwd/tests/mocks.pl";

setup_redis_mock();

my @all_tags = (
    'artist:yatsuki hiyori',
    'male:business suit',
    'male:glasses',
    'female:anal',
    'female:beauty mark',
    'female:big breasts',
    'female:business suit',
    'female:dark skin',
    'female:gyaru',
    'female:hair buns',
    'female:milf',
    'female:nakadashi',
    'female:paizuri',
    'female:pantyhose',
    'female:ponytail',
    'female:schoolgirl uniform',
    'female:stockings',
    'female:sweating',
    'tankoubon',
    'category:manga',
    # additional tags
    'uploader:hobohobo',
    'timestamp:1615623691'
);

use_ok('LANraragi::Plugin::Metadata::EHentai');

note ( 'testing retrieving tags without "additionaltags" ...' );
{
    my $json = decode_json( Mojo::File->new("$SAMPLES/eh/001_gid-1866546.json")->slurp );

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::EHentai::get_plugin_logger = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::EHentai::get_json_from_EH = sub { return $json; };

    my $additionaltags = 0;

    my ( $tags, $title ) = LANraragi::Plugin::Metadata::EHentai::get_tags_from_EH('dummy', 'dummy', 'dummy', 0, $additionaltags);

    cmp_bag( [ split( ', ', $tags ) ], [ @all_tags[0..19] ], 'tag list' );
    is($title, '[Yatsuki Hiyori] Choro Sugi! [Digital]', 'titile');
}

note ( 'testing retrieving tags with "additionaltags" ...' );
{
    my $json = decode_json( Mojo::File->new("$SAMPLES/eh/001_gid-1866546.json")->slurp );

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::EHentai::get_plugin_logger = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::EHentai::get_json_from_EH = sub { return $json; };

    my $additionaltags = 1;

    my ( $tags, $title ) = LANraragi::Plugin::Metadata::EHentai::get_tags_from_EH('dummy', 'dummy', 'dummy', 0, $additionaltags);

    cmp_bag( [ split( ', ', $tags ) ], \@all_tags, 'tag list' );
    is($title, '[Yatsuki Hiyori] Choro Sugi! [Digital]', 'titile');
}

note ( 'testing retrieving tags with original title...' );
{
    my $json = decode_json( Mojo::File->new("$SAMPLES/eh/001_gid-1866546.json")->slurp );

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::EHentai::get_plugin_logger = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::EHentai::get_json_from_EH = sub { return $json; };

    my $jpntitle = 1;

    my ( $tags, $title ) = LANraragi::Plugin::Metadata::EHentai::get_tags_from_EH('dummy', 'dummy', 'dummy', $jpntitle, 1);

    cmp_bag( [ split( ', ', $tags ) ], \@all_tags, 'tag list' );
    is($title, '[八樹ひより] ちょろすぎっ! [DL版]', 'title');
}

note ( 'testing parsing search results...' );
{
    my $dom = Mojo::DOM->new( Mojo::File->new("$SAMPLES/eh/002_search_results.html")->slurp );

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::EHentai::get_plugin_logger = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::EHentai::search_gallery = sub { return $dom; };

    my ( $gID, $gToken ) = LANraragi::Plugin::Metadata::EHentai::ehentai_parse( 'dummy-url', 'dummy-ua' );

    is( $gID, '618395', 'parsed ID' );
    is( $gToken, '0439fa3666', 'parsed Token' );
}



done_testing();
