use strict;
use warnings;

use Cwd qw( getcwd );

use Test::More;

my $cwd = getcwd();
require "$cwd/tests/mocks.pl";
setup_redis_mock();

use_ok('LANraragi::Plugin::Metadata::RegexParse');

# Extract default regex from plugin_info for testing the default behavior
my %plugin_info = LANraragi::Plugin::Metadata::RegexParse::plugin_info();
my $DEFAULT_REGEX = $plugin_info{parameters}[2]{default_value};

my %PARAMS_EH_STANDARD = (
    'check_trailing_tags' => 0,
    'keep_all_captures'   => 0,
    'regex_string'        => $DEFAULT_REGEX,
);
my %PARAMS_KEEP_ALL = (
    'check_trailing_tags' => 1,
    'keep_all_captures'   => 1,
    'regex_string'        => $DEFAULT_REGEX,
);
my %SKIP_TRAILING_TAGS = ( 'check_trailing_tags' => 0 );

note("testing basic example");
{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::RegexParse::get_plugin_logger = sub { return get_logger_mock(); };

    my %response =
      LANraragi::Plugin::Metadata::RegexParse::get_tags( "",
        { file_path => "/poopoo/peepee/(NoNe) [Yanyanyo (Yanyo)] Reijo no Rei no... (Blue Archive) [English] [Digital].zip" },
        1, 1, $DEFAULT_REGEX );

    is( $response{title}, "Reijo no Rei no...", 'title' );
    is( $response{tags}, "artist:Yanyo, event:NoNe, group:Yanyanyo, language:English, parsed:Digital, series:Blue Archive",
        'tag list' );
}

my $filename = '(NoNe) [Yanyanyo (Yanyo)] Reijo no Rei no... (ongoing) [Decensored]';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) =
      LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, { %PARAMS_KEEP_ALL, ( 'keep_all_captures' => 0 ) } );
    is( $tags,  'artist:Yanyo, event:NoNe, group:Yanyanyo', 'tag list' );
    is( $title, 'Reijo no Rei no...',                       'title' );

    ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags, 'artist:Yanyo, event:NoNe, group:Yanyanyo, parsed:Decensored, parsed:ongoing', 'full tag list' );
}

$filename = '(NoNe) [Yanyanyo (Yanyo)] Reijo no Rei no... (Blue Archive) [English] [Digital]';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags,  'artist:Yanyo, event:NoNe, group:Yanyanyo, language:English, parsed:Digital, series:Blue Archive', 'tag list' );
    is( $title, 'Reijo no Rei no...',                                                                              'title' );
}

$filename = '(NoNe) [Yanyanyo (Yanyo)] Reijo no Rei no... (Blue Archive) [Decensored]';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags,  'artist:Yanyo, event:NoNe, group:Yanyanyo, parsed:Decensored, series:Blue Archive', 'tag list' );
    is( $title, 'Reijo no Rei no...',                                                               'title' );
}

$filename = '(NoNe) [Yanyanyo (Yanyo)] Reijo no Rei no... (Blue Archive) [Eng] [Uncensored]';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags,  'artist:Yanyo, event:NoNe, group:Yanyanyo, language:Eng, parsed:Uncensored, series:Blue Archive', 'tag list' );
    is( $title, 'Reijo no Rei no...',                                                                             'title' );
}

$filename = '(NoNe) [Yanyo] Reijo no Rei no... (Blue Archive) [En]';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags,  'artist:Yanyo, event:NoNe, language:En, series:Blue Archive', 'tag list' );
    is( $title, 'Reijo no Rei no...',                                         'title' );
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
        'artist:Yanyo, big breasts, language:english, parsed:Digital, parsed:Ongoing, parsed:Team, sole female',
        'tag list with all captures and the last curly brackets as simple tags'
    );

    ( $tags, $title ) =
      LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, { %PARAMS_KEEP_ALL, %SKIP_TRAILING_TAGS } );
    is( $tags,
        'artist:Yanyo, language:english, parsed:Digital, parsed:Ongoing, parsed:Team, parsed:big breasts, parsed:sole female',
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
        'artist:Tajima Shinobu, artist:Yoko, event:C24, group:Atomic Diver Henshuubu, language:En, language:Textless, series:Various',
        'tag list'
    );
    is( $title, 'ART DANGER II', 'title' );
}

$filename = '[Crimson Comics (Crimson)] J-Girl. Ecstasy (Black Cat, D.Gray-man, MX0, To Love-Ru) [English]';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags,
        'artist:Crimson, group:Crimson Comics, language:English, series:Black Cat, series:D.Gray-man, series:MX0, series:To Love-Ru',
        'tag list'
    );
    is( $title, 'J-Girl. Ecstasy', 'title' );
}

$filename = '[Pixiv] 佐々(66526024) 2024.10.19';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags,  'parsed:66526024, parsed:Pixiv', 'tag list' );
    is( $title, '佐々',                            'not a title, but meh...' );
}

# === UNDERSCORE REPLACEMENT TESTS ===

$filename = '[Some_Artist]_Title_With_Underscores_(Some_Series)_[English]';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags,  'artist:Some Artist, language:English, series:Some Series', 'underscores converted to spaces in all fields' );
    is( $title, 'Title With Underscores', 'underscores converted in title' );
}

$filename = '(C_99)_[Circle_Name_(Artist_Name)]_My_Title_(Series_Name)_[Eng]';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags,  'artist:Artist Name, event:C 99, group:Circle Name, language:Eng, series:Series Name', 'underscores in event and group/artist' );
    is( $title, 'My Title', 'title parsed correctly' );
}

# === WHITESPACE TRIMMING TESTS ===

$filename = '[  Artist  ]   Padded Title   (  Series  ) [  English  ]';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags,  'artist:Artist, language:English, series:Series', 'whitespace trimmed from captured values' );
    is( $title, 'Padded Title', 'whitespace trimmed from title' );
}

# NOTE: Previously, event and group were not trimmed. Now all named capture groups
# are trimmed via trim($captures{$name}), and group is trimmed in parse_artist_value().
# Old expected: 'artist:Inner Artist, event:  Event  , group:  Group , series:Series'
$filename = '(  Event  ) [  Group  (  Inner Artist  )  ] Title (Series)';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags,  'artist:Inner Artist, event:Event, group:Group, series:Series', 'whitespace trimmed from all fields including event and group' );
    is( $title, 'Title', 'title parsed correctly' );
}

# === NEGATIVE / EDGE CASE TESTS ===

note("testing edge cases");
{
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( '', \%PARAMS_KEEP_ALL );
    is( $tags,  '', 'empty filename returns empty tags' );
    is( $title, '', 'empty filename returns empty title' );
}

$filename = 'Just A Plain Title';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags,  '', 'plain title returns no tags' );
    is( $title, 'Just A Plain Title', 'plain title returned as-is' );
}

# NOTE: malformed input - no title between brackets causes Artist] to leak into title
$filename = '[Artist](Series)[English]';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags,  'language:English, series:Series', 'tags extracted from malformed input' );
    is( $title, 'Artist]', 'malformed input causes bracket leak into title' );
}

$filename = '[Artist]   [English]';
note("parsing filename > $filename ...");
{
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::RegexParse::parse_filename( $filename, \%PARAMS_KEEP_ALL );
    is( $tags,  'artist:Artist, language:English', 'artist and language extracted' );
    is( $title, '', 'empty title when no title content between brackets' );
}

done_testing();
