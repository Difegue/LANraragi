package LANraragi::Utils::Search;

use strict;
use warnings;
use utf8;
no warnings 'experimental';
use feature qw(signatures);

use Exporter 'import';
our @EXPORT_OK = qw(reduce_clauses normalize_clauses compute_search_filter resolve_search_clause);

use LANraragi::Utils::String  qw(trim);
use LANraragi::Utils::Generic qw(intersect_arrays);
use LANraragi::Utils::Logging qw(get_logger);
use LANraragi::Model::Category;

# compute_search_filter (filter)
# Transform the search engine syntax into a list of tokens.
# A token object contains the tag, whether it must be an exact match, and whether it must be absent.
sub compute_search_filter ($filter) {

    my $logger = get_logger( "Search Core", "lanraragi" );
    my @tokens = ();
    if ( !$filter ) { $filter = ""; }

    # Special characters:
    # "" for exact search (or $, but is that one really useful now?)
    # ?/_ for any character
    # * % for multiple characters
    # - to exclude the next tag

    $b = reverse($filter);
    while ( $b ne "" ) {

        my $char  = chop $b;
        my $isneg = 0;

        # Skip spaces
        while ( $char eq " " && $b ne "" ) {
            $char = chop $b;
        }

        if ( $char eq "-" ) {
            $isneg = 1;
            $char  = chop $b;
        }

        # Get characters until the next comma, or the next " if the following char is "
        my $delimiter = ',';
        if ( $char eq '"' ) {
            $delimiter = '"';
            $char      = chop $b;
        }

        my $tag     = "";
        my $isexact = 0;
      TAGBUILD: while (1) {
            if ( $char eq $delimiter || $char eq "" ) { last TAGBUILD; }
            $tag  = $tag . $char;    # Add characters in reverse order since we used reverse earlier on
            $char = chop $b;
        }

        #If last char is $ or delimiter was ", enable isexact
        if ( $delimiter eq '"' ) {
            $isexact = 1;

            # Quotes then $ is an accepted syntax, even though it does nothing
            $char = chop $b;
            unless ( $char eq "\$" ) {
                $b = $b . $char;
            }
        } else {
            $char = chop $tag;
            if ( $char eq "\$" ) {
                $isexact = 1;
            } else {
                $tag = $tag . $char;
            }
        }

        # Escape already present regex characters
        $logger->debug("Pre-escaped tag: $tag");

        $tag = trim($tag);

        # Escape characters according to redis zscan rules
        $tag =~ s/([\[\]\^\\])/\\$1/g;

        # Replace placeholders with glob-style patterns,
        # ? or _ => ?
        $tag =~ s/\_/\?/g;

        # * or % => *
        $tag =~ s/\%/\*/g;

        if ( $tag ne "" ) {    # Blank tokens shouldn't be added as theyll slow down search
            push @tokens,
              { tag     => lc($tag),
                isneg   => $isneg,
                isexact => $isexact
              };
        }

    }
    return @tokens;
}

# resolve_search_clause (tokens, categories, base_candidates, newonly, untaggedonly, hidecompleted)
# Resolves a search clause into a clause hashref for do_composite_search_inner.
# Processes category entries: dynamic categories add filter tokens, static categories intersect/subtract candidates.
#
# Returns: hashref { candidate_ids, tokens, newonly, untaggedonly, hidecompleted }
sub resolve_search_clause ( $tokens, $categories, $base_candidates, $newonly, $untaggedonly, $hidecompleted ) {

    my @candidates = @$base_candidates;
    my @tokens     = @$tokens;

    foreach my $cat_entry (@$categories) {
        my $cat_id = $cat_entry->{id};
        my $mode   = $cat_entry->{mode} // "include";

        my %category = LANraragi::Model::Category::get_category($cat_id);
        next unless %category;

        if ( $category{search} ne "" ) {

            # Dynamic category: add search predicate tokens
            my @cat_tokens = compute_search_filter( $category{search} );
            if ( $mode eq "exclude" ) {
                foreach my $token (@cat_tokens) {
                    $token->{isneg} = $token->{isneg} ? 0 : 1;
                }
            }
            push @tokens, @cat_tokens;
        } else {

            # Static category: intersect or subtract candidate set
            my $isneg = ( $mode eq "exclude" ) ? 1 : 0;
            @candidates = intersect_arrays( $category{archives}, \@candidates, $isneg );
            last if scalar @candidates == 0;
        }
    }

    return {
        candidate_ids => \@candidates,
        tokens        => \@tokens,
        newonly       => $newonly,
        untaggedonly  => $untaggedonly,
        hidecompleted => $hidecompleted,
    };
}

# Parse each clause descriptor's filter and produce a normalized form for reduction and resolution.
sub normalize_clauses ($clause_descriptors) {

    my @normed;
    for my $desc (@$clause_descriptors) {
        my @tokens = compute_search_filter( $desc->{filter} );
        my @canon_tokens = sort map { join( "|", $_->{tag}, $_->{isneg}, $_->{isexact} ) } @tokens;
        my $categories   = $desc->{categories} // [];
        my @canon_cats   = sort map { $_->{id} . ":" . $_->{mode} } @$categories;

        push @normed, {
            tokens         => \@canon_tokens,
            raw_tokens     => \@tokens,
            categories     => \@canon_cats,
            raw_categories => $categories,
            newonly        => $desc->{newonly},
            untaggedonly   => $desc->{untaggedonly},
            hidecompleted  => $desc->{hidecompleted},
        };
    }

    return \@normed;
}

# Reduce redundant normalized clauses via DNF absorption.
sub reduce_clauses ($normed) {

    return $normed if scalar @$normed <= 1;

    # Pairwise absorption: if A subsumes B, remove B.
    # A subsumes B when A's predicates are a subset of B's (A is less restrictive).
    # Identical clauses mutually subsume, so dedup is handled implicitly.
    my @keep = (1) x scalar @$normed;
    for my $i ( 0 .. $#$normed ) {
        next unless $keep[$i];
        for my $j ( 0 .. $#$normed ) {
            next if $i == $j;
            next unless $keep[$j];

            my ( $a, $b ) = ( $normed->[$i], $normed->[$j] );

            # Flag subsumption: 0 (off) subsumes 1 (on) and -1 (exclude).
            # Non-zero unequal values do not subsume (different filter semantics).
            my $subsumes = 1;
            for my $flag (qw(newonly untaggedonly hidecompleted)) {
                unless ( $a->{$flag} == 0 || $a->{$flag} == $b->{$flag} ) {
                    $subsumes = 0;
                    last;
                }
            }

            # A's tokens must be a subset of B's tokens
            if ($subsumes) {
                my %b_tokens = map { $_ => 1 } @{ $b->{tokens} };
                for my $t ( @{ $a->{tokens} } ) {
                    unless ( $b_tokens{$t} ) {
                        $subsumes = 0;
                        last;
                    }
                }
            }

            # A's categories must be a subset of B's categories
            if ($subsumes) {
                my %b_cats = map { $_ => 1 } @{ $b->{categories} };
                for my $c ( @{ $a->{categories} } ) {
                    unless ( $b_cats{$c} ) {
                        $subsumes = 0;
                        last;
                    }
                }
            }

            $keep[$j] = 0 if $subsumes;
        }
    }

    my @result;
    for my $i ( 0 .. $#$normed ) {
        push @result, $normed->[$i] if $keep[$i];
    }

    return \@result;
}

1;
