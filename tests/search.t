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
use LANraragi::Model::Stats;

# Mock Redis
my $cwd = getcwd;
require $cwd . "/tests/mocks.pl";
setup_redis_mock();

my $redis = LANraragi::Model::Config->get_redis;

is( $redis->hget( "28697b96f0ac5858be2614ed10ca47742c9522fd", "title" ), "Fate GO MEMO", 'Redis mock test' );

# Build search hashes
LANraragi::Model::Stats::build_stat_hashes();

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
is( $ids[0], "4857fd2e7c00db8b0af0337b94055d8445118630", qq(Basic search ($search)) );

$search = qq("male:very cool");
do_test_search();
is( $filtered, 1, qq(Exact namespace search ($search)) );

$search = qq(male:very cool);
do_test_search();
is( $filtered, 2, qq(Fuzzy namespace search ($search)) );

$search = qq(*male:very cool);
do_test_search();
is( $filtered, 3, qq(Very fuzzy namespace search ($search)) );

$search = qq("Fate GO MEMO ?");
do_test_search();
is( $filtered, 1, qq(Wildcard search ($search)) );

$search = qq("Fate GO MEMO _");
do_test_search();
is( $filtered, 1, qq(Wildcard search ($search)) );

$search = qq("Saturn*Cartridge*Japanese Manual");
do_test_search();
is( $ids[0], "e69e43e1355267f7d32a4f9b7f2fe108d2401ebf", qq(Multiple wildcard search ($search)) );

$search = qq("Saturn\%American\%");
do_test_search();
is( $ids[0], "e69e43e1355267f7d32a4f9b7f2fe108d2401ebg", qq(Multiple wildcard search ($search)) );

$search = qq(artist:wada rco, character:ereshkigal);
do_test_search();
ok( $filtered eq 1 && $ids[0] eq "2810d5e0a8d027ecefebca6237031a0fa7b91eb3", qq(Tag inclusion search ($search)) );

$search = qq(artist:wada rco, -character:ereshkigal);
do_test_search();
ok( $filtered eq 1 && $ids[0] eq "28697b96f0ac5858be2614ed10ca47742c9522fd", qq(Tag exclusion search ($search)) );

$search = qq(artist:wada rco, -character:waver velvet);
do_test_search();
ok( $filtered eq 1 && $ids[0] eq "28697b96f0ac5858be2614ed10ca47742c9522fd", qq(Tag exclusion with quotes ($search)) );

$search = qq("artist:wada rco" "-character:waver velvet");
do_test_search();
is( $filtered, 0, qq(Incorrect tag exclusion ($search)) );

$search = qq(character:segata\$);
do_test_search();
ok( $filtered eq 1 && $ids[0] eq "e69e43e1355267f7d32a4f9b7f2fe108d2401ebg", qq(Exact search without quotes ($search)) );

$search = qq("Fate GO MEMO");
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
ok( $filtered eq 1 && $ids[0] eq "e4c422fd10943dc169e3489a38cdbf57101a5f7e", qq(Search with new filter applied) );

( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", 0, 0, 0, 0, 1 );
ok( $filtered eq 2 && $ids[0] eq "4857fd2e7c00db8b0af0337b94055d8445118630", qq(Search with untagged filter applied) );

$search = qq(pages:>150);
do_test_search();
is( $ids[0], "e69e43e1355267f7d32a4f9b7f2fe108d2401ebg", qq(Pagecount search ($search)) );

$search = qq(read:10);
do_test_search();
is( $ids[0], "e69e43e1355267f7d32a4f9b7f2fe108d2401ebf", qq(Read search ($search)) );

$search = qq(read:<11, read:>9);
do_test_search();
is( $ids[0], "e69e43e1355267f7d32a4f9b7f2fe108d2401ebf", qq(Read search ($search)) );

$search = "";
( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", 0, "lastread", 0, 0, 0 );
is( $ids[0], "e69e43e1355267f7d32a4f9b7f2fe108d2401ebg", qq(Last read time sort) );

done_testing();
