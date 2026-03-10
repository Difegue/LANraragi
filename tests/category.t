use strict;
use warnings;
use utf8;
use Cwd;

use Mojo::Base 'Mojolicious';

use Test::More;
use Test::Mojo;
use Test::MockObject;
use Mojo::JSON qw(decode_json);
use Data::Dumper;

use LANraragi::Model::Category;
use LANraragi::Model::Tankoubon;
use LANraragi::Model::Config;
use LANraragi::Model::Stats;

# Mock Redis
my $cwd = getcwd;
require $cwd . "/tests/mocks.pl";
setup_redis_mock();

my $redis = LANraragi::Model::Config->get_redis;

# Build search hashes
LANraragi::Model::Stats::build_stat_hashes();

#################################
# Category API Tests
#################################

# Test: Get category list
my @categories = LANraragi::Model::Category::get_category_list();
ok(scalar @categories >= 2, 'Category list has at least 2 categories');

# Test: Get static category list
my @static_cats = LANraragi::Model::Category::get_static_category_list();
ok(scalar @static_cats >= 1, 'Static category list returns at least 1 category');
ok($static_cats[0]->{search} eq "", 'Static category has empty search field');

# Test: Get single category
my %cat = LANraragi::Model::Category::get_category("SET_1589141306");
is($cat{name}, "Segata Sanshiro", 'Category name is correct');
is($cat{pinned}, "1", 'Category pinned status is correct');
ok(ref($cat{archives}) eq 'ARRAY', 'Category archives is an array');

# Test: Create static category
my $new_cat_id = LANraragi::Model::Category::create_category("Test Category", "", "0");
ok($new_cat_id =~ /^SET_\d{10}$/, 'Create category returns valid ID');

my %new_cat = LANraragi::Model::Category::get_category($new_cat_id);
is($new_cat{name}, "Test Category", 'Created category has correct name');
is($new_cat{search}, "", 'Created static category has empty search');

# Test: Create dynamic category
my $dyn_cat_id = LANraragi::Model::Category::create_category("Dynamic Test", "artist:test", "1");
my %dyn_cat = LANraragi::Model::Category::get_category($dyn_cat_id);
is($dyn_cat{name}, "Dynamic Test", 'Dynamic category has correct name');
is($dyn_cat{search}, "artist:test", 'Dynamic category has correct search');
is($dyn_cat{pinned}, "1", 'Dynamic category pinned status is correct');

#################################
# Archive in Category Tests
#################################

# Archive ID from datamodel
my $archive_id = "e69e43e1355267f7d32a4f9b7f2fe108d2401ebf";

# Test: Add archive to category
my ($add_result, $add_err) = LANraragi::Model::Category::add_to_category($new_cat_id, $archive_id);
ok($add_result, 'Added archive to category');

# Verify archive is in category
my %cat_after_add = LANraragi::Model::Category::get_category($new_cat_id);
ok((grep { $_ eq $archive_id } @{$cat_after_add{archives}}), 'Archive is in category after add');

# Test: Adding duplicate archive (should succeed but not duplicate)
my ($dup_result, $dup_err) = LANraragi::Model::Category::add_to_category($new_cat_id, $archive_id);
ok($dup_result, 'Adding duplicate archive returns success');
my %cat_after_dup = LANraragi::Model::Category::get_category($new_cat_id);
my @matching = grep { $_ eq $archive_id } @{$cat_after_dup{archives}};
is(scalar @matching, 1, 'Archive appears only once after duplicate add');

# Test: Cannot add to dynamic category
my ($dyn_add_result, $dyn_add_err) = LANraragi::Model::Category::add_to_category($dyn_cat_id, $archive_id);
ok(!$dyn_add_result, 'Cannot add archive to dynamic category');
like($dyn_add_err, qr/dynamic category/, 'Error message mentions dynamic category');

# Test: Get categories containing archive
my @containing = LANraragi::Model::Category::get_categories_containing_archive($archive_id);
ok((grep { $_->{id} eq $new_cat_id } @containing), 'Found category containing archive');

# Test: Remove archive from category
my ($rm_result, $rm_err) = LANraragi::Model::Category::remove_from_category($new_cat_id, $archive_id);
ok($rm_result, 'Removed archive from category');

my %cat_after_rm = LANraragi::Model::Category::get_category($new_cat_id);
ok(!(grep { $_ eq $archive_id } @{$cat_after_rm{archives}}), 'Archive is not in category after removal');

#################################
# Tankoubon in Category Tests
#################################

# Use existing tankoubon from datamodel
my $tank_id = "TANK_1589141306";

# Test: Add tankoubon to static category
my ($tank_add_result, $tank_add_err) = LANraragi::Model::Category::add_to_category($new_cat_id, $tank_id);
ok($tank_add_result, 'Added tankoubon to category');

# Verify tankoubon is in category
my %cat_with_tank = LANraragi::Model::Category::get_category($new_cat_id);
ok((grep { $_ eq $tank_id } @{$cat_with_tank{archives}}), 'Tankoubon is in category after add');

# Test: Get categories containing tankoubon
my @tank_containing = LANraragi::Model::Category::get_categories_containing_archive($tank_id);
ok((grep { $_->{id} eq $new_cat_id } @tank_containing), 'Found category containing tankoubon');

# Test: Add another tankoubon
my $tank_id2 = "TANK_1589138380";
my ($tank2_add_result, $tank2_add_err) = LANraragi::Model::Category::add_to_category($new_cat_id, $tank_id2);
ok($tank2_add_result, 'Added second tankoubon to category');

my %cat_with_tanks = LANraragi::Model::Category::get_category($new_cat_id);
is(scalar @{$cat_with_tanks{archives}}, 2, 'Category has 2 items (both tankoubons)');

# Test: Remove tankoubon from category
my ($tank_rm_result, $tank_rm_err) = LANraragi::Model::Category::remove_from_category($new_cat_id, $tank_id);
ok($tank_rm_result, 'Removed tankoubon from category');

my %cat_after_tank_rm = LANraragi::Model::Category::get_category($new_cat_id);
ok(!(grep { $_ eq $tank_id } @{$cat_after_tank_rm{archives}}), 'Tankoubon is not in category after removal');
ok((grep { $_ eq $tank_id2 } @{$cat_after_tank_rm{archives}}), 'Other tankoubon still in category');

# Test: Mixed archives and tankoubons in category
my ($mixed_add_result, $mixed_add_err) = LANraragi::Model::Category::add_to_category($new_cat_id, $archive_id);
ok($mixed_add_result, 'Added archive to category with tankoubon');

my %mixed_cat = LANraragi::Model::Category::get_category($new_cat_id);
is(scalar @{$mixed_cat{archives}}, 2, 'Category has 2 items (archive + tankoubon)');
ok((grep { $_ eq $archive_id } @{$mixed_cat{archives}}), 'Archive is in mixed category');
ok((grep { $_ eq $tank_id2 } @{$mixed_cat{archives}}), 'Tankoubon is in mixed category');

#################################
# Delete Category Tests
#################################

# Test: Delete category
my $del_result = LANraragi::Model::Category::delete_category($new_cat_id);
ok($del_result, 'Deleted category');

my %deleted_cat = LANraragi::Model::Category::get_category($new_cat_id);
ok(!%deleted_cat, 'Category no longer exists after deletion');

# Cleanup dynamic category
LANraragi::Model::Category::delete_category($dyn_cat_id);

done_testing();
