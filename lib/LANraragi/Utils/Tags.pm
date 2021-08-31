package LANraragi::Utils::Tags;

use strict;
use warnings;
use utf8;
use feature "switch";
no warnings 'experimental';

use LANraragi::Utils::Generic qw(remove_spaces remove_newlines);

# Generic Utility Functions.
use Exporter 'import';
our @EXPORT_OK =
  qw( tags_rules_to_array rewrite_tags split_tags_to_array );

sub is_null_or_empty {
    return !length(shift);
}

sub split_tags_to_array {
    my ( $tags_string ) = @_;
    my @tags   = split( ',', $tags_string );
    foreach my $tags (@tags) {
        remove_spaces($tags);
        remove_newlines($tags);
    }
    return @tags;
}

sub tags_rules_to_array {
    my ( $text_rules ) = @_;
    my @rules;
    my @lines = split( '\n', $text_rules );
    foreach my $line ( @lines ) {
        my ( $match, $value ) = split( '->', $line );
        remove_spaces($match);
        remove_spaces($value);
        if (!is_null_or_empty($match)) {

            my $rule_type;
            if ( !$value && $match =~ m/^-.*:\*$/ ) {
                $rule_type = 'remove_ns';
                $match     = substr ($match, 1, length($match)-3);
            } elsif ( !$value && $match =~ m/^-/ ) {
                $rule_type = 'remove';
                $match     = substr ($match, 1);
            } elsif ( !$value && $match =~ m/^~/ ) {
                $rule_type = 'strip_ns';
                $match     = substr ($match, 1);
            } elsif ( $match =~ m/:\*$/ && $value =~ m/:\*$/ ) {
                $rule_type = 'replace_ns';
                $match     = substr ($match, 0, length($match)-2);
                $value     = substr ($value, 0, length($value)-2);
            } elsif ( !$value ) {
                $rule_type = 'remove'; # blacklist mode
            } else {
                $rule_type = 'replace'
            }

            push( @rules, [ $rule_type, $match, $value ] ) if ($rule_type);
        }
    }
    return @rules;
}

sub rewrite_tags {
    my ( $tags, $rules ) = @_;
    return @$tags if ( !@$rules );

    my @parsed_tags;
    foreach my $tag ( @$tags ) {
        my $new_tag = apply_rules($tag, $rules);
        push(@parsed_tags, $new_tag) if ($new_tag);
    }
    return @parsed_tags;
}

sub apply_rules {
    my ( $tag, $rules ) = @_;

    foreach my $rule ( @$rules ) {
        my $match = $rule->[1];
        my $value = $rule->[2];
        given($rule->[0]) {
            when ('remove')     { return if ( $tag eq $match ); }
            when ('remove_ns')  { return if ( $tag =~ m/^$match:/ ); }
            when ('replace_ns') { $tag =~ s/^\Q$match:/$value\:/; }
            when ('strip_ns')   { $tag =~ s/^\Q$match://; }
            default             { $tag = $value if ( $tag eq $match ); }
        }
    }

    return $tag;
}

1;
