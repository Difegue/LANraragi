use strict;
use warnings;
use utf8;
use Data::Dumper;

use Cwd qw( getcwd );
my $cwd = getcwd();

require "$cwd/tests/mocks.pl";
setup_redis_mock();

use Module::Pluggable require => 1, search_path => ['LANraragi::Plugin::Metadata'];

use Test::More;
use Test::Deep;

my @required_keywords = qw( author description name namespace type version );
my @keywords          = ( @required_keywords, qw( cooldown icon login_from oneshot_arg parameters to_named_params ) );

my @metadata_modules = plugins();

foreach my $plugin (@metadata_modules) {
    use_ok($plugin);
    can_ok( $plugin, 'plugin_info' );
    can_ok( $plugin, 'get_tags' );

    my %pluginfo = $plugin->plugin_info();
    my @keys     = keys %pluginfo;
    cmp_deeply( \@keys, subsetof(@keywords),            'valid keywords' );
    cmp_deeply( \@keys, supersetof(@required_keywords), 'required keywords' );
    is( $pluginfo{type}, 'metadata', 'plugin type' );
}

done_testing();
