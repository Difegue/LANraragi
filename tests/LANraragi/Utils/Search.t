use strict;
use warnings;
use utf8;
use Cwd;

use Test::More;

# Mock Redis
my $cwd = getcwd;
require $cwd . "/tests/mocks.pl";
setup_redis_mock();

BEGIN { use_ok('LANraragi::Utils::Search'); }

# Helper: normalize then reduce
sub norm_reduce {
    my ($descs) = @_;
    my $normed = LANraragi::Utils::Search::normalize_clauses($descs);
    return LANraragi::Utils::Search::reduce_clauses($normed);
}

note('testing reduce_clauses: single clause passthrough...');
{
    my $result = norm_reduce([
        { filter => "artist:wada rco", categories => [], newonly => 0, untaggedonly => 0 },
    ]);
    is( scalar @$result, 1, 'Single clause should pass through unchanged' );
}

note('testing reduce_clauses: identical clause dedup...');
{
    my $result = norm_reduce([
        { filter => "artist:wada rco", categories => [], newonly => 0, untaggedonly => 0 },
        { filter => "artist:wada rco", categories => [], newonly => 0, untaggedonly => 0 },
    ]);
    is( scalar @$result, 1, 'Identical clauses should deduplicate to 1' );
}

note('testing reduce_clauses: triple identical clause dedup...');
{
    my $result = norm_reduce([
        { filter => "artist:wada rco", categories => [], newonly => 0, untaggedonly => 0 },
        { filter => "artist:wada rco", categories => [], newonly => 0, untaggedonly => 0 },
        { filter => "artist:wada rco", categories => [], newonly => 0, untaggedonly => 0 },
    ]);
    is( scalar @$result, 1, 'Three identical clauses should deduplicate to 1' );
}

note('testing reduce_clauses: distinct clauses preserved...');
{
    my $result = norm_reduce([
        { filter => "artist:wada rco",        categories => [], newonly => 0, untaggedonly => 0 },
        { filter => "artist:shirow masamune", categories => [], newonly => 0, untaggedonly => 0 },
    ]);
    is( scalar @$result, 2, 'Distinct clauses should both be preserved' );
}

note('testing reduce_clauses: absorption A OR (A AND B) -> A...');
{
    my $result = norm_reduce([
        { filter => "artist:wada rco",                          categories => [], newonly => 0, untaggedonly => 0 },
        { filter => "artist:wada rco, character:ereshkigal",    categories => [], newonly => 0, untaggedonly => 0 },
    ]);
    is( scalar @$result, 1, 'A OR (A AND B) should absorb to 1 clause' );
    is( scalar @{ $result->[0]{tokens} }, 1, 'Surviving clause should have 1 token (less restrictive)' );
}

note('testing reduce_clauses: absorption order independent...');
{
    my $result = norm_reduce([
        { filter => "artist:wada rco, character:ereshkigal",    categories => [], newonly => 0, untaggedonly => 0 },
        { filter => "artist:wada rco",                          categories => [], newonly => 0, untaggedonly => 0 },
    ]);
    is( scalar @$result, 1, 'Absorption should work regardless of clause order' );
    is( scalar @{ $result->[0]{tokens} }, 1, 'Surviving clause should have 1 token (less restrictive)' );
}

note('testing reduce_clauses: irreducible clauses preserved...');
{
    my $result = norm_reduce([
        { filter => "artist:wada rco, character:ereshkigal",          categories => [], newonly => 0, untaggedonly => 0 },
        { filter => "character:ereshkigal, language:english",         categories => [], newonly => 0, untaggedonly => 0 },
    ]);
    is( scalar @$result, 2, 'Irreducible clauses should both be preserved' );
}

note('testing reduce_clauses: empty filter subsumes any filter...');
{
    my $result = norm_reduce([
        { filter => "",                 categories => [], newonly => 0, untaggedonly => 0 },
        { filter => "artist:wada rco", categories => [], newonly => 0, untaggedonly => 0 },
    ]);
    is( scalar @$result, 1, 'Empty filter should absorb any filtered clause' );
    is( scalar @{ $result->[0]{tokens} }, 0, 'Surviving clause should have 0 tokens' );
}

note('testing reduce_clauses: newonly flag prevents absorption...');
{
    my $result = norm_reduce([
        { filter => "artist:wada rco", categories => [], newonly => 1, untaggedonly => 0 },
        { filter => "artist:wada rco", categories => [], newonly => 0, untaggedonly => 0 },
    ]);
    is( scalar @$result, 1, 'newonly=0 should absorb newonly=1 with same filter' );
    is( $result->[0]{newonly}, 0, 'Surviving clause should have newonly=0' );
}

note('testing reduce_clauses: newonly=1 does not subsume newonly=-1...');
{
    my $result = norm_reduce([
        { filter => "artist:wada rco", categories => [], newonly => 1,  untaggedonly => 0 },
        { filter => "artist:wada rco", categories => [], newonly => -1, untaggedonly => 0 },
    ]);
    is( scalar @$result, 2, 'newonly=1 and newonly=-1 should not absorb each other' );
}

note('testing reduce_clauses: category subset absorption...');
{
    my $result = norm_reduce([
        { filter => "artist:wada rco", categories => [],                                                newonly => 0, untaggedonly => 0 },
        { filter => "artist:wada rco", categories => [{ id => "SET_1589141306", mode => "include" }],   newonly => 0, untaggedonly => 0 },
    ]);
    is( scalar @$result, 1, 'Clause without categories should absorb clause with categories' );
    is( scalar @{ $result->[0]{categories} }, 0, 'Surviving clause should have no categories' );
}

note('testing reduce_clauses: category superset not absorbed...');
{
    my $result = norm_reduce([
        { filter => "", categories => [{ id => "SET_1589141306", mode => "include" }],  newonly => 0, untaggedonly => 0 },
        { filter => "", categories => [],                                                newonly => 0, untaggedonly => 0 },
    ]);
    is( scalar @$result, 1, 'Empty clause should absorb category-filtered clause' );
    is( scalar @{ $result->[0]{categories} }, 0, 'Surviving clause should be the unconstrained one' );
}

note('testing reduce_clauses: multi-category absorption...');
{
    my $result = norm_reduce([
        { filter => "", categories => [{ id => "SET_1589141306", mode => "include" }],                                                      newonly => 0, untaggedonly => 0 },
        { filter => "", categories => [{ id => "SET_1589141306", mode => "include" }, { id => "SET_1589138380", mode => "include" }],        newonly => 0, untaggedonly => 0 },
    ]);
    is( scalar @$result, 1, 'Single-category clause should absorb multi-category clause' );
    is( scalar @{ $result->[0]{categories} }, 1, 'Surviving clause should have 1 category' );
}

note('testing reduce_clauses: chain absorption A OR (A,B) OR (A,B,C)...');
{
    my $result = norm_reduce([
        { filter => "artist:wada rco",                                                          categories => [], newonly => 0, untaggedonly => 0 },
        { filter => "artist:wada rco, character:ereshkigal",                                    categories => [], newonly => 0, untaggedonly => 0 },
        { filter => "artist:wada rco, character:ereshkigal, language:english",                  categories => [], newonly => 0, untaggedonly => 0 },
    ]);
    is( scalar @$result, 1, 'Chain absorption should reduce to 1 clause' );
    is( scalar @{ $result->[0]{tokens} }, 1, 'Surviving clause should have 1 token (least restrictive)' );
}

note('testing reduce_clauses: mixed absorption and irreducible...');
{
    my $result = norm_reduce([
        { filter => "artist:wada rco",                          categories => [], newonly => 0, untaggedonly => 0 },
        { filter => "artist:wada rco, character:ereshkigal",    categories => [], newonly => 0, untaggedonly => 0 },
        { filter => "artist:shirow masamune",                   categories => [], newonly => 0, untaggedonly => 0 },
    ]);
    is( scalar @$result, 2, 'Mixed absorption should keep A and C, remove A,B' );
}

note('testing reduce_clauses: untaggedonly flag absorption...');
{
    my $result = norm_reduce([
        { filter => "", categories => [], newonly => 0, untaggedonly => 0 },
        { filter => "", categories => [], newonly => 0, untaggedonly => 1 },
    ]);
    is( scalar @$result, 1, 'untaggedonly=0 should absorb untaggedonly=1' );
    is( $result->[0]{untaggedonly}, 0, 'Surviving clause should have untaggedonly=0' );
}

note('testing reduce_clauses: combined filter+flag absorption...');
{
    my $result = norm_reduce([
        { filter => "artist:wada rco",                          categories => [], newonly => 0, untaggedonly => 0 },
        { filter => "artist:wada rco, character:ereshkigal",    categories => [], newonly => 1, untaggedonly => 0 },
    ]);
    is( scalar @$result, 1, 'Less restrictive filter+flags should absorb more restrictive' );
    is( scalar @{ $result->[0]{tokens} }, 1, 'Surviving clause tokens' );
    is( $result->[0]{newonly}, 0, 'Surviving clause newonly' );
}

note('testing reduce_clauses: negated token asymmetry...');
{
    my $result = norm_reduce([
        { filter => "artist:wada rco",  categories => [], newonly => 0, untaggedonly => 0 },
        { filter => "-artist:wada rco", categories => [], newonly => 0, untaggedonly => 0 },
    ]);
    is( scalar @$result, 2, 'Positive and negated token should be irreducible' );
}

note('testing reduce_clauses: empty input...');
{
    my $result = LANraragi::Utils::Search::reduce_clauses([]);
    is( scalar @$result, 0, 'Empty input should return empty' );
}

done_testing();
