use strict;
use warnings;

use Test::More;
use LANraragi::Controller::Api::Search;

{
    package RandomSearchRequest;
    sub new { bless { params => $_[1] }, $_[0] }
    sub openapi { shift }
    sub valid_input { shift }
    sub req { shift }
    sub param { $_[0]->{params}{$_[1]} }
    sub render {
        my ( $self, %args ) = @_;
        $self->{response} = $args{openapi};
    }
}

sub run_random_search {
    my ( $ids, $available, $count ) = @_;
    my @drawn;
    no warnings 'redefine';
    local *LANraragi::Model::Search::do_search = sub {
        return ( scalar(@$ids), scalar(@$ids), @$ids );
    };
    local *LANraragi::Controller::Api::Search::get_archive_json_multi = sub {
        push @drawn, @_;
        return map { { arcid => $_ } } grep { $available->{$_} } @_;
    };

    my $request = RandomSearchRequest->new( { count => $count } );
    LANraragi::Controller::Api::Search::get_random_archives($request);
    my %seen;
    ok( !grep( { $seen{$_}++ } @drawn ), 'candidates are never drawn twice' );
    is( $request->{response}{recordsTotal}, scalar @{ $request->{response}{data} },
        'reported count matches returned metadata' );
    return $request->{response}{data};
}

subtest 'refill results when indexed files are missing' => sub {
    my @ids = ( 'missing', 'one', 'two', 'three' );
    my %available = map { $_ => 1 } qw(one two three);
    # Exercise multiple random selections; every draw must yield three results.
    for my $seed ( 1 .. 20 ) {
        srand($seed);
        my $data = run_random_search( \@ids, \%available, 3 );
        is_deeply( [ sort map { $_->{arcid} } @$data ], [ qw(one three two) ],
            "all readable archives returned for seed $seed" );
    }
};

subtest 'exhaust candidates when fewer readable files remain' => sub {
    my $data = run_random_search( [ qw(missing one absent) ], { one => 1 }, 5 );
    is_deeply( $data, [ { arcid => 'one' } ], 'only readable result returned' );
};

subtest 'empty and entirely missing searches terminate' => sub {
    is_deeply( run_random_search( [], {}, 5 ), [], 'empty search' );
    is_deeply( run_random_search( [ qw(missing absent) ], {}, 5 ), [], 'all missing' );
};

subtest 'default count and sufficient readable results' => sub {
    my @ids = ( 1 .. 8 );
    my %available = map { $_ => 1 } @ids;
    is( scalar @{ run_random_search( \@ids, \%available, undef ) }, 5, 'default count' );
    is( scalar @{ run_random_search( \@ids, \%available, 2 ) }, 2, 'explicit count' );
};

done_testing();
