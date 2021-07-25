use strict;
use warnings;
use utf8;
use Data::Dumper;

use Cwd qw( getcwd );
use Mojo::JSON qw(decode_json encode_json);
use Mojo::File;
use Mojolicious;
use LANraragi::Model::Config;

use Test::More;
use Test::Deep;
use Test::MockObject;

my $cwd = getcwd();
my $SAMPLES = "$cwd/tests/samples";
require "$cwd/tests/mocks.pl";

require $cwd . "/tests/mocks.pl";
setup_redis_mock();

my @all_tags = (
    'language:japanese',
    'artist:masamune shirow',
    'full color',
    'non-h',
    'artbook',
    'category:manga'
);

use_ok('LANraragi::Plugin::Metadata::nHentai');

note ( 'testing searching gallery by title ...' );

{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::nHentai::get_local_logger = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::nHentai::get_gallery_dom_by_title = sub { return; };

    my $gID = LANraragi::Plugin::Metadata::nHentai::get_gallery_id_from_title("you will not find this");

    is($gID, undef, 'empty gallery ID');
}

{
    my $body = Mojo::File->new("$SAMPLES/nh/001_search_results.html")->slurp;

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::nHentai::get_gallery_dom_by_title = sub { return Mojo::DOM->new( $body ); };

    my $gID = LANraragi::Plugin::Metadata::nHentai::get_gallery_id_from_title("a title that exists");

    is($gID, '999999', 'gallery ID');
}

note ( 'testing parsing JSON from HTML ...' );

{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::nHentai::get_local_logger = sub { return get_logger_mock(); };

    my $body = Mojo::File->new("$SAMPLES/nh/002_gid_52249.html")->slurp;

    my $json = LANraragi::Plugin::Metadata::nHentai::get_json_from_html($body);

    isa_ok($json, 'HASH', 'json');
    is($json->{id}, 52249, 'gallery ID');
    isa_ok($json->{title}, 'HASH', 'json.title');
    is($json->{title}{pretty}, 'Pieces 1', 'json.title.pretty');
    isa_ok($json->{tags}, 'ARRAY', 'json.tags');
    is(scalar @{$json->{tags}}, 6, 'tags count');
}

note ( 'testing getting tags from JSON ...' );

{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::nHentai::get_local_logger = sub { return get_logger_mock(); };

    my $body = Mojo::File->new("$SAMPLES/nh/002_gid_52249.html")->slurp;
    my $json = LANraragi::Plugin::Metadata::nHentai::get_json_from_html($body);

    my @tags = LANraragi::Plugin::Metadata::nHentai::get_tags_from_json($json);

    cmp_bag( \@tags, \@all_tags, 'tag list' );
}

note ( 'testing getting tags from JSON ...' );

{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::nHentai::get_local_logger = sub { return get_logger_mock(); };

    my $body = Mojo::File->new("$SAMPLES/nh/002_gid_52249.html")->slurp;
    my $json = LANraragi::Plugin::Metadata::nHentai::get_json_from_html($body);

    my $title = LANraragi::Plugin::Metadata::nHentai::get_title_from_json($json);

    is( $title, 'Pieces 1', 'title' );
}

done_testing();
