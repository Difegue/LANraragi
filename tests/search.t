use strict;
use warnings;
use utf8;
use Cwd;

use Mojo::Base 'Mojolicious';

use Test::More;
use Test::Mojo;
use Test::MockObject;
use Mojo::JSON qw (decode_json);
use Data::Dumper;

use LANraragi::Model::Search;
use LANraragi::Model::Config;

# Mock Redis
my $cwd = getcwd;
require $cwd . "/tests/mocks.pl";
setup_redis_mock();

my $redis = LANraragi::Model::Config->get_redis;

is( $redis->hget( "28697b96f0ac5858be2614ed10ca47742c9522fd", "title" ), "Fate GO MEMO", 'Redis mock test' );

# Search queries
my $search = "";
my ( $total, $filtered, @ids );

sub do_test_search {
    ( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( $search, "", 0, 0, 0, 0, 0 );
}

do_test_search();
is( $filtered, 6, qq(Empty search(full index)) );

$search = qq(Ghost in the Shell);
do_test_search();
is( %{ $ids[0] }{title}, "Ghost in the Shell 1.5 - Human-Error Processor vol01ch01", qq(Basic search ($search)) );

$search = qq("Fate GO MEMO");
do_test_search();
is( $filtered, 2, qq(Non-exact quoted search ($search)) );

$search = qq("Fate GO MEMO ?");
do_test_search();
is( $filtered, 1, qq(Wildcard search ($search)) );

$search = qq("Fate GO MEMO _");
do_test_search();
is( $filtered, 1, qq(Wildcard search ($search)) );

$search = qq("Saturn*Cartridge*Japanese");
do_test_search();
is( %{ $ids[0] }{title}, "Saturn Backup Cartridge - Japanese Manual", qq(Multiple wildcard search ($search)) );

$search = qq("Saturn\%American");
do_test_search();
is( %{ $ids[0] }{title}, "Saturn Backup Cartridge - American Manual", qq(Multiple wildcard search ($search)) );

$search = qq("artist:wada rco" character:ereshkigal);
do_test_search();
ok( $filtered eq 1 && %{ $ids[0] }{title} eq "Fate GO MEMO 2", qq(Tag inclusion search ($search)) );

$search = qq("artist:wada rco" -character:ereshkigal);
do_test_search();
ok( $filtered eq 1 && %{ $ids[0] }{title} eq "Fate GO MEMO", qq(Tag exclusion search ($search)) );

$search = qq("artist:wada rco" -"character:waver velvet");
do_test_search();
ok( $filtered eq 1 && %{ $ids[0] }{title} eq "Fate GO MEMO", qq(Tag exclusion with quotes ($search)) );

$search = qq("artist:wada rco" "-character:waver velvet");
do_test_search();
is( $filtered, 0, qq(Incorrect tag exclusion ($search)) );

$search = qq(character:segata\$);
do_test_search();
ok( $filtered eq 1 && %{ $ids[0] }{title} eq "Saturn Backup Cartridge - American Manual",
    qq(Exact search without quotes ($search)) );

$search = qq("Fate GO MEMO"\$);
do_test_search();
is( $filtered, 1, qq(Exact search with quotes ($search)) );

$search = qq("Saturn Backup Cartridge - *"\$);
do_test_search();
is( $filtered, 2, qq(Exact search with quotes and wildcard ($search)) );

( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", qq(SET_1589141306), 0, 0, 0, 0, 0 );
is( $filtered, 2, qq(Search in category (SET_1589141306: Segata Sanshiro)) );

$search = qq("character:segata");
( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( $search, qq(SET_1589138380), 0, 0, 0, 0, 0 );
is( $filtered, 1, qq(Search with favorite search category applied ($search) + (SET_1589138380: American)) );

( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", 0, 0, 0, 1, 0 );
ok( $filtered eq 1 && %{ $ids[0] }{title} eq "Rohan Kishibe goes to Gucci", qq(Search with new filter applied) );

( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", 0, 0, 0, 0, 1 );
ok( $filtered eq 2 && %{ $ids[0] }{title} eq "Ghost in the Shell 1.5 - Human-Error Processor vol01ch01",
    qq(Search with untagged filter applied) );

done_testing();
