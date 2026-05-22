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

use LANraragi::Model::Tankoubon;
use LANraragi::Model::Config;
use LANraragi::Model::Stats;
use LANraragi::Utils::Database qw(set_tags);

# Mock Redis
my $cwd = getcwd;
require $cwd . "/tests/mocks.pl";
setup_redis_mock();

my $redis = LANraragi::Model::Config->get_redis;

# Build search hashes
LANraragi::Model::Stats::build_stat_hashes();

# Search queries
my ( $total, $filtered, @rgs );
my %tankoubon;

# Get Tankoubon
( $total, $filtered, %tankoubon ) = LANraragi::Model::Tankoubon::get_tankoubon("TANK_1589141306", 0, 0);
is($tankoubon{id}, "TANK_1589141306", 'ID test');
is($tankoubon{name}, "Hello", 'Name test');
is($total, 2, 'Total Test');
is($filtered, 2, 'Count Test');
ok($tankoubon{archives}[0] eq "28697b96f0ac5858be2666ed10ca47742c955555", 'Archives test');

# List Tankoubon
( $total, $filtered, @rgs ) = LANraragi::Model::Tankoubon::get_tankoubon_list(0);
is($total, 2, 'Total Test');
is($filtered, 2, 'Count Test');
ok($rgs[0]{name} eq "World" && $rgs[1]{name} eq "Hello", 'Tank List test');

#################################
# Tankoubon API Tests
#################################

# All 12 archive IDs from datamodel
my @archive_ids = (
    "e69e43e1355267f7d32a4f9b7f2fe108d2401ebf",
    "e69e43e1355267f7d32a4f9b7f2fe108d2401ebg",
    "e4c422fd10943dc169e3489a38cdbf57101a5f7e",
    "4857fd2e7c00db8b0af0337b94055d8445118630",
    "2810d5e0a8d027ecefebca6237031a0fa7b91eb3",
    "28697b96f0ac5858be2614ed10ca47742c9522fd",
    "28697b96f0ac5777be2614ed10ca47742c9522fa",
    "28697b96f0ac5858be2666ed10ca47742c955555",
    "d0be2dc421be4fcd0172e5afceea3970e2f3d940",
    "250e77f12a5ab6972a0895d290c4792f0a326ea8",
    "7e41c6480852a4a914e48c7a3a4084f193e963d9",
    "af8978b1797b72acfff9595a5a2a373ec3d9106d",
);

# Test: Create Tankoubon
my $new_tank_id = LANraragi::Model::Tankoubon::create_tankoubon("Test Tank", "");
ok($new_tank_id =~ /^TANK_\d{10}$/, 'Create tankoubon returns valid ID');

# Verify it exists and has correct name
my ($t, $f, %new_tank) = LANraragi::Model::Tankoubon::get_tankoubon($new_tank_id);
is($new_tank{name}, "Test Tank", 'Created tankoubon has correct name');
is($t, 0, 'New tankoubon has 0 archives');

# Test: Add 12 archives to tank
foreach my $arc_id (@archive_ids) {
    my ($result, $err) = LANraragi::Model::Tankoubon::add_to_tankoubon($new_tank_id, $arc_id);
    ok($result, "Added archive to tankoubon");
}

# Test: Verify ordering with 12 archives (critical test for cmp vs <=> fix)
my ($total_12, $filtered_12, %tank_12) = LANraragi::Model::Tankoubon::get_tankoubon($new_tank_id, 0, -1);
is($total_12, 12, 'Tank has 12 archives');

# Verify archives are in correct insertion order (not string-sorted)
for my $i (0 .. $#archive_ids) {
    is($tank_12{archives}[$i], $archive_ids[$i], "Archive at position $i is correct");
}

# Test: Adding duplicate archive
my ($dup_result, $dup_err) = LANraragi::Model::Tankoubon::add_to_tankoubon($new_tank_id, $archive_ids[0]);
ok($dup_result, 'Adding duplicate archive returns success');
my ($t_dup, $f_dup, %tank_dup) = LANraragi::Model::Tankoubon::get_tankoubon($new_tank_id, 0, -1);
is($t_dup, 12, 'Tank still has 12 archives after duplicate add');

# Test: Remove from tankoubon
my ($rm_result, $rm_err) = LANraragi::Model::Tankoubon::remove_from_tankoubon($new_tank_id, $archive_ids[1]);
ok($rm_result, 'Removed archive from tankoubon');
is($rm_result, 2, 'Removed archive was at position 2');

my ($t_rm, $f_rm, %tank_rm) = LANraragi::Model::Tankoubon::get_tankoubon($new_tank_id, 0, -1);
is($t_rm, 11, 'Tank now has 11 archives');
is($tank_rm{archives}[0], $archive_ids[0], 'First archive unchanged after removal');
is($tank_rm{archives}[1], $archive_ids[2], 'Second archive is now what was third');

# Test: Update archive list (reorder)
my @current_archives = @{ $tank_rm{archives} };
my @reversed = reverse @current_archives;
my ($reorder_result, $reorder_err) = LANraragi::Model::Tankoubon::update_archive_list($new_tank_id, { archives => \@reversed });
ok($reorder_result, 'Reordered archive list');

my ($t_rev, $f_rev, %tank_rev) = LANraragi::Model::Tankoubon::get_tankoubon($new_tank_id, 0, -1);
is_deeply($tank_rev{archives}, \@reversed, 'Archives are in reversed order');

# Test: Update metadata
my ($meta_result, $meta_err) = LANraragi::Model::Tankoubon::update_metadata($new_tank_id, {
    metadata => {
        name => "Updated Tank Name",
        summary => "A test summary",
        tags => "test, tankoubon"
    }
});
ok($meta_result, 'Updated metadata');

my ($t_meta, $f_meta, %tank_meta) = LANraragi::Model::Tankoubon::get_tankoubon($new_tank_id);
is($tank_meta{name}, "Updated Tank Name", 'Name updated correctly');
is($tank_meta{summary}, "A test summary", 'Summary updated correctly');
is($tank_meta{tags}, "test,tankoubon", 'Tags updated correctly');

# Test: Get tankoubons containing archive
my @containing_tanks = LANraragi::Model::Tankoubon::get_tankoubons_containing_archive($archive_ids[0]);
ok((grep { $_ eq $new_tank_id } @containing_tanks), 'Found tank containing archive');

#################################
# Progress Tests
#################################

# Test: New tankoubon has progress=0
my ($t_prog0, $f_prog0, %tank_prog0) = LANraragi::Model::Tankoubon::get_tankoubon($new_tank_id);
is($tank_prog0{progress}, 0, 'New tankoubon starts with progress=0');

# Test: update_tank_progress stores the page
my ($prog_result, $prog_err) = LANraragi::Model::Tankoubon::update_tank_progress($new_tank_id, 7);
ok($prog_result, 'update_tank_progress returns success');

my ($t_prog7, $f_prog7, %tank_prog7) = LANraragi::Model::Tankoubon::get_tankoubon($new_tank_id);
is($tank_prog7{progress}, 7, 'Tank progress updated to 7');

# Test: Delete tankoubon
my $del_result = LANraragi::Model::Tankoubon::delete_tankoubon($new_tank_id);
ok($del_result, 'Deleted tankoubon');

my ($t_del, $f_del, %tank_del) = LANraragi::Model::Tankoubon::get_tankoubon($new_tank_id);
ok(!%tank_del, 'Tankoubon no longer exists after deletion');

#################################
# Imputed Tag Index Tests
#################################

# Create a fresh tank for index testing
my $index_tank_id = LANraragi::Model::Tankoubon::create_tankoubon("Index Test Tank", "");
ok($index_tank_id =~ /^TANK_\d{10}$/, 'Create index test tankoubon');

# Get the search redis for checking indexes
my $redis_search = LANraragi::Model::Config->get_redis_search;

# Test: Adding archive to tank updates INDEX_* sets
# Archive "d0be2dc421be4fcd0172e5afceea3970e2f3d940" has tag "fruit:apple"
my $apple_archive = "d0be2dc421be4fcd0172e5afceea3970e2f3d940";
my ($add_result, $add_err) = LANraragi::Model::Tankoubon::add_to_tankoubon($index_tank_id, $apple_archive);
ok($add_result, 'Added apple archive to tank');

# Check that tank is now in INDEX_fruit:apple
my @apple_index = $redis_search->smembers("INDEX_fruit:apple");
ok((grep { $_ eq $index_tank_id } @apple_index), 'Tank added to INDEX_fruit:apple after adding archive');

# Test: Adding second archive with different tag updates indexes
# Archive "250e77f12a5ab6972a0895d290c4792f0a326ea8" has tag "fruit:banana"
my $banana_archive = "250e77f12a5ab6972a0895d290c4792f0a326ea8";
($add_result, $add_err) = LANraragi::Model::Tankoubon::add_to_tankoubon($index_tank_id, $banana_archive);
ok($add_result, 'Added banana archive to tank');

my @banana_index = $redis_search->smembers("INDEX_fruit:banana");
ok((grep { $_ eq $index_tank_id } @banana_index), 'Tank added to INDEX_fruit:banana after adding archive');

# Tank should still be in apple index
@apple_index = $redis_search->smembers("INDEX_fruit:apple");
ok((grep { $_ eq $index_tank_id } @apple_index), 'Tank still in INDEX_fruit:apple');

# Test: Removing archive removes tank from index (if no other archive has that tag)
my ($rm_result2, $rm_err2) = LANraragi::Model::Tankoubon::remove_from_tankoubon($index_tank_id, $apple_archive);
ok($rm_result2, 'Removed apple archive from tank');
is($rm_result2, 1, 'Removed archive was at position 1');

@apple_index = $redis_search->smembers("INDEX_fruit:apple");
ok(!(grep { $_ eq $index_tank_id } @apple_index), 'Tank removed from INDEX_fruit:apple after removing archive');

# Tank should still be in banana index
@banana_index = $redis_search->smembers("INDEX_fruit:banana");
ok((grep { $_ eq $index_tank_id } @banana_index), 'Tank still in INDEX_fruit:banana');

# Test: Modifying archive tags updates tank indexes
# Change banana archive's tags to "fruit:elderberry"
set_tags($banana_archive, "fruit:elderberry");

# Tank should now be in elderberry index
my @elderberry_index = $redis_search->smembers("INDEX_fruit:elderberry");
ok((grep { $_ eq $index_tank_id } @elderberry_index), 'Tank added to INDEX_fruit:elderberry after archive tag change');

# Tank should be removed from banana index
@banana_index = $redis_search->smembers("INDEX_fruit:banana");
ok(!(grep { $_ eq $index_tank_id } @banana_index), 'Tank removed from INDEX_fruit:banana after archive tag change');

# Test: Tank's own tags are also in indexes
my ($meta_result2, $meta_err2) = LANraragi::Model::Tankoubon::update_metadata($index_tank_id, {
    metadata => {
        tags => "series:test series"
    }
});
ok($meta_result2, 'Updated tank own tags');

my @series_index = $redis_search->smembers("INDEX_series:test series");
ok((grep { $_ eq $index_tank_id } @series_index), 'Tank in INDEX for its own tags');

# Test: Bulk update_archive_list handles index updates
# Add cherry archive, remove elderberry (banana) archive
my $cherry_archive = "7e41c6480852a4a914e48c7a3a4084f193e963d9";
my ($bulk_result, $bulk_err) = LANraragi::Model::Tankoubon::update_archive_list($index_tank_id, {
    archives => [$cherry_archive]
});
ok($bulk_result, 'Bulk updated archive list');

my @cherry_index = $redis_search->smembers("INDEX_fruit:cherry");
ok((grep { $_ eq $index_tank_id } @cherry_index), 'Tank in INDEX_fruit:cherry after bulk update');

@elderberry_index = $redis_search->smembers("INDEX_fruit:elderberry");
ok(!(grep { $_ eq $index_tank_id } @elderberry_index), 'Tank removed from INDEX_fruit:elderberry after bulk update');

# Cleanup
LANraragi::Model::Tankoubon::delete_tankoubon($index_tank_id);

done_testing();
