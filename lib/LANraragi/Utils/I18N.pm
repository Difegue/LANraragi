package LANraragi::Utils::I18N;

use strict;
use warnings;
use utf8;
use base 'Locale::Maketext';

use Locale::Maketext::Lexicon {
    en    => [ Gettext => "../../locales/template/en.po" ],
    zh    => [ Gettext => "../../locales/template/zh.po" ],
    fr    => [ Gettext => "../../locales/template/fr.po" ],
    _auto => 0,
};

our @ISA = qw(Locale::Maketext);

1;
