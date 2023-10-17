package LANraragi::Utils::Tags;

use strict;
use warnings;
use utf8;
use feature "switch";
no warnings 'experimental';

use LANraragi::Utils::String qw(trim trim_CRLF);

# Functions related to the Tag system.
use Exporter 'import';
our @EXPORT_OK = qw( unflat_tagrules replace_CRLF restore_CRLF tags_rules_to_array rewrite_tags split_tags_to_array join_tags_to_string );

sub is_null_or_empty {
    return !length(shift);
}

sub replace_CRLF {
    my ($val) = @_;
    $val =~ s/\x{d}\x{a}/;/g if ($val);
    return $val;
}

sub restore_CRLF {
    my ($val) = @_;
    $val =~ s/;/\x{d}\x{a}/g if ($val);
    return $val;
}

sub unflat_tagrules {
    my ($flattened_rules) = @_;
    my @tagrules = ();
    while ( @{ $flattened_rules || [] } ) {
        push( @tagrules, [ splice( @$flattened_rules, 0, 3 ) ] );
    }
    return @tagrules;
}

sub split_tags_to_array {
    my ($tags_string) = @_;
    my @tags = split( ',', $tags_string );
    foreach my $tags (@tags) {
        $tags = trim($tags);
        $tags = trim_CRLF($tags);
    }
    return @tags;
}

sub join_tags_to_string {
    return join( ',', @_ );
}

sub tags_rules_to_array {
    my ($text_rules) = @_;
    my @rules;
    my @lines = split( '\n', $text_rules );
    foreach my $line (@lines) {
        my ( $match, $value ) = split( '->', $line );
        $match = trim($match);
        $value = trim($value);
        if ( !is_null_or_empty($match) ) {

            my $rule_type;
            if ( !$value && $match =~ m/^-.*:\*$/ ) {
                $rule_type = 'remove_ns';
                $match     = substr( $match, 1, length($match) - 3 );
            } elsif ( !$value && $match =~ m/^-/ ) {
                $rule_type = 'remove';
                $match     = substr( $match, 1 );
            } elsif ( !$value && $match =~ m/^~/ ) {
                $rule_type = 'strip_ns';
                $match     = substr( $match, 1 );
            } elsif ( $match =~ m/:\*$/ && $value =~ m/:\*$/ ) {
                $rule_type = 'replace_ns';
                $match     = substr( $match, 0, length($match) - 2 );
                $value     = substr( $value, 0, length($value) - 2 );
            } elsif ( !$value ) {
                $rule_type = 'remove';    # blacklist mode
            } else {
                $rule_type = 'replace';
            }

            push( @rules, [ $rule_type, lc $match, $value || '' ] ) if ($rule_type);
        }
    }
    return @rules;
}

sub rewrite_tags {
    my ( $tags, $rules ) = @_;
    return @$tags if ( !@$rules );

    my @parsed_tags;
    foreach my $tag (@$tags) {
        my $new_tag = apply_rules( $tag, $rules );
        push( @parsed_tags, $new_tag ) if ($new_tag);
    }
    return @parsed_tags;
}

sub apply_rules {
    my ( $tag, $rules ) = @_;

    foreach my $rule (@$rules) {
        my $match = $rule->[1];
        my $value = $rule->[2];
        given ( $rule->[0] ) {
            when ('remove')     { return if ( lc $tag eq $match ); }
            when ('remove_ns')  { return if ( $tag =~ m/^$match:/i ); }
            when ('replace_ns') { $tag =~ s/^\Q$match:/$value\:/i; }
            when ('strip_ns')   { $tag =~ s/^\Q$match://i; }
            default             { $tag = $value if ( lc $tag eq $match ); }
        }
    }

    return $tag;
}

1;
