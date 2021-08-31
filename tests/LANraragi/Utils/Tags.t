use strict;
use warnings;
use utf8;
use Data::Dumper;

use Cwd qw( getcwd );

use Test::More;
use Test::Deep;

my $cwd = getcwd();

my $SAMPLES     = "$cwd/tests/samples";
my $META_FILE_1 = "$SAMPLES/meta/tag_list.meta.txt";
my $META_FILE_2 = "$SAMPLES/meta/tag_list2.meta.txt";
my $DEFAULT_METAFILE = 'lanraragi.nfo';

my @incoming_tags = (
    'group:alpha',
    'group:beta',
    'namespace:one',
    'namespace:two and three',
    'namespace-fake',
    'flip',
    'ping',
    'cat',
    'with space'
);

BEGIN { use_ok('LANraragi::Utils::Tags'); }

note ("testing tags rules conversion...");

{
    my $text_rules = '     ping    ->   pong

    no-space   ->         keep     spaces
    ';

    my @rules = LANraragi::Utils::Tags::tags_rules_to_array($text_rules);

    cmp_deeply( \@rules, [ [ 'replace', 'ping', 'pong' ], [ 'replace', 'no-space', 'keep     spaces' ] ], 'skips empty lines and remove surrounding spaces');
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

    cmp_deeply( \@rules, [ [ 'strip_ns', 'namespace', undef ] ], 'strip namespace');
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
            'namespace:one',
            'namespace:two and three',
            'namespace-fake',
            'flop',
            'ping',
            'dog',
            'with space'
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
            'namespace:one',
            'namespace:two and three',
            'namespace-fake',
            'flip',
            'ping',
            'with space'
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
            'with space'
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
            'one',
            'two and three',
            'namespace-fake',
            'flip',
            'ping',
            'cat',
            'with space'
        ],
        'strip namespace');
}

done_testing();
