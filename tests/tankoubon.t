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

# Mock Redis
my $cwd = getcwd;
require $cwd . "/tests/mocks.pl";
setup_redis_mock();

my $redis = LANraragi::Model::Config->get_redis;

# Build search hashes
LANraragi::Model::Stats::build_stat_hashes();

# Get Tankoubon
my ( $total, $filtered, %tankoubon ) = LANraragi::Model::Tankoubon::get_tankoubon("TANK_0daa851e-55da-36b2-bfa3-2d1c8c3d6d08", 0, 0);
is($tankoubon{id}, "TANK_0daa851e-55da-36b2-bfa3-2d1c8c3d6d08", 'ID test');
is($tankoubon{name}, "Hello", 'Name test');
is($total, 2, 'Total Test');
is($filtered, 2, 'Count Test');
ok($tankoubon{archives}[0] eq "28697b96f0ac5858be2666ed10ca47742c955555", 'Archives test');

# List Tankoubon
my ( $total_list, $filtered_list, @rgs ) = LANraragi::Model::Tankoubon::get_tankoubon_list(0);
is($total_list, 2, 'Total Test');
is($filtered_list, 2, 'Count Test');
ok($rgs[0]{name} eq "Hello" && $rgs[1]{name} eq "World", 'Tank List test');

done_testing();
