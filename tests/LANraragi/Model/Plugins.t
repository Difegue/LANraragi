use strict;
use warnings;
use utf8;
use Data::Dumper;

use Cwd qw( getcwd );

use Test::More;
use Test::Deep;
use Test::Trap;
use Test::MockObject;

my $cwd = getcwd();
require "$cwd/tests/mocks.pl";

my $PKG = 'LANraragi::Model::Plugins';

require_ok($PKG);
use_ok($PKG);

note('calling exec_metadata_plugin without providing an ID');
{
    no warnings 'once', 'redefine';
    local *LANraragi::Model::Plugins::get_logger = sub { return get_logger_mock() };

    my %rdata = LANraragi::Model::Plugins::exec_metadata_plugin( undef, undef, undef, undef );

    cmp_deeply( \%rdata, { 'error' => re('without providing an id') }, 'returned error' );

    %rdata = LANraragi::Model::Plugins::exec_metadata_plugin( undef, 0, undef, undef );

    cmp_deeply( \%rdata, { 'error' => re('without providing an id') }, 'returned error' );

    %rdata = LANraragi::Model::Plugins::exec_metadata_plugin( undef, '', undef, undef );

    cmp_deeply( \%rdata, { 'error' => re('without providing an id') }, 'returned error' );
}

note('exec_metadata_plugin doesn\'t die when get_tags fails');
{
    my $plugin_mock = Test::MockObject->new();
    $plugin_mock->mock( 'plugin_info' => sub { return (); } );
    $plugin_mock->mock( 'get_tags'    => sub { die "Ooops!\n"; } );

    my $redis_mock = Test::MockObject->new();
    $redis_mock->mock( 'hgetall' => sub { return ( 'thumbhash' => 'dummy' ); } );
    $redis_mock->mock( 'quit'    => sub { return 1; } );

    no warnings 'once', 'redefine';
    local *LANraragi::Model::Plugins::get_logger     = sub { return get_logger_mock() };
    local *LANraragi::Model::Config::get_redis       = sub { return $redis_mock; };
    local *LANraragi::Model::Config::enable_tagrules = sub { return; };

    # Act
    my %rdata = LANraragi::Model::Plugins::exec_metadata_plugin( $plugin_mock, 'dummy', undef, undef );

    cmp_deeply( \%rdata, { 'error' => re('Ooops!') }, 'returned error' );
}

note('exec_metadata_plugin returns the tags');
{
    my $plugin_mock = Test::MockObject->new();
    $plugin_mock->mock( 'plugin_info' => sub { return (); } );
    $plugin_mock->mock( 'get_tags'    => sub { return ( tags => 'tag1,tag2' ); } );

    my $redis_mock = Test::MockObject->new();
    $redis_mock->mock( 'hgetall' => sub { return ( 'thumbhash' => 'dummy', 'tags' => '' ); } );
    $redis_mock->mock( 'quit'    => sub { return 1; } );

    no warnings 'once', 'redefine';
    local *LANraragi::Model::Plugins::get_logger     = sub { return get_logger_mock() };
    local *LANraragi::Model::Config::get_redis       = sub { return $redis_mock; };
    local *LANraragi::Model::Config::enable_tagrules = sub { return; };

    # Act
    my %rdata = LANraragi::Model::Plugins::exec_metadata_plugin( $plugin_mock, 'dummy', undef, undef );

    cmp_deeply( \%rdata, { 'new_tags' => ' tag1, tag2' }, 'returned tags' );
}

note('exec_metadata_plugin returns the tags and the title');
{
    my $plugin_mock = Test::MockObject->new();
    $plugin_mock->mock( 'plugin_info' => sub { return (); } );
    $plugin_mock->mock( 'get_tags'    => sub { return ( tags => 'tag1,tag2', title => '  The Best Manga  ' ); } );

    my $redis_mock = Test::MockObject->new();
    $redis_mock->mock( 'hgetall' => sub { return ( 'thumbhash' => 'dummy', 'tags' => '' ); } );
    $redis_mock->mock( 'quit'    => sub { return 1; } );

    no warnings 'once', 'redefine';
    local *LANraragi::Model::Plugins::get_logger       = sub { return get_logger_mock() };
    local *LANraragi::Model::Config::get_redis         = sub { return $redis_mock; };
    local *LANraragi::Model::Config::enable_tagrules   = sub { return; };
    local *LANraragi::Model::Config::can_replacetitles = sub { return 1; };

    # Act
    my %rdata = LANraragi::Model::Plugins::exec_metadata_plugin( $plugin_mock, 'dummy', undef, undef );

    cmp_deeply( \%rdata, { 'new_tags' => ' tag1, tag2', title => 'The Best Manga' }, 'returned tags' );
}

note('exec_script_plugin doesn\'t die when run_script fails');
{
    my $plugin_mock = Test::MockObject->new();
    $plugin_mock->mock( 'plugin_info' => sub { return (); } );
    $plugin_mock->mock( 'run_script'  => sub { die "Ooops!\n"; } );

    no warnings 'once', 'redefine';
    local *LANraragi::Model::Plugins::exec_login_plugin = sub { return; };

    # Act
    my %rdata = LANraragi::Model::Plugins::exec_script_plugin( $plugin_mock, 'dummy', undef );

    cmp_deeply( \%rdata, { 'error' => re('Ooops!') }, 'returned error' );
}

done_testing();