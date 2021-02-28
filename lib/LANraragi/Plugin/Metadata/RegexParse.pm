package LANraragi::Plugin::Metadata::RegexParse;

use strict;
use warnings;

#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use Mojo::JSON qw(from_json);
use File::Basename;
use Scalar::Util qw(looks_like_number);

#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Database qw(redis_encode redis_decode);
use LANraragi::Utils::Logging qw(get_logger);
use LANraragi::Utils::Generic qw(remove_spaces);
use LANraragi::Utils::Archive qw(is_file_in_archive extract_file_from_archive);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name      => "Filename Parsing",
        type      => "metadata",
        namespace => "regexplugin",
        author    => "Difegue",
        version   => "1.0",
        description =>
          "Derive tags from the filename of the given archive. Follows the doujinshi naming standard (Release) [Artist] TITLE (Series) [Language].",
        icon =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IArs4c6QAAAL1JREFUOI1jZMABpNbH/sclx8DAwPAscDEjNnEMQUIGETIYhUOqYdgMhTPINQzdUEZqGIZsKBM1DEIGTOiuexqwCKdidDl0vtT62P9kuZCJEWuKYWBgYGBgRHbh04BFDNIb4jAUbbSrZTARUkURg6lD10OUC/0PNaMYgs1Skgwk1jCSDCQWoBg46dYmhite0+D8pwGLCMY6uotRDOy8toZBkI2HIhcO/pxCm8KBUkOxFl/kGoq3gCXFYFxVAACeoU/8xSNybwAAAABJRU5ErkJggg==",
        parameters => [ { type => "bool", desc => "Save archive title" } ]
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;    # Global info hash
    my ($savetitle) = @_;    # Plugin parameters

    my $logger = get_logger( "regexparse", "plugins" );
    my $file   = $lrr_info->{file_path};

    # lrr_info's file_path is taken straight from the filesystem, which might not be proper UTF-8.
    # Run a decode to make sure we can derive tags with the proper encoding.
    $file = redis_decode($file);

    # Get the filename from the file_path info field
    my ( $filename, $filepath, $suffix ) = fileparse( $file, qr/\.[^.]*/ );

    my ( $event, $artist, $title, $series, $language );
    $event = $artist = $title = $series = $language = "";

    #Replace underscores with spaces
    $filename =~ s/_/ /g;

    #Use the regex on our file, and pipe it to the regexsel sub.
    $filename =~ &get_regex;

    #Take variables from the regex selection
    if ( defined $2 ) { $event    = $2; }
    if ( defined $4 ) { $artist   = $4; }
    if ( defined $5 ) { $title    = $5; }
    if ( defined $7 ) { $series   = $7; }
    if ( defined $9 ) { $language = $9; }

    my @tags = ();

    if ( $event ne "" ) {
        push @tags, "event:$event";
    }

    if ( $artist ne "" ) {

        #Special case for circle/artist sets:
        #If the string contains parenthesis, what's inside those is the artist name
        #the rest is the circle.
        if ( $artist =~ /(.*) \((.*)\)/ ) {
            push @tags, "group:$1";
            push @tags, "artist:$2";
        } else {
            push @tags, "artist:$artist";
        }
    }

    if ( $series ne "" ) {
        push @tags, "series:$series";
    }

    # Don't push numbers as tags for language.
    unless ( $language eq "" || looks_like_number($language) ) {
        push @tags, "language:$language";
    }

    my $tagstring = join( ", ", @tags );

    $logger->info("Sending the following tags to LRR: $tagstring");

    if ($savetitle) {
        $logger->info("Parsed title is $title");
        return ( tags => $tagstring, title => $title );
    } else {
        return ( tags => $tagstring );
    }

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
