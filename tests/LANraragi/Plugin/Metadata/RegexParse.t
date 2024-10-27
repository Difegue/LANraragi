use strict;
use warnings;

use Cwd qw( getcwd );

use Test::More;

my $cwd = getcwd();
require "$cwd/tests/mocks.pl";

use_ok('LANraragi::Plugin::Metadata::RegexParse');

my %PARAMS_EH_STANDARD = (
    'check_trailing_tags' => 0,
    'keep_all_captures'   => 0,
);
my %PARAMS_KEEP_ALL = (
    'check_trailing_tags' => 1,
    'keep_all_captures'   => 1,
);
my %SKIP_TRAILING_TAGS = ( 'check_trailing_tags' => 0 );

note("testing basic example");
{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::RegexParse::get_plugin_logger = sub { return get_logger_mock(); };

    my %response =
      LANraragi::Plugin::Metadata::RegexParse::get_tags( "",
        { file_path => "/poopoo/peepee/(NoNe) [Yanyanyo (Yanyo)] Reijo no Rei no... (Blue Archive) [English] [Digital].zip" },
        1, 0 );

    is( $response{title}, "Reijo no Rei no...",                                                              'title' );
    is( $response{tags},  "artist:Yanyo, event:NoNe, group:Yanyanyo, language:english, series:Blue Archive", 'tag list' );
}

my $filename = '(NoNe) [Yanyanyo (Yanyo)] Reijo no Rei no... (ongoing) [Decensored]';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) =
      LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, { %PARAMS_KEEP_ALL, ( 'keep_all_captures' => 0 ) } );
    is( $tags,  'artist:Yanyo, event:NoNe, group:Yanyanyo', 'tag list' );
    is( $title, 'Reijo no Rei no...',                       'title' );

    ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags, 'artist:Yanyo, event:NoNe, group:Yanyanyo, parsed:decensored, parsed:ongoing', 'full tag list' );
}

$filename = '(NoNe) [Yanyanyo (Yanyo)] Reijo no Rei no... (Blue Archive) [English] [Digital]';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags,  'artist:Yanyo, event:NoNe, group:Yanyanyo, language:english, series:Blue Archive', 'tag list' );
    is( $title, 'Reijo no Rei no...',                                                              'title' );
}

$filename = '(NoNe) [Yanyanyo (Yanyo)] Reijo no Rei no... (Blue Archive) [Decensored]';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags,  'artist:Yanyo, event:NoNe, group:Yanyanyo, parsed:decensored, series:Blue Archive', 'tag list' );
    is( $title, 'Reijo no Rei no...',                                                               'title' );
}

$filename = '(NoNe) [Yanyanyo (Yanyo)] Reijo no Rei no... (Blue Archive) [Eng] [Uncensored]';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags,  'artist:Yanyo, event:NoNe, group:Yanyanyo, language:english, series:Blue Archive', 'tag list' );
    is( $title, 'Reijo no Rei no...',                                                              'title' );
}

$filename = '(NoNe) [Yanyo] Reijo no Rei no... (Blue Archive) [En]';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags,  'artist:Yanyo, event:NoNe, language:english, series:Blue Archive', 'tag list' );
    is( $title, 'Reijo no Rei no...',                                              'title' );
}

$filename = '[Yanyo] Reijo no Rei no... [english]';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags,  'artist:Yanyo, language:english', 'tag list' );
    is( $title, 'Reijo no Rei no...',             'title' );
}

$filename = '[Yanyo] Reijo no Rei no... [english] {Team} Cap.01 (Digital) [Ongoing] [ ] () { } {big breasts, sole female}';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags,
        'artist:Yanyo, big breasts, language:english, parsed:Team, parsed:digital, parsed:ongoing, sole female',
        'tag list with all captures and the last curly brackets as simple tags'
    );

    ( $tags, $title ) =
      LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, { %PARAMS_KEEP_ALL, %SKIP_TRAILING_TAGS } );
    is( $tags,
        'artist:Yanyo, language:english, parsed:Team, parsed:big breasts, parsed:digital, parsed:ongoing, parsed:sole female',
        'tag list with all captures'
    );

    ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_EH_STANDARD );
    is( $tags, 'artist:Yanyo, language:english', 'tag list with only EH standard tags' );
}

$filename = '[黒ねずみいぬ, 市川和秀, 猪去バンセ, カサイこーめい, きしぐま, ＳＵＶ, 重丸しげる, ちんぱん☆Mk-Ⅱ, ばんじゃく, 英, ふぁい, 水樹 凱, やさごり] So many artists!';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags,
        'artist:きしぐま, artist:ちんぱん☆Mk-Ⅱ, artist:ばんじゃく, artist:ふぁい, artist:やさごり, artist:カサイこーめい, artist:市川和秀, artist:水樹 凱, artist:猪去バンセ, artist:英, artist:重丸しげる, artist:黒ねずみいぬ, artist:ＳＵＶ',
        'tag list'
    );
    is( $title, 'So many artists!', 'title' );
}

$filename = '(C24) [Atomic Diver Henshuubu (Tajima Shinobu, Yoko)] ART DANGER II (Various) [En,Textless]';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags,
        'artist:Tajima Shinobu, artist:Yoko, event:C24, group:Atomic Diver Henshuubu, language:english, language:textless, series:Various',
        'tag list'
    );
    is( $title, 'ART DANGER II', 'title' );
}

$filename = '[Crimson Comics (Crimson)] J-Girl. Ecstasy (Black Cat, D.Gray-man, MX0, To Love-Ru) [English]';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags,
        'artist:Crimson, group:Crimson Comics, language:english, series:Black Cat, series:D.Gray-man, series:MX0, series:To Love-Ru',
        'tag list'
    );
    is( $title, 'J-Girl. Ecstasy', 'title' );
}

$filename = '[Pixiv] 佐々(66526024) 2024.10.19';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags,  'parsed:66526024, parsed:pixiv', 'tag list' );
    is( $title, '佐々',                            'not a title, but meh...' );
}

done_testing();