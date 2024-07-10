use strict;
use warnings;
use utf8;
use Data::Dumper;

use LANraragi::Utils::Generic qw(flat);

use Cwd qw( getcwd );

use Test::More;
use Test::Deep;

my $cwd = getcwd();

my @incoming_tags = (
    'group:alpha',    'group:beta', 'namespace:ONE', 'namespace:Two and Three',
    'namespace-fake', 'flip',       'ping',          'cat',
    'with space',     'SCREAM'
);

BEGIN { use_ok('LANraragi::Utils::Tags'); }

note("testing tag rules conversion...");

{
    my $text_rules = '     ping    ->   pong

    no-space   ->         keep     spaces
    ';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply(
        \@rules,
        [ [ 'replace', 'ping', 'pong' ], [ 'replace', 'no-space', 'keep     spaces' ] ],
        'skips empty lines and removes surrounding spaces'
    );
}

{
    my $text_rules = 'SCREAM -> Be Quite';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'replace', 'scream', 'Be Quite' ] ], 'always converts the match term to lowercase' );
}

{
    my $text_rules = "\r\n ping -> pong\r\n -cat";

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'replace', 'ping', 'pong' ], [ 'remove', 'cat', '' ] ], 'handles CRLF' );
}

{
    my $text_rules = 'ping -> おはよう';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'replace', 'ping', 'おはよう' ] ], 'handles non-ASCII characters' );
}

{
    my $text_rules = 'ping
    flip';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'remove', 'ping', '' ], [ 'remove', 'flip', '' ] ], 'blacklist mode' );
}

{
    my $text_rules = 'ping -> pong';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'replace', 'ping', 'pong' ] ], 'simple substitution' );
}

{
    my $text_rules = 'group:alpha -> lone wolf';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'replace', 'group:alpha', 'lone wolf' ] ], 'simple substitution with namespace' );
}

{
    my $text_rules = 'group:* -> block:*';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'replace_ns', 'group', 'block' ] ], 'namespace substitution' );
}

{
    my $text_rules = '-with space';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'remove', 'with space', '' ] ], 'simple deletion' );
}

{
    my $text_rules = '-namespace:*';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'remove_ns', 'namespace', '' ] ], 'namespace deletion' );
}

{
    my $text_rules = '~namespace';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'strip_ns', 'namespace', '' ] ], 'strips namespace' );
}

{
    my $text_rules = '     ping    =>   pong

    no-space   =>         keep     spaces
    ';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply(
        \@rules,
        [ [ 'hash_replace', 'ping', 'pong' ], [ 'hash_replace', 'no-space', 'keep     spaces' ] ],
        'hash_replace: skips empty lines and removes surrounding spaces'
    );
}

{
    my $text_rules = 'SCREAM => Be Quite';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'hash_replace', 'scream', 'Be Quite' ] ], 'hash_replace: always converts the match term to lowercase' );
}

{
    my $text_rules = "\r\n ping => pong\r\n -cat";

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'hash_replace', 'ping', 'pong' ], [ 'remove', 'cat', '' ] ], 'hash_replace: handles CRLF' );
}

{
    my $text_rules = 'ping => おはよう';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'hash_replace', 'ping', 'おはよう' ] ], 'hash_replace: handles non-ASCII characters' );
}

{
    my $text_rules = 'ping => pong';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'hash_replace', 'ping', 'pong' ] ], 'hash_replace: simple substitution' );
}

{
    my $text_rules = 'group:alpha => lone wolf';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'hash_replace', 'group:alpha', 'lone wolf' ] ], 'hash_replace: simple substitution with namespace' );
}

note("testing tags manipulation ...");

{
    my @tags = LANraragi::Utils::Tags::rewrite_tags( \@incoming_tags, [] );

    cmp_deeply( \@tags, \@incoming_tags, 'no rule' );
}

{
    my $text_rules = 'flip -> flop
    cat -> dog';
    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    my @tags = LANraragi::Utils::Tags::rewrite_tags( \@incoming_tags, \@rules );

    cmp_deeply(
        \@tags,
        [   'group:alpha',    'group:beta', 'namespace:ONE', 'namespace:Two and Three',
            'namespace-fake', 'flop',       'ping',          'dog',
            'with space',     'SCREAM'
        ],
        'simple substitution'
    );
}

{
    my $text_rules = '-cat';
    my @rules      = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    my @tags = LANraragi::Utils::Tags::rewrite_tags( \@incoming_tags, \@rules );

    cmp_deeply(
        \@tags,
        [   'group:alpha',    'group:beta', 'namespace:ONE', 'namespace:Two and Three',
            'namespace-fake', 'flip',       'ping',          'with space',
            'SCREAM'
        ],
        'simple deletion'
    );
}

{
    my $text_rules = '-namespace:*';
    my @rules      = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    my @tags = LANraragi::Utils::Tags::rewrite_tags( \@incoming_tags, \@rules );

    cmp_deeply(
        \@tags,
        [ 'group:alpha', 'group:beta', 'namespace-fake', 'flip', 'ping', 'cat', 'with space', 'SCREAM' ],
        'namespace deletion'
    );
}

{
    my $text_rules = 'group:* -> block:*';
    my @rules      = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    my @tags = LANraragi::Utils::Tags::rewrite_tags( \@incoming_tags, \@rules );

    cmp_deeply(
        \@tags,
        [   'block:alpha',    'block:beta', 'namespace:ONE', 'namespace:Two and Three',
            'namespace-fake', 'flip',       'ping',          'cat',
            'with space',     'SCREAM'
        ],
        'namespace substitution'
    );
}

{
    my $text_rules = '~namespace';
    my @rules      = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    my @tags = LANraragi::Utils::Tags::rewrite_tags( \@incoming_tags, \@rules );

    cmp_deeply(
        \@tags,
        [ 'group:alpha', 'group:beta', 'ONE', 'Two and Three', 'namespace-fake', 'flip', 'ping', 'cat', 'with space', 'SCREAM' ],
        'strips namespace'
    );
}

{
    my $text_rules = 'flip => flop
    cat => dog';
    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    my @tags = LANraragi::Utils::Tags::rewrite_tags( \@incoming_tags, \@rules );

    cmp_deeply(
        \@tags,
        [   'group:alpha',    'group:beta', 'namespace:ONE', 'namespace:Two and Three',
            'namespace-fake', 'flop',       'ping',          'dog',
            'with space',     'SCREAM'
        ],
        'simple hash_replace substitution'
    );
}

{
    my $text_rules = '~NameSpace
    scream -> Please Stop
    one => Hello
    -PING';
    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    my @tags = LANraragi::Utils::Tags::rewrite_tags( \@incoming_tags, \@rules );

    cmp_deeply(
        \@tags,
        [ 'group:alpha', 'group:beta', 'Hello', 'Two and Three', 'namespace-fake', 'flip', 'cat', 'with space', 'Please Stop' ],
        'rules matching is case insensitive'
    );
}

note('testing rules unflattening...');

{
    my $expected_rules = [ [ 'strip_ns', 'namespace', '' ], [ 'replace', 'scream', 'Please Stop' ], [ 'remove', 'ping', '' ] ];
    my @flattened_rules = flat(@$expected_rules);

    my @rules = LANraragi::Utils::Tags::unflat_tagrules( \@flattened_rules );

    cmp_deeply( \@rules, $expected_rules, 'unflattened rules' );
}

{
    my @empty_rules;
    my @rules = LANraragi::Utils::Tags::unflat_tagrules( \@empty_rules );
    cmp_deeply( \@rules, [], 'unflattened empty rules' );
    my @rules = LANraragi::Utils::Tags::unflat_tagrules(undef);
    cmp_deeply( \@rules, [], 'unflattened undef array' );
}

note('testing tag rules hash building...');

{
    my $text_rules = 'bug
    -bugs
    ~namespace
    demo:bad -> demo:good
    animal:dog -> animal:cat
    animal:dog => animal:cat
    animal:ant => animal:bird
    animal:ant => animal:penguin';
    my @rules      = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    my ( $other_rules, $hash_replace_rules ) = LANraragi::Utils::Tags::build_tag_replace_hash( \@rules );


    cmp_deeply(
        $other_rules,
        [[ 'remove', 'bug', '' ], [ 'remove', 'bugs', '' ], [ 'strip_ns', 'namespace', '' ], [ 'replace', 'demo:bad', 'demo:good' ], [ 'replace', 'animal:dog', 'animal:cat' ]],
        'return rules other than the hash_replace type'
    );
    cmp_deeply(
        $hash_replace_rules,
        { 'animal:dog' => 'animal:cat', 'animal:ant' => 'animal:penguin' },
        'return a hash containing rules of hash_replace'
    );
}

done_testing();
