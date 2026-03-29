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
    ( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( $search, "", 0, 0, 0, 0, 0, 1, 0 );
}

do_test_search();
is( $filtered, 9, qq(Empty search(full index)) );
( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( $search, "", 0, 0, 0, 0, 0, 0, 0 );
is( $filtered, 9, qq(Empty search(tank grouping off)) );

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

( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", qq(SET_1589141306), 0, 0, 0, 0, 0, 0, 0 );
is( $filtered, 2, qq(Search in category (SET_1589141306: Segata Sanshiro)) );

$search = qq("character:segata");
( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( $search, qq(SET_1589138380), 0, 0, 0, 0, 0, 0, 0 );
is( $filtered, 1, qq(Search with favorite search category applied ($search) + (SET_1589138380: American)) );

( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", 0, 0, 0, 1, 0, 0, 0 );
ok( $filtered eq 1 && $ids[0] eq "e4c422fd10943dc169e3489a38cdbf57101a5f7e", qq(Search with new filter applied) );

( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", 0, 0, 0, 0, 1, 0, 0 );
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
( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( $search, "", 0, "lastread", 0, 0, 0, 0, 0 );
is( $ids[0], "e69e43e1355267f7d32a4f9b7f2fe108d2401ebg", qq(Last read time sort) );

$search = qq(medjed);
do_test_search();
is( $ids[0], "TANK_1589141306", qq(Tankoubon grouping search (1/2)) );
$search = qq(vector);
do_test_search();
is( $ids[0],   "TANK_1589141306", qq(Tankoubon grouping search (2/2)) );
is( $filtered, 2,                 qq(Tankoubon grouping count) );

( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( $search, "", 0, 0, 0, 0, 0, 0, 0 );
is( $filtered, 1,                                          qq(No tank grouping count) );
is( $ids[0],   "28697b96f0ac5777be2614ed10ca47742c9522fa", qq(Tank grouping disabled) );

note('testing namespace sort partition (keyed archives first, unkeyed at back)...');

my %expected_keyed = map { $_ => 1 } (
    "4857fd2e7c00db8b0af0337b94055d8445118630",     # artist:shirow masamune
    "2810d5e0a8d027ecefebca6237031a0fa7b91eb3",     # artist:wada rco
    "28697b96f0ac5858be2614ed10ca47742c9522fd",     # artist:wada rco
    "be447b58ea66137c415ee306ee2ac44b308ee484",     # artist:yoshiyuki sadamoto
);
my %expected_unkeyed = map { $_ => 1 } (
    "e69e43e1355267f7d32a4f9b7f2fe108d2401ebf",
    "e69e43e1355267f7d32a4f9b7f2fe108d2401ebg",
    "e4c422fd10943dc169e3489a38cdbf57101a5f7e",
    "28697b96f0ac5777be2614ed10ca47742c9522fa",
    "28697b96f0ac5858be2666ed10ca47742c955555",
);

{
    # Sort by artist, ascending: shirow masamune < wada rco < yoshiyuki sadamoto
    my ( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", -1, "artist", 0, 0, 0, 0, 0 );
    is( $filtered, 9, 'Artist sort should return all archives' );

    # Keyed partition (positions 0-3): boundary positions are deterministic
    is( $ids[0], "4857fd2e7c00db8b0af0337b94055d8445118630",
        'Artist asc should place shirow masamune first' );
    is( $ids[3], "be447b58ea66137c415ee306ee2ac44b308ee484",
        'Artist asc should place yoshiyuki sadamoto last in keyed partition' );
    is_deeply( { map { $_ => 1 } @ids[0..3] }, \%expected_keyed,
        'Artist asc keyed partition should contain all artist-tagged archives' );

    # Unkeyed partition (positions 4-8): archives without artist tag
    is_deeply( { map { $_ => 1 } @ids[4..8] }, \%expected_unkeyed,
        'Artist asc should place all unkeyed archives at positions 5-9' );
}

{
    # Sort by artist, descending — only keyed partition reverses
    my ( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", -1, "artist", 1, 0, 0, 0, 0 );

    # Keyed partition reversed: boundary positions swap
    is( $ids[0], "be447b58ea66137c415ee306ee2ac44b308ee484",
        'Artist desc should place yoshiyuki sadamoto first' );
    is( $ids[3], "4857fd2e7c00db8b0af0337b94055d8445118630",
        'Artist desc should place shirow masamune last in keyed partition' );
    is_deeply( { map { $_ => 1 } @ids[0..3] }, \%expected_keyed,
        'Artist desc keyed partition should contain all artist-tagged archives' );

    # Unkeyed partition still at back
    is_deeply( { map { $_ => 1 } @ids[4..8] }, \%expected_unkeyed,
        'Artist desc should keep all unkeyed archives at positions 5-9' );
}

note('testing hidecompleted filter...');

# Completed archives in the mock data (progress / pagecount > 0.85):
#   e69e43e1...ebf: pagecount=2,   progress=10 => 10/2  = 5.00  => completed
#   4857fd2e...630: pagecount=34,  progress=34 => 34/34 = 1.00  => completed
#   2810d5e0...eb3: pagecount=34,  progress=34 => 34/34 = 1.00  => completed
# Not completed: 6 remaining archives

{
    # Basic hidecompleted test (no tank grouping)
    my ( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", 0, 0, 0, 0, 0, 0, 1 );
    is( $filtered, 6, 'hidecompleted should remove 3 completed archives (9 - 3 = 6)' );

    my %returned = map { $_ => 1 } @ids;
    ok( !exists $returned{"e69e43e1355267f7d32a4f9b7f2fe108d2401ebf"},
        'hidecompleted should exclude Saturn Japanese Manual (progress 10, pagecount 2)' );
    ok( !exists $returned{"4857fd2e7c00db8b0af0337b94055d8445118630"},
        'hidecompleted should exclude Ghost in the Shell (progress 34, pagecount 34)' );
    ok( !exists $returned{"2810d5e0a8d027ecefebca6237031a0fa7b91eb3"},
        'hidecompleted should exclude Fate GO MEMO 2 (progress 34, pagecount 34)' );

    # Verify non-completed archives are kept
    ok( exists $returned{"e69e43e1355267f7d32a4f9b7f2fe108d2401ebg"},
        'hidecompleted should keep Saturn American Manual (progress 34, pagecount 200)' );
    ok( exists $returned{"e4c422fd10943dc169e3489a38cdbf57101a5f7e"},
        'hidecompleted should keep Rohan Kishibe (progress 0)' );
    ok( exists $returned{"28697b96f0ac5858be2614ed10ca47742c9522fd"},
        'hidecompleted should keep Fate GO MEMO (progress 0)' );
}

{
    # hidecompleted combined with a search filter
    my ( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "artist:wada rco", "", 0, 0, 0, 0, 0, 0, 1 );
    is( $filtered, 1, 'hidecompleted + search should filter completed from results' );
    is( $ids[0], "28697b96f0ac5858be2614ed10ca47742c9522fd",
        'hidecompleted + artist search should only return the non-completed Fate GO MEMO' );
}

{
    # hidecompleted with tank grouping enabled — tanks should be preserved
    my ( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", 0, 0, 0, 0, 0, 1, 1 );
    my %returned = map { $_ => 1 } @ids;
    ok( exists $returned{"TANK_1589141306"}, 'hidecompleted should keep tanks (TANK_1589141306)' );
    ok( exists $returned{"TANK_1589138380"}, 'hidecompleted should keep tanks (TANK_1589138380)' );
}

{
    # hidecompleted combined with newonly
    my ( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", 0, 0, 0, 1, 0, 0, 1 );
    is( $filtered, 1, 'hidecompleted + newonly should return only new non-completed archives' );
    is( $ids[0], "e4c422fd10943dc169e3489a38cdbf57101a5f7e",
        'hidecompleted + newonly should return Rohan Kishibe (new and not completed)' );
}

{
    # hidecompleted with lastread sort
    my ( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", 0, "lastread", 0, 0, 0, 0, 1 );

    # Only e69e43..ebg has a non-zero lastreadtime among the non-completed archives
    is( $filtered, 1, 'hidecompleted + lastread sort should only return read-but-not-completed archives' );
    is( $ids[0], "e69e43e1355267f7d32a4f9b7f2fe108d2401ebg",
        'hidecompleted + lastread should return Saturn American Manual (read but not completed)' );
}

done_testing();
