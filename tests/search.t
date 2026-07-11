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
is( $filtered, 13, qq(Empty search(full index)) );
( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( $search, "", 0, 0, 0, 0, 0, 0, 0 );
is( $filtered, 13, qq(Empty search(tank grouping off)) );

note('testing initialized empty index with tank grouping enabled...');
{
    my $redis_search = LANraragi::Model::Config->get_redis_search;
    $redis_search->del("LRR_TANKGROUPED");

    my ( $empty_total, $empty_filtered, @empty_ids ) =
      LANraragi::Model::Search::do_search( "", "", 0, 0, 0, 0, 0, 1, 0 );
    is( $empty_total,    0, 'empty initialized grouped search total is zero' );
    is( $empty_filtered, 0, 'empty initialized grouped search filtered count is zero' );
    is_deeply( \@empty_ids, [], 'empty initialized grouped search returns no ids' );

    LANraragi::Model::Stats::build_stat_hashes();
}

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
# Two archives are now new: e4c422fd10943dc169e3489a38cdbf57101a5f7e and 28697b96f0ac5858be2666ed10ca47742c955555
is( $filtered, 2, qq(Search with new filter applied) );

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
    "d0be2dc421be4fcd0172e5afceea3970e2f3d940",
    "250e77f12a5ab6972a0895d290c4792f0a326ea8",
    "7e41c6480852a4a914e48c7a3a4084f193e963d9",
    "af8978b1797b72acfff9595a5a2a373ec3d9106d",
);

{
    # Sort by artist, ascending: shirow masamune < wada rco < yoshiyuki sadamoto
    my ( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", -1, "artist", 0, 0, 0, 0, 0 );
    is( $filtered, 13, 'Artist sort should return all archives' );

    # Keyed partition (positions 0-3): boundary positions are deterministic
    is( $ids[0], "4857fd2e7c00db8b0af0337b94055d8445118630",
        'Artist asc should place shirow masamune first' );
    is( $ids[3], "be447b58ea66137c415ee306ee2ac44b308ee484",
        'Artist asc should place yoshiyuki sadamoto last in keyed partition' );
    is_deeply( { map { $_ => 1 } @ids[0..3] }, \%expected_keyed,
        'Artist asc keyed partition should contain all artist-tagged archives' );

    # Unkeyed partition (positions 4-12): archives without artist tag
    is_deeply( { map { $_ => 1 } @ids[4..12] }, \%expected_unkeyed,
        'Artist asc should place all unkeyed archives at positions 5-13' );
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
    is_deeply( { map { $_ => 1 } @ids[4..12] }, \%expected_unkeyed,
        'Artist desc should keep all unkeyed archives at positions 5-13' );
}

note('testing hidecompleted filter...');

# Completed archives in the mock data (progress / pagecount > 0.85):
#   e69e43e1...ebf: pagecount=2,   progress=10 => 10/2  = 5.00  => completed
#   4857fd2e...630: pagecount=34,  progress=34 => 34/34 = 1.00  => completed
#   2810d5e0...eb3: pagecount=34,  progress=34 => 34/34 = 1.00  => completed
# Not completed: 10 remaining archives (13 total - 3 completed)

{
    # Basic hidecompleted test (no tank grouping)
    my ( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", 0, 0, 0, 0, 0, 0, 1 );
    is( $filtered, 10, 'hidecompleted should remove 3 completed archives (13 - 3 = 10)' );

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
    # Both new archives (e4c422fd... and 28697b96...55) have no progress, so neither is completed
    my ( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", 0, 0, 0, 1, 0, 0, 1 );
    is( $filtered, 2, 'hidecompleted + newonly should return both new non-completed archives' );
    my %new_returned = map { $_ => 1 } @ids;
    ok( exists $new_returned{"e4c422fd10943dc169e3489a38cdbf57101a5f7e"},
        'hidecompleted + newonly should include Rohan Kishibe (new and not completed)' );
    ok( exists $new_returned{"28697b96f0ac5858be2666ed10ca47742c955555"},
        'hidecompleted + newonly should include All about Egypt (new and not completed)' );
}

{
    # hidecompleted with lastread sort
    my ( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", 0, "lastread", 0, 0, 0, 0, 1 );

    # Only e69e43..ebg has a non-zero lastreadtime among the non-completed archives
    is( $filtered, 1, 'hidecompleted + lastread sort should only return read-but-not-completed archives' );
    is( $ids[0], "e69e43e1355267f7d32a4f9b7f2fe108d2401ebg",
        'hidecompleted + lastread should return Saturn American Manual (read but not completed)' );
}

note('testing tag sort with tanks (grouptanks=1) -- exercises _fallback_tags since evalsha is not mocked...');

{
    # TANK_1589141306 tags: "series:hello world"       => keyed (hello world)
    # TANK_1589138380 tags: ""                         => unkeyed
    # be447b58...484  tags: "series:Neon Genesis Evangelion, ..." => keyed (neon genesis evangelion)
    # All other archives have no series tag            => unkeyed
    my ( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", -1, "series", 0, 0, 0, 1, 0 );
    is( $filtered, 13, 'tank tag sort: series asc should return all 13 items' );
    is( $ids[0], "TANK_1589141306",
        'tank tag sort: series asc puts TANK_1589141306 first (series:hello world < neon genesis evangelion)' );
    is( $ids[1], "be447b58ea66137c415ee306ee2ac44b308ee484",
        'tank tag sort: series asc puts NGE archive second (series:Neon Genesis Evangelion)' );

    my %remaining = map { $_ => 1 } @ids[ 2 .. 12 ];
    ok( exists $remaining{"TANK_1589138380"},
        'tank tag sort: TANK_1589138380 (no series tag) goes to unkeyed partition' );
    ok( !exists $remaining{"TANK_1589141306"},
        'tank tag sort: TANK_1589141306 is not in unkeyed partition' );
}

{
    # Descending: keyed partition reverses
    my ( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", -1, "series", 1, 0, 0, 1, 0 );
    is( $ids[0], "be447b58ea66137c415ee306ee2ac44b308ee484",
        'tank tag sort: series desc puts NGE archive first' );
    is( $ids[1], "TANK_1589141306",
        'tank tag sort: series desc puts TANK_1589141306 second' );
}

note('testing date_added sort with tanks (grouptanks=1) -- reproduces the "tanks always pushed last" bug...');

# date_added tags in the mock data (grouptanks=1 -- Egypt/Computer Room are grouped into their tanks):
#   TANK_1589138380: own tag "date_added:1000000000" (wins over any imputed member value)
#   4857fd2e...630 (Ghost in the Shell):   date_added:1620000000
#   TANK_1589141306: no own date_added tag -> imputed as MAX(Egypt=1600000000, Computer Room=1650000000) = 1650000000
#   e4c422fd...7e (Rohan Kishibe):         date_added:1700000000
# All other archives have no date_added tag -> unkeyed, pushed to the back.
my %expected_date_keyed = map { $_ => 1 } (
    "TANK_1589138380",
    "4857fd2e7c00db8b0af0337b94055d8445118630",
    "TANK_1589141306",
    "e4c422fd10943dc169e3489a38cdbf57101a5f7e",
);

{
    my ( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", -1, "date_added", 0, 0, 0, 1, 0 );
    is( $filtered, 13, 'date_added sort should return all 13 items' );

    is_deeply( { map { $_ => 1 } @ids[ 0 .. 3 ] }, \%expected_date_keyed,
        'date_added asc keyed partition should contain both tanks plus Ghost in the Shell and Rohan Kishibe' );

    is( $ids[0], "TANK_1589138380",
        'date_added asc: TANK_1589138380 (own tag 1000000000) sorts first, not pushed to the back' );
    is( $ids[1], "4857fd2e7c00db8b0af0337b94055d8445118630",
        'date_added asc: Ghost in the Shell (1620000000) is second' );
    is( $ids[2], "TANK_1589141306",
        'date_added asc: TANK_1589141306 (imputed max 1650000000) is third, not pushed to the back' );
    is( $ids[3], "e4c422fd10943dc169e3489a38cdbf57101a5f7e",
        'date_added asc: Rohan Kishibe (1700000000) is fourth' );
}

{
    # Descending: keyed partition reverses, unkeyed items stay at the back either way
    my ( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", -1, "date_added", 1, 0, 0, 1, 0 );

    is_deeply( { map { $_ => 1 } @ids[ 0 .. 3 ] }, \%expected_date_keyed,
        'date_added desc keyed partition should contain both tanks plus Ghost in the Shell and Rohan Kishibe' );

    is( $ids[0], "e4c422fd10943dc169e3489a38cdbf57101a5f7e",
        'date_added desc: Rohan Kishibe (1700000000) sorts first' );
    is( $ids[1], "TANK_1589141306",
        'date_added desc: TANK_1589141306 (imputed max 1650000000) is second, not pushed to the back' );
    is( $ids[2], "4857fd2e7c00db8b0af0337b94055d8445118630",
        'date_added desc: Ghost in the Shell (1620000000) is third' );
    is( $ids[3], "TANK_1589138380",
        'date_added desc: TANK_1589138380 (own tag 1000000000) is fourth, not pushed to the back' );
}

note('testing timestamp sort with tanks -- same date-type imputation logic applies to the "timestamp" namespace...');

{
    # Temporarily swap Rohan Kishibe's and Computer Room's date_added tag for a timestamp tag,
    # to prove the imputation isn't hardcoded to only the date_added namespace.
    my $orig_rohan_tags        = $redis->hget( "e4c422fd10943dc169e3489a38cdbf57101a5f7e",   "tags" );
    my $orig_computerroom_tags = $redis->hget( "28697b96f0ac5777be2614ed10ca47742c9522fa", "tags" );

    $redis->hset( "e4c422fd10943dc169e3489a38cdbf57101a5f7e", "tags",
        "parody: jojo's bizarre adventure, timestamp:1700000000" );
    $redis->hset( "28697b96f0ac5777be2614ed10ca47742c9522fa", "tags",
        "year of shadow, character:vector the crocodile, timestamp:1650000000" );

    my ( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", -1, "timestamp", 0, 0, 0, 1, 0 );

    my %pos = map { $ids[$_] => $_ } 0 .. $#ids;
    ok( $pos{"TANK_1589141306"} <= 3,
        'timestamp sort: TANK_1589141306 (imputed from Computer Room) is in the keyed partition, not pushed to the back' );
    ok( $pos{"TANK_1589141306"} < $pos{"e4c422fd10943dc169e3489a38cdbf57101a5f7e"},
        'timestamp sort: TANK_1589141306 (1650000000) sorts before Rohan Kishibe (1700000000)' );

    $redis->hset( "e4c422fd10943dc169e3489a38cdbf57101a5f7e",   "tags", $orig_rohan_tags );
    $redis->hset( "28697b96f0ac5777be2614ed10ca47742c9522fa", "tags", $orig_computerroom_tags );
}

note('testing lastread sort with tanks (grouptanks=1) -- exercises _fallback_lastread since evalsha is not mocked...');

{
    # Give Computer Room (a member of both tanks) a non-zero lastreadtime so both tanks
    # appear in the lastread sort results.  Restore the value after the block.
    $redis->hset( "28697b96f0ac5777be2614ed10ca47742c9522fa", "lastreadtime", 1589038279 );

    my ( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search( "", "", -1, "lastread", 0, 0, 0, 1, 0 );

    # Standalones with lastreadtime > 0 in LRR_TANKGROUPED:
    #   Saturn USA (1589038281), Saturn JP (1589038280), Ghost (1589038280), FGO MEMO 2 (1589038280)
    # Tanks with max member lastreadtime > 0:
    #   TANK_1589141306: max(Egypt=0, Computer Room=1589038279) = 1589038279
    #   TANK_1589138380: max(Computer Room=1589038279) = 1589038279
    is( $filtered, 6, 'tank lastread sort: both tanks with a read member archive should appear' );
    is( $ids[0], "e69e43e1355267f7d32a4f9b7f2fe108d2401ebg",
        'tank lastread sort: Saturn JP (highest lastreadtime 1589038281) should be first' );

    my %lrt = map { $_ => 1 } @ids;
    ok( exists $lrt{"TANK_1589141306"},
        'tank lastread sort: TANK_1589141306 present (member Computer Room was read)' );
    ok( exists $lrt{"TANK_1589138380"},
        'tank lastread sort: TANK_1589138380 present (member Computer Room was read)' );
    ok( !exists $lrt{"28697b96f0ac5777be2614ed10ca47742c9522fa"},
        'tank lastread sort grouptanks=1: Computer Room itself not present (grouped into its tanks)' );

    # Ascending: oldest-read archives first, so tanks (1589038279) precede Saturn JP (1589038281)
    my ( $total2, $filtered2, @ids2 ) = LANraragi::Model::Search::do_search( "", "", -1, "lastread", 1, 0, 0, 1, 0 );
    is( $ids2[-1], "e69e43e1355267f7d32a4f9b7f2fe108d2401ebg",
        'tank lastread sort asc: Saturn JP (most recently read) should be last' );
    my %pos2 = map { $ids2[$_] => $_ } 0 .. $#ids2;
    ok( $pos2{"TANK_1589141306"} < $pos2{"e69e43e1355267f7d32a4f9b7f2fe108d2401ebg"},
        'tank lastread sort asc: TANK_1589141306 appears before Saturn JP' );

    $redis->hset( "28697b96f0ac5777be2614ed10ca47742c9522fa", "lastreadtime", 0 );
}

done_testing();
