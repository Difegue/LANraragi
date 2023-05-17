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

my @tags_list_from_gallery =
  ( 'comic kairakuten 2018-06', 'original work', 'range murata', 'twintails', 'color', 'illustration', 'non-h', 'unlimited' );

use_ok('LANraragi::Plugin::Metadata::Koushoku');

note("testing searching URL by title ...");

{
    my $html = ( Mojo::File->new("$SAMPLES/koushoku/001_search_response.html")->slurp );
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Koushoku::get_search_result_dom = sub { return Mojo::DOM->new($html); };
    local *LANraragi::Plugin::Metadata::Koushoku::get_plugin_logger     = sub { return get_logger_mock(); };

    my $url = LANraragi::Plugin::Metadata::Koushoku::search_for_ksk_url("my wonderful manga");
    is( $url, "https://ksk.moehttps://ksk.moe/view/3077/f8d48ef8c7be", "url check" );
}

note("testing parsing gallery front page ...");

{
    my $html = ( Mojo::File->new("$SAMPLES/koushoku/002_gallery_front.html")->slurp );
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Koushoku::get_dom_from_ksk  = sub { return Mojo::DOM->new($html); };
    local *LANraragi::Plugin::Metadata::Koushoku::get_plugin_logger = sub { return get_logger_mock(); };

    my ( $tags, $title ) = LANraragi::Plugin::Metadata::Koushoku::get_tags_from_ksk("https://url/to/my/page.html");
    cmp_bag( [ split( ', ', $tags ) ], \@tags_list_from_gallery, "tag check" );
    is( $title, 'futuregraph #175', "title check" );
}

done_testing();
