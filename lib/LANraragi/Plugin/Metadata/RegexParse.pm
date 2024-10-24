package LANraragi::Plugin::Metadata::RegexParse;

use strict;
use warnings;

#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use File::Basename;

use LANraragi::Model::Plugins;
use LANraragi::Utils::Database qw(redis_encode redis_decode);
use LANraragi::Utils::Logging  qw(get_plugin_logger);
use LANraragi::Utils::String   qw(trim);
use Scalar::Util               qw(looks_like_number);

my $PLUGIN_TAG_NS = 'parsed:';

# consider using Locale::Language / Locale::Script
my %VALID_LANGUAGES = (
    'chi'      => 'chinese',    # ?
    'chinese'  => 'chinese',
    'de'       => 'german',
    'deu'      => 'german',
    'en'       => 'english',
    'eng'      => 'english',
    'english'  => 'english',
    'es'       => 'spanish',
    'fr'       => 'french',
    'fra'      => 'french',
    'fre'      => 'french',
    'french'   => 'french',
    'ger'      => 'german',     # ?
    'german'   => 'german',
    'it'       => 'italian',
    'ita'      => 'italian',
    'italian'  => 'italian',
    'ja'       => 'japanese',
    'japanese' => 'japanese',
    'jpn'      => 'japanese',
    'ko'       => 'korean',
    'kor'      => 'korean',
    'korean'   => 'korean',
    'pl'       => 'polish',
    'pol'      => 'polish',
    'polish'   => 'polish',
    'ru'       => 'russian',
    'rus'      => 'russian',
    'russian'  => 'russian',
    'spa'      => 'spanish',
    'spanish'  => 'spanish',
    'zh'       => 'chinese',
    'zh'       => 'chinese',
    'zho'      => 'chinese',
    'textless' => 'textless'
);

my %COMMON_EXTRANEOUS_VALUES = (
    'uncensored' => 1,
    'decensored' => 1,
    'ongoing'    => 1,
    'pixiv'      => 1,
    'twitter'    => 1,
    'fanbox'     => 1,
    'cosplay'    => 1,
    'digital'    => 1
);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "Filename Parsing",
        type        => "metadata",
        namespace   => "regexplugin",
        author      => "Difegue",
        version     => "1.0.1",
        description =>
          "Derive tags from the filename of the given archive. <br>Follows the doujinshi naming standard (Release) [Artist] TITLE (Series) [Language].",
        icon =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IArs4c6QAAAL1JREFUOI1jZMABpNbH/sclx8DAwPAscDEjNnEMQUIGETIYhUOqYdgMhTPINQzdUEZqGIZsKBM1DEIGTOiuexqwCKdidDl0vtT62P9kuZCJEWuKYWBgYGBgRHbh04BFDNIb4jAUbbSrZTARUkURg6lD10OUC/0PNaMYgs1Skgwk1jCSDCQWoBg46dYmhite0+D8pwGLCMY6uotRDOy8toZBkI2HIhcO/pxCm8KBUkOxFl/kGoq3gCXFYFxVAACeoU/8xSNybwAAAABJRU5ErkJggg==",
        parameters => [
            { type => "bool", desc => "Capture trailing tags in curly brackets" },
            {   type => "bool",
                desc => "Keep everything you catch as tags in the namespace \"${PLUGIN_TAG_NS}\"<BR />"
                  . "(this should be used in conjunction with Tag Rules)"
            }
        ],
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {
    my ( undef, $lrr_info, $check_trailing_tags, $keep_all_captures ) = @_;

    # lrr_info's file_path is taken straight from the filesystem, which might not be proper UTF-8.
    # Run a decode to make sure we can derive tags with the proper encoding.
    my $file     = Mojo::File->new( redis_decode( $lrr_info->{'file_path'} ) );
    my $filename = $file->basename( $file->extname );

    my ( $tags, $title ) = parse_filename(
        $filename,
        {   'check_trailing_tags' => $check_trailing_tags,
            'keep_all_captures'   => $keep_all_captures
        }
    );

    my $logger = get_plugin_logger();
    $logger->info("Sending the following tags to LRR: $tags");
    $logger->info("Parsed title is $title");

    return ( tags => $tags, title => $title );
}

sub parse_filename {
    my ( $filename, $params ) = @_;

    my ( $event, $artist, $title, $series, $language, $trailing_tags );

    #Replace underscores with spaces
    $filename =~ s/_/ /g;

    #Use the regex on our file, and pipe it to the regexsel sub.
    $filename =~ &get_regex;

    #Take variables from the regex selection
    if ( defined $2 ) { $event    = $2; }
    if ( defined $4 ) { $artist   = $4; }
    if ( defined $5 ) { $title    = trim($5); }
    if ( defined $7 ) { $series   = $7; }
    if ( defined $9 ) { $language = $9; }

    # match trailing_tags (...{Tags}.ext)
    if ( $params->{'check_trailing_tags'} ) {
        $filename =~ /\{(?<ttags>.*?)}$/;
        $trailing_tags = $+{ttags};
    }

    my @tags;

    push @tags, parse_artist_value($artist)                              if ($artist);
    push @tags, "event:$event"                                           if ($event);
    push @tags, parse_language_value($language)                          if ($language);
    push @tags, parse_captured_value_for_namespace( $series, 'series:' ) if ($series);
    push @tags, parse_captured_value_for_namespace( $trailing_tags, '' ) if ($trailing_tags);

    if ( !$params->{'keep_all_captures'} ) {
        @tags = grep { !m/^\Q$PLUGIN_TAG_NS/ } @tags;
    }

    return ( join( ", ", sort @tags ), trim($title) );
}

sub parse_language_value {
    my ($language) = @_;
    my @tags;
    my @maybe_languages = map { trim( lc $_ ) } split( m/,/, $language );
    foreach my $item (@maybe_languages) {
        next if ( !$item );
        my $lang = $VALID_LANGUAGES{$item};
        if ($lang) {
            push @tags, "language:$lang";
        } else {
            push @tags, "${PLUGIN_TAG_NS}${item}";
        }
    }
    return @tags;
}

sub parse_artist_value {
    my ($artist) = @_;

    my @tags;

    #Special case for circle/artist sets:
    #If the string contains parenthesis, what's inside those is the artist name
    #the rest is the circle.
    if ( $artist =~ /(.*) \((.*)\)/ ) {
        push @tags, "group:$1";    # split group?
        $artist = $2;
    }
    push @tags, parse_captured_value_for_namespace( $artist, 'artist:' );

    return @tags;
}

sub parse_captured_value_for_namespace {
    my ( $capture, $namespace ) = @_;
    return map { _classify_item( trim($_), $namespace ) } split( m/,/, $capture );
}

sub _classify_item {
    my ( $item, $namespace ) = @_;

    # if the namespace is specified, we are able to exclude some common words,
    # otherwise we are dealing with simple tags
    if ( $namespace && $COMMON_EXTRANEOUS_VALUES{ lc $item } || looks_like_number($item) ) {
        return $PLUGIN_TAG_NS . lc $item;
    }
    return "${namespace}${item}";
}

#Regular Expression matching the E-Hentai standard: (Release) [Artist] TITLE (Series) [Language]
#Used in parsing.
#Stuff that's between unescaped ()s is put in a numbered variable: $1,$2,etc
#Parsing is only done the first time the file is found. The parsed info is then stored into Redis.
#Change this regex if you wish to use a different parsing for mass-addition of archives.

#()? indicates the field is optional.
#(\(([^([]+)\))? returns the content of (Release). Optional.
#(\[([^]]+)\])? returns the content of [Artist]. Optional.
#([^([]+) returns the title. Mandatory.
#(\(([^([)]+)\))? returns the content of (Series). Optional.
#(\[([^]]+)\])? returns the content of [Language]. Optional.
#\s* indicates zero or more whitespaces.
my $regex = qr/(\(([^([]+)\))?\s*(\[([^]]+)\])?\s*([^([]+)\s*(\(([^([)]+)\))?\s*(\[([^]]+)\])?/;
sub get_regex { return $regex }

1;
