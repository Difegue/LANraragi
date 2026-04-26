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

use LANraragi::Model::Stamp;
use LANraragi::Model::Config;
use LANraragi::Model::Stats;

# Mock Redis
my $cwd = getcwd;
require $cwd . "/tests/mocks.pl";
setup_redis_mock();

my $redis = LANraragi::Model::Config->get_redis;

# Build search hashes
LANraragi::Model::Stats::build_stat_hashes();

# Get stamped pages
my ( $indexes, $err ) = LANraragi::Model::Stamp::get_stamped_pages( "be447b58ea66137c415ee306ee2ac44b308ee484" );
is ( scalar @$indexes, 4, "Page test" );

my ( $stamps, $err ) = LANraragi::Model::Stamp::get_stamps_by_page("be447b58ea66137c415ee306ee2ac44b308ee484", 0);
is ( scalar @$stamps, 2, "Stamps by page length test" );

my ( $stamps, $err ) = LANraragi::Model::Stamp::get_stamps_by_page("be447b58ea66137c415ee306ee2ac44b308ee484", 1);
is ( $stamps->[0]{"id"}, "STAMPS_1_1777224824662", "Stamps by page value test" );

my ( $stamp, $err ) = LANraragi::Model::Stamp::get_stamp("STAMPS_0_1777224824660");
is ( %$stamp{"id"}, "STAMPS_0_1777224824660", "Get stamp id test" );
is ( %$stamp{"content"}, "Lorem", "Get stamp content test" );
is ( %$stamp{"position"}, "0,0", "Get stamp position test" );

done_testing();
