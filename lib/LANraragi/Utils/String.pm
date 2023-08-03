package LANraragi::Utils::String;

use strict;
use warnings;
use utf8;
use feature "switch";
no warnings 'experimental';
use feature qw(signatures);

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

1;
