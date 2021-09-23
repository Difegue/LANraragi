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

my @tags_list_from_gallery = (
    'Artist:Hamao',
    'Parody:Original Work',
    'Magazine:Comic Kairakuten 2020-04',
    'Publisher:FAKKU', 'color', 'schoolgirl outfit',
    'osananajimi', 'unlimited', 'non-h', 'illustration'
);

use_ok('LANraragi::Plugin::Metadata::Fakku');

note("testing searching URL by title ...");

{
    my $html = ( Mojo::File->new("$SAMPLES/fakku/001_search_response.html")->slurp );
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Fakku::get_search_result_dom = sub { return Mojo::DOM->new($html); };
    local *LANraragi::Plugin::Metadata::Fakku::get_plugin_logger     = sub { return get_logger_mock(); };

    my $url = LANraragi::Plugin::Metadata::Fakku::search_for_fakku_url("my wonderful manga");
    is( $url, "https://www.fakku.net/hentai/kairakuten-cover-girls-episode-009-hamao-english", "url check" );
}

note("testing parsing gallery front page ...");

{
    my $html = ( Mojo::File->new("$SAMPLES/fakku/002_gallery_front.html")->slurp );
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Fakku::get_dom_from_fakku = sub { return Mojo::DOM->new($html); };
    local *LANraragi::Plugin::Metadata::Fakku::get_plugin_logger  = sub { return get_logger_mock(); };

    my ( $tags, $title ) = LANraragi::Plugin::Metadata::Fakku::get_tags_from_fakku("https://url/to/my/page.html");
    cmp_bag( [ split( ', ', $tags ) ], \@tags_list_from_gallery, "tag check" );
    is( $title, 'Kairakuten Cover Girl\'s Episode 009: Hamao', "title check" );
}

done_testing();
