package LANraragi::Utils::I18N;

use strict;
use warnings;
use utf8;
use base 'Locale::Maketext';

use Locale::Maketext::Lexicon {
    en      => [ Gettext => "../../locales/template/en.po" ],
    zh      => [ Gettext => "../../locales/template/zh.po" ],
    "zh-cn" => [ Gettext => "../../locales/template/zh.po" ],
    fr      => [ Gettext => "../../locales/template/fr.po" ],
    ko      => [ Gettext => "../../locales/template/ko.po" ],
    "zh-tw" => [ Gettext => "../../locales/template/zh_Hant.po" ],
    vi      => [ Gettext => "../../locales/template/vi.po" ],
    _auto   => 0,
};

our @ISA = qw(Locale::Maketext);

1;
