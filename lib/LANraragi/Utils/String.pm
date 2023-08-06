package LANraragi::Utils::String;

use strict;
use warnings;
use utf8;
use feature "switch";
no warnings 'experimental';
use feature qw(signatures);

use String::Similarity;

# Remove "junk" from titles, turning something like "(c12) [poop (butt)] hardcore handholding [monogolian] [recensored]" into "hardcore handholding"
sub clean_title($title) {
    $title = trim($title);
    # Remove leading "(c12)"
    $title =~ s/^\([^)]*\)?\s?//g;
    # Remove leading "[poop (butt)]"
    $title =~ s/^\[[^]]*\]?\s?//g;

    # Remove trailing [mongolian] [recensored]"
    $title =~ s/\s?\[[^]]*\]$//g;
    $title =~ s/\s?\[[^]]*\]$//g;
    return $title;
}

sub trim($s) {
    $s =~ s/^\s+|\s+$//g;
    return $s
}

# Finds the index of the string in @values that is most similar to $tested_string. Returns undef if @values is empty.
# If multiple rows score "first place", the first one is returned
sub most_similar($tested_string, @values) {
    if (!@values) {
        return;
    }

    my $best_similarity = 0.0;
    my $best_index = undef;

    while (my ($index, $elem) = each @values) {
        my $similarity = similarity($tested_string, $elem);
        if (!defined($best_index) || $similarity > $best_similarity) {
            $best_similarity = $similarity;
            $best_index = $index;
        }
    }
    return $best_index;
}

1;
