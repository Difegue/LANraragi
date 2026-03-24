package LANraragi::Plugin::Metadata::RegexParse;

use strict;
use warnings;

#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use File::Basename;

use LANraragi::Model::Plugins;
use LANraragi::Utils::Redis    qw(redis_encode redis_decode);
use LANraragi::Utils::Logging  qw(get_plugin_logger);
use LANraragi::Utils::String   qw(trim);
use Scalar::Util               qw(looks_like_number);

my $PLUGIN_TAG_NS = 'parsed:';

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
        version     => "1.2",
        description => "Derive tags from the filename of the given archive.<br><br>"
        . "By default it follows the doujinshi naming standard \"(Event) [Artist] TITLE (Series) [Language]\".<br><br>"
        . "The default regex is:<br>"
        .'<code>(\((?&lt;event&gt;[^([]+)\))?\s*(\[(?&lt;artist&gt;[^]]+)\])?\s*(?&lt;title&gt;[^([]+)\s*(\((?&lt;series&gt;[^([)]+)\))?\s*(\[(?&lt;language&gt;[^]]+)\])?(?&lt;tail&gt;.*)?</code><br><br>'
        .'<code>()?</code> indicates the field is optional<br>'
        .'<code>(\((?&lt;event&gt;[^([]+)\))?</code> returns the content of (Event). Optional.<br>'
        .'<code>(\[(?&lt;artist&gt;[^]]+)\])?</code> returns the content of [Artist]. Optional.<br>'
        .'<code>(?&lt;title&gt;[^([]+)</code> returns the title. Mandatory.<br>'
        .'<code>(\((?&lt;series&gt;[^([)]+)\))?</code> returns the content of (Series). Optional.<br>'
        .'<code>(\[(?&lt;language&gt;[^]]+)\])?</code> returns the content of [Language]. Optional.<br>'
        .'<code>(?&lt;tail&gt;.*)?</code> returns everything that is out of E-Hentai standard for further processing. Optional.<br>'
        .'<code>\s*</code> indicates zero or more whitespaces.<br><br>'
          . "You can provide a custom regex using named capture groups. The group name determines the tag namespace:<br>"
          . "&bull; <code>(?&lt;artist&gt;...)</code> &rarr; <code>artist:</code> (also extracts <code>group:</code> from \"Circle (Artist)\" format)<br>"
          . "&bull; <code>(?&lt;series&gt;...)</code> &rarr; <code>series:</code><br>"
          . "&bull; <code>(?&lt;tag&gt;...)</code> &rarr; simple tag (no namespace)<br>"
          . "&bull; <code>(?&lt;anyname&gt;...)</code> &rarr; <code>anyname:</code><br>"
          . "Use numbered suffixes for multiple groups of the same type: <code>(?&lt;artist2&gt;...)</code>, <code>(?&lt;tag3&gt;...)</code>, etc.<br>"
          . "Special groups: <code>title</code> sets the archive title, <code>tail</code> is used for trailing tag processing.<br><br>"
          . "By activating the plugin settings below, you can extend the capture to the content of each bracket in"
          . " the filename, even if it does not belong to the standard naming format.<br>"
          . "Non-standard tags will be made available to you associated with the \"<i>${PLUGIN_TAG_NS}</i>\" namespace so"
          . " you can manage them as you please by creating your own set of Tag Rules.<br>"
          . "My only suggestion is that you should place the rule \"<i>-${PLUGIN_TAG_NS}*</i>\" as your last rule to cleanup all the unnecessary elements.",
        icon =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IArs4c6QAAAL1JREFUOI1jZMABpNbH/sclx8DAwPAscDEjNnEMQUIGETIYhUOqYdgMhTPINQzdUEZqGIZsKBM1DEIGTOiuexqwCKdidDl0vtT62P9kuZCJEWuKYWBgYGBgRHbh04BFDNIb4jAUbbSrZTARUkURg6lD10OUC/0PNaMYgs1Skgwk1jCSDCQWoBg46dYmhite0+D8pwGLCMY6uotRDOy8toZBkI2HIhcO/pxCm8KBUkOxFl/kGoq3gCXFYFxVAACeoU/8xSNybwAAAABJRU5ErkJggg==",
        parameters => [
            {   type => "bool",
                desc =>
                  "If the filename ends with a pair of curly braces, return the contents inside them as a list of simple tags, without the \"${PLUGIN_TAG_NS}\" namespace"
            },
            {   type => "bool",
                desc =>
                  "Capture everything you find between a pair of parentheses and make it available under the \"${PLUGIN_TAG_NS}\" namespace<BR />"
                  . "(use this in conjunction with Tag Rules)"
            },
            {   type => "string",
                desc =>
                    "Regex to use for parsing",
                default_value => '(\((?<event>[^([]+)\))?\s*(\[(?<artist>[^]]+)\])?\s*(?<title>[^([]+)\s*(\((?<series>[^([)]+)\))?\s*(\[(?<language>[^]]+)\])?(?<tail>.*)?'
            }
        ],
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {
    my ( undef, $lrr_info, $check_trailing_tags, $keep_all_captures, $regex_string ) = @_;

    # lrr_info's file_path is taken straight from the filesystem, which might not be proper UTF-8.
    # Run a decode to make sure we can derive tags with the proper encoding.
    my $file     = Mojo::File->new( redis_decode( $lrr_info->{'file_path'} ) );
    my $filename = $file->basename( '.' . $file->extname );

    my ( $tags, $title ) = parse_filename(
        $filename,
        {   'check_trailing_tags' => $check_trailing_tags,
                'keep_all_captures'   => $keep_all_captures,
                'regex_string' => $regex_string
        }
        );
    my $logger = get_plugin_logger();
    if ($tags eq "" && $title eq "") {
        $logger->info("Regex match failed, no changes");
        return ( tags => "" );
    }
    

    $logger->info("Sending the following tags to LRR: $tags");
    $logger->info("Parsed title is $title");

    return ( tags => $tags, title => $title );
}

sub parse_filename {
    my ( $filename, $params ) = @_;

    my ( $title, $trailing_tags, $other_captures );

    #Replace underscores with spaces
    $filename =~ s/_/ /g;

    my $regex = qr/$params->{'regex_string'}/;
    if (!($filename =~ $regex)) {
        return ("", "");
    }

    # Capture all named groups immediately (before any subsequent regex operations overwrite %+)
    my %captures = %+;

    # Extract special cases
    $title = trim($captures{'title'}) if defined $captures{'title'};
    my $tail = defined $captures{'tail'} ? trim($captures{'tail'}) : '';

    if ($tail) {

        # match trailing_tags (...{Tags}.ext)
        if ( $params->{'check_trailing_tags'} ) {
            $tail =~ /(?<head>.*)(\{(?<ttags>[^\}]*)\})$/;
            $trailing_tags = $+{'ttags'};
            $tail          = $+{'head'} if ($trailing_tags);
        }

        # match any remaining parenthesis
        if ( $tail && $params->{'keep_all_captures'} ) {
            my @items = ( $tail =~ /\(([^\)]+)\)|\{([^}]+)\}|\[([^\]]+)\]/g );
            $other_captures = join( ',', grep { trim($_) } @items );
        }
    }

    my @tags;

    # Process all named capture groups dynamically
    for my $name (keys %captures) {
        next if $name eq 'title' || $name eq 'tail';

        my $value = trim($captures{$name});
        next unless $value;

        # Strip trailing digits to get the namespace (e.g., artist2 -> artist)
        my $namespace = $name =~ s/\d+$//r;

        if ($namespace eq 'tag') {
            # Simple tags - no namespace, skip _classify_item
            push @tags, map { trim($_) } split(/,/, $value);
        } elsif ($namespace eq 'artist') {
            push @tags, parse_artist_value($value);
        } elsif ($namespace eq 'event') {
            # Direct assignment - no filtering
            push @tags, "event:$value";
        } else {
            push @tags, parse_captured_value_for_namespace($value, "$namespace:");
        }
    }

    push @tags, parse_captured_value_for_namespace( $other_captures, $PLUGIN_TAG_NS ) if ($other_captures);
    push @tags, parse_captured_value_for_namespace( $trailing_tags, '' )              if ($trailing_tags);

    if ( !$params->{'keep_all_captures'} ) {
        @tags = grep { !m/^\Q$PLUGIN_TAG_NS/ } @tags;
    }

    return ( join( ", ", sort @tags ), $title // '' );
}

sub parse_artist_value {
    my ($artist) = @_;

    my @tags;

    #Special case for circle/artist sets:
    #If the string contains parenthesis, what's inside those is the artist name
    #the rest is the circle.
    if ( $artist =~ /(.*) \((.*)\)/ ) {
        push @tags, "group:" . trim($1);
        $artist = trim($2);
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
        return $PLUGIN_TAG_NS . $item;
    }
    return "${namespace}${item}";
}

1;
