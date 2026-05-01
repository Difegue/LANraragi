use strict;
use warnings;
use utf8;
use Data::Dumper;

use Cwd qw( getcwd );
use Mojo::JSON qw(decode_json encode_json);
use Mojo::File;

use Test::More;
use Test::Deep;

my $cwd     = getcwd();
my $SAMPLES = "$cwd/tests/samples";
require "$cwd/tests/mocks.pl";
setup_redis_mock();

my @all_tags = ( 'language:japanese', 'artist:masamune shirow', 'full color', 'non-h', 'artbook', 'category:manga' );

use_ok('LANraragi::Plugin::Metadata::nHentai');

note('testing searching gallery by title ...');

{
    my $json = decode_json( Mojo::File->new("$SAMPLES/nh/002_search_results_empty.json")->slurp );

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::nHentai::get_plugin_logger = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::nHentai::get_search_json   = sub { return $json; };

    my $gID = LANraragi::Plugin::Metadata::nHentai::get_gallery_id_from_title("you will not find this", undef);

    is( $gID, undef, 'empty gallery ID' );
}

{
    my $json = decode_json( Mojo::File->new("$SAMPLES/nh/001_search_results.json")->slurp );

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::nHentai::get_plugin_logger = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::nHentai::get_search_json   = sub { return $json; };

    my $gID = LANraragi::Plugin::Metadata::nHentai::get_gallery_id_from_title("a title that exists", undef);

    is( $gID, '52249', 'gallery ID' );
}

note('testing getting tags from JSON ...');

{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::nHentai::get_plugin_logger = sub { return get_logger_mock(); };

    my $json = decode_json( Mojo::File->new("$SAMPLES/nh/003_gid_52249.json")->slurp );

    my @tags = LANraragi::Plugin::Metadata::nHentai::get_tags_from_json($json);

    cmp_bag( \@tags, \@all_tags, 'tag list' );
}

note('testing getting tags from JSON ...');

{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::nHentai::get_plugin_logger = sub { return get_logger_mock(); };

    my $json = decode_json( Mojo::File->new("$SAMPLES/nh/003_gid_52249.json")->slurp );

    my $title = LANraragi::Plugin::Metadata::nHentai::get_title_from_json($json);

    is( $title, 'Pieces 1', 'title' );
}

done_testing();
