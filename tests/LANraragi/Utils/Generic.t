use strict;
use warnings;
use utf8;
use Data::Dumper;

use Test::More;
use Test::Deep;

BEGIN { use_ok('LANraragi::Utils::Generic'); }

note('testing rules flattening...');

{
    my $tagrules = [
        [ 'strip_ns', 'namespace', '' ],
        [ 'replace', 'scream', 'Please Stop' ],
        [ 'remove', 'ping', '']
    ];

    my @flattened_rules = LANraragi::Utils::Generic::flat(@$tagrules);
    cmp_deeply(
        \@flattened_rules,
        [
            'strip_ns',
            'namespace',
            '',
            'replace',
            'scream',
            'Please Stop',
            'remove',
            'ping',
            ''
        ],
        'flattened rules');
}

done_testing();