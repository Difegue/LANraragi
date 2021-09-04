use strict;
use warnings;
use utf8;
use Data::Dumper;

use Cwd qw( getcwd );

use Test::More;
use Test::Deep;

my $cwd = getcwd();

my @incoming_tags = (
    'group:alpha',
    'group:beta',
    'namespace:ONE',
    'namespace:Two and Three',
    'namespace-fake',
    'flip',
    'ping',
    'cat',
    'with space',
    'SCREAM'
);

BEGIN { use_ok('LANraragi::Utils::Tags'); }

note ("testing tag rules conversion...");

{
    my $text_rules = '     ping    ->   pong

    no-space   ->         keep     spaces
    ';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'replace', 'ping', 'pong' ], [ 'replace', 'no-space', 'keep     spaces' ] ], 'skips empty lines and removes surrounding spaces');
}

{
    my $text_rules = 'SCREAM -> Be Quite';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'replace', 'scream', 'Be Quite' ] ], 'always converts the match term to lowercase');
}

{
    my $text_rules = "\r\n ping -> pong\r\n -cat";

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'replace', 'ping', 'pong' ], [ 'remove', 'cat', undef ] ], 'handles CRLF');
}

{
    my $text_rules = 'ping
    flip';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'remove', 'ping', undef ], [ 'remove', 'flip', undef ] ], 'blacklist mode');
}

{
    my $text_rules = 'ping -> pong';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'replace', 'ping', 'pong' ] ], 'simple substitution');
}

{
    my $text_rules = 'group:alpha -> lone wolf';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'replace', 'group:alpha', 'lone wolf' ] ], 'simple substitution with namespace');
}

{
    my $text_rules = 'group:* -> block:*';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'replace_ns', 'group', 'block' ] ], 'namespace substitution');
}

{
    my $text_rules = '-with space';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'remove', 'with space', undef ] ], 'simple deletion');
}

{
    my $text_rules = '-namespace:*';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'remove_ns', 'namespace', undef ] ], 'namespace deletion');
}

{
    my $text_rules = '~namespace';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'strip_ns', 'namespace', undef ] ], 'strips namespace');
}

note("testing tags manipulation ...");

{
    my @tags = LANraragi::Utils::Tags::rewrite_tags(\@incoming_tags, []);

    cmp_deeply( \@tags, \@incoming_tags, 'no rule');
}

{
    my $text_rules = 'flip -> flop
    cat -> dog';
    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    my @tags = LANraragi::Utils::Tags::rewrite_tags(\@incoming_tags, \@rules);

    cmp_deeply(
        \@tags,
        [
            'group:alpha',
            'group:beta',
            'namespace:ONE',
            'namespace:Two and Three',
            'namespace-fake',
            'flop',
            'ping',
            'dog',
            'with space',
            'SCREAM'
        ],
        'simple substitution');
}

{
    my $text_rules = '-cat';
    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    my @tags = LANraragi::Utils::Tags::rewrite_tags(\@incoming_tags, \@rules);

    cmp_deeply(
        \@tags,
        [
            'group:alpha',
            'group:beta',
            'namespace:ONE',
            'namespace:Two and Three',
            'namespace-fake',
            'flip',
            'ping',
            'with space',
            'SCREAM'
        ],
        'simple deletion');
}

{
    my $text_rules = '-namespace:*';
    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    my @tags = LANraragi::Utils::Tags::rewrite_tags(\@incoming_tags, \@rules);

    cmp_deeply(
        \@tags,
        [
            'group:alpha',
            'group:beta',
            'namespace-fake',
            'flip',
            'ping',
            'cat',
            'with space',
            'SCREAM'
        ],
        'namespace deletion');
}

{
    my $text_rules = '~namespace';
    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    my @tags = LANraragi::Utils::Tags::rewrite_tags(\@incoming_tags, \@rules);

    cmp_deeply(
        \@tags,
        [
            'group:alpha',
            'group:beta',
            'ONE',
            'Two and Three',
            'namespace-fake',
            'flip',
            'ping',
            'cat',
            'with space',
            'SCREAM'
        ],
        'strips namespace');
}

{
    my $text_rules = '~NameSpace
    scream -> Please Stop
    -PING';
    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    my @tags = LANraragi::Utils::Tags::rewrite_tags(\@incoming_tags, \@rules);

    cmp_deeply(
        \@tags,
        [
            'group:alpha',
            'group:beta',
            'ONE',
            'Two and Three',
            'namespace-fake',
            'flip',
            'cat',
            'with space',
            'Please Stop'
        ],
        'rules matching is case insensitive');
}

done_testing();
