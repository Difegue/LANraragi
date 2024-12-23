package LANraragi::Utils::I18N;

use strict;
use warnings;
use utf8;
use base 'Locale::Maketext';

use Locale::Maketext::Lexicon {
    en => [ Gettext => "lib/LANraragi/I18N/en.po"],
    zh => [ Gettext => "lib/LANraragi/I18N/zh.po"],
    _auto => 0,
};

our @ISA = qw(Locale::Maketext);

1;
