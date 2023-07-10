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

# Search queries
my ( $total, $filtered, @rgs );

# Get Tankoubon
my %tankoubon = LANraragi::Model::Tankoubon::get_tankoubon("TANK_1589141306", 0, 0);
is($tankoubon{id}, "TANK_1589141306", 'ID test');
is($tankoubon{name}, "Hello", 'Name test');
ok($tankoubon{archives}[0] eq "28697b96f0ac5858be2614ed10ca47742c9522fd", 'Archives test');

# List Tankoubon
( $total, $filtered, @rgs ) = LANraragi::Model::Tankoubon::get_tankoubon_list(0);
is($total, 2, 'Total Test');
is($filtered, 2, 'Count Test');
ok($rgs[0]{name} eq "World" && $rgs[1]{name} eq "Hello", 'Tank List test');

done_testing();
