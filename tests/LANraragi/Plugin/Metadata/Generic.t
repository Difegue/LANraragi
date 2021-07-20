use strict;
use warnings;
use utf8;
use Data::Dumper;

use Module::Pluggable require => 1, search_path => ['LANraragi::Plugin::Metadata'];

use Test::More;
use Test::Deep;

my @required_keywords = qw( author description icon name namespace parameters type version );
my @keywords = ( @required_keywords, qw( cooldown login_from oneshot_arg ) );

my @metadata_modules = plugins();

foreach my $plugin (@metadata_modules) {
    use_ok($plugin);
    can_ok($plugin, 'plugin_info');
    can_ok($plugin, 'get_tags');

    my %pluginfo = $plugin->plugin_info();
    my @keys = keys %pluginfo;
    cmp_deeply( \@keys, subsetof( @keywords ), 'valid keywords' );
    cmp_deeply( \@keys, supersetof( @required_keywords ), 'required keywords' );
    is($pluginfo{type}, 'metadata', 'plugin type');
}

done_testing();
