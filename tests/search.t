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
    ( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( $search, "", 0, 0, 0, 0, 0, 1 );
}

do_test_search();
is( $filtered, 12, qq(Empty search(full index)) );
( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( $search, "", 0, 0, 0, 0, 0, 0 );
is( $filtered, 12, qq(Empty search(tank grouping off)) );

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

$search = qq(artist:shirow masamune, full color, artbook);
do_test_search();
is( $filtered, 0, qq(Multiple tag search with spaces halting at second token ($search)) );

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

( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", qq(SET_1589141306), 0, 0, 0, 0, 0, 0 );
is( $filtered, 2, qq(Search in category (SET_1589141306: Segata Sanshiro)) );

$search = qq("character:segata");
( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( $search, qq(SET_1589138380), 0, 0, 0, 0, 0, 0 );
is( $filtered, 1, qq(Search with favorite search category applied ($search) + (SET_1589138380: American)) );

# With grouptanks=0, we get individual archives. Two archives are now new:
# e4c422fd10943dc169e3489a38cdbf57101a5f7e and 28697b96f0ac5858be2666ed10ca47742c955555
( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", 0, 0, 0, 1, 0, 0 );
is( $filtered, 2, qq(Search with new filter applied - count) );

( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", 0, 0, 0, 0, 1, 0 );
ok( $filtered eq 2 && $ids[0] eq "4857fd2e7c00db8b0af0337b94055d8445118630", qq(Search with untagged filter applied) );

# Tankoubonsonly filter tests
( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", 0, 0, 0, 0, 0, 1, 1 );
is( $filtered, 2, qq(Search with tankoubonsonly filter - count) );
ok( $ids[0] =~ /^TANK_/ && $ids[1] =~ /^TANK_/, qq(Search with tankoubonsonly filter - all results are tanks) );

( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "Hello", "", 0, 0, 0, 0, 0, 1, 1 );
is( $filtered, 1, qq(Search with tankoubonsonly filter and query) );
is( $ids[0], "TANK_1589141306", qq(Search with tankoubonsonly filter finds correct tank) );

( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "nonexistent", "", 0, 0, 0, 0, 0, 1, 1 );
is( $filtered, 0, qq(Tankoubonsonly with no matching tanks returns empty) );

# Edge case: tankoubonsonly with grouptanks=0 returns 0 since tanks aren't in the initial set
( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", 0, 0, 0, 0, 0, 0, 1 );
is( $filtered, 0, qq(Tankoubonsonly with grouptanks=0 returns empty - tanks not in initial set) );

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
( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( $search, "", 0, "lastread", 0, 0, 0, 0 );
is( $ids[0], "e69e43e1355267f7d32a4f9b7f2fe108d2401ebg", qq(Last read time sort) );

$search = qq(medjed);
do_test_search();
is( $ids[0], "TANK_1589141306", qq(Tankoubon grouping search (1/2)) );
$search = qq(vector);
do_test_search();
is( $ids[0],   "TANK_1589141306", qq(Tankoubon grouping search (2/2)) );
is( $filtered, 2,                 qq(Tankoubon grouping count) );

( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( $search, "", 0, 0, 0, 0, 0, 0 );
is( $filtered, 1,                                          qq(No tank grouping count) );
is( $ids[0],   "28697b96f0ac5777be2614ed10ca47742c9522fa", qq(Tank grouping disabled) );

# Multi-category filter tests (comma-separated categories with AND/intersection logic)

# Test: newonly + untaggedonly combination (should return archives that are both new AND untagged)
# The "new" archive (e4c422fd10943dc169e3489a38cdbf57101a5f7e) has only parody: tag which is a "basic" tag,
# so it's considered untagged. This tests that both filters are applied together (AND logic).
( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", 0, 0, 0, 1, 1, 0 );
is( $filtered, 1, qq(Multi-filter: newonly + untaggedonly - archive is both new and untagged) );
is( $ids[0], "e4c422fd10943dc169e3489a38cdbf57101a5f7e", qq(Multi-filter: correct archive matches both filters) );

# Test: tankoubonsonly + newonly (tanks containing new archives)
# TANK_1589141306 contains archive 28697b96f0ac5858be2666ed10ca47742c955555 which has isnew=true
( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", 0, 0, 0, 1, 0, 1, 1 );
is( $filtered, 1, qq(Multi-filter: tankoubonsonly + newonly - finds tank with new archive) );
is( $ids[0], "TANK_1589141306", qq(Multi-filter: correct tank returned) );

# Test: newonly with grouptanks=1 includes tanks containing new archives
# Should return: the new archive + the tank containing another new archive
( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", 0, 0, 0, 1, 0, 1, 0 );
ok( $filtered >= 2, qq(Newonly with grouptanks includes tanks with new archives) );
# Check that TANK_1589141306 is in the results (it contains a new archive)
ok( grep( { $_ eq "TANK_1589141306" } @ids ), qq(Tank with new archive appears in newonly results) );

# Test: multiple real categories (comma-separated) - static + dynamic intersection
# SET_1589141306 (Segata Sanshiro) has: e69e43e1355267f7d32a4f9b7f2fe108d2401ebf, e69e43e1355267f7d32a4f9b7f2fe108d2401ebg
# SET_1589138380 (AMERICA ONRY) is dynamic with search "American"
# Only e69e43e1355267f7d32a4f9b7f2fe108d2401ebg ("Saturn Backup Cartridge - American Manual") matches both
( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "SET_1589141306,SET_1589138380", 0, 0, 0, 0, 0, 0 );
is( $filtered, 1, qq(Multi-category: static + dynamic intersection) );
is( $ids[0], "e69e43e1355267f7d32a4f9b7f2fe108d2401ebg", qq(Multi-category: correct archive in intersection) );

# Test: single category still works (backwards compatibility)
( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "SET_1589141306", 0, 0, 0, 0, 0, 0 );
is( $filtered, 2, qq(Single category still works - backwards compatible) );

# Test: empty category in comma list is ignored
( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "SET_1589141306,", 0, 0, 0, 0, 0, 0 );
is( $filtered, 2, qq(Trailing comma in category list is handled gracefully) );

( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", ",SET_1589141306", 0, 0, 0, 0, 0, 0 );
is( $filtered, 2, qq(Leading comma in category list is handled gracefully) );

done_testing();
