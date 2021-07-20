package LANraragi::Plugin::Metadata::Fakku;

use strict;
use warnings;

#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use URI::Escape;
use Mojo::JSON qw(decode_json);
use Mojo::UserAgent;
use Mojo::DOM;

#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_logger);
use LANraragi::Utils::Generic qw(remove_spaces remove_newlines);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "FAKKU",
        type        => "metadata",
        namespace   => "jewcob",
        author      => "Difegue",
        version     => "0.5.1",
        description => "Searches FAKKU for tags matching your archive.",
        icon =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAAFiUAABYlAUlSJPAAAACZSURBVDhPlY+xDYQwDEWvZgRGYA22Y4frqJDSZhFugiuuo4cqPGT0iTjAYL3C+fGzktc3hEcsQvJq6HtjE2Jdv4viH4a4pWnL8q4A6g+ET9P8YhS2/kqwIZXWnwqChDxPfCFfD76wOzJ2IOR/0DSwnuRKYAKUW3gq2OsJTYM0jr7QVRVwlabJEaw3ARYBcmFXeomxphIeEMIMmh3lOLQR+QQAAAAASUVORK5CYII=",
        parameters  => [ { type => "bool", desc => "Save archive title" } ],
        oneshot_arg => "FAKKU Gallery URL (Will attach tags matching this exact gallery to your archive)"
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;    # Global info hash
    my ($savetitle) = @_;    # Plugin parameters

    my $logger = get_local_logger();

    # Work your magic here - You can create subs below to organize the code better
    my $jewcobURL = "";

    # If the user specified a oneshot argument, use it as-is.
    # We could stand to pre-check it to see if it really is a FAKKU URL but meh
    if ( $lrr_info->{oneshot_param} ) {
        $jewcobURL = $lrr_info->{oneshot_param};
    } else {

        # Search for a FAKKU URL if the user didn't specify one
        $jewcobURL = search_for_fakku_url( $lrr_info->{archive_title} );
    }

    # Do we have a URL to grab data from?
    if ( $jewcobURL ne "" ) {
        $logger->debug("Detected FAKKU URL: $jewcobURL");
    } else {
        $logger->info("No matching FAKKU Gallery Found!");
        return ( error => "No matching FAKKU Gallery Found!" );
    }

    my ( $newtags, $newtitle );
    eval { ( $newtags, $newtitle ) = get_tags_from_fakku($jewcobURL); };

    if ($@) {
        return ( error => $@ );
    }

    $logger->info("Sending the following tags to LRR: $newtags");

    #Return a hash containing the new metadata - it will be integrated in LRR.
    if ( $savetitle && $newtags ne "" ) { return ( tags => $newtags, title => $newtitle ); }
    else                                { return ( tags => $newtags ); }
}

sub get_local_logger {
    my %pi = plugin_info();
    return get_logger( $pi{name}, "plugins" );
}

######
## FAKKU-Specific Methods
######

my $fakku_host = "https://www.fakku.net";

# search_for_fakku_url(title)
# Uses the website's search to find a gallery and returns its gallery ID.
sub search_for_fakku_url {

    my ($title) = @_;

    my $dom = get_search_result_dom_by_title($title);

    # Get the first gallery url of the search results
    my $path = ( $dom->at('.content-title') ) ? $dom->at('.content-title')->attr('href') : "";

    if ( $path ne "" ) {
        return $fakku_host . $path;
    } else {
        return "";
    }

}

sub get_search_result_dom_by_title {

    my ( $title ) = @_;

    my $logger = get_local_logger();

    #Strip away hyphens and apostrophes as they can break search
    $title =~ s/-|'/ /g;

    my $ua = Mojo::UserAgent->new;

    # Visit the base host once to set cloudflare cookies and jank
    $ua->max_redirects(5)->get($fakku_host);

    # Use the regular search page.
    # The autosuggest API (fakku.net/suggest/blahblah) yields better results but is blocked unless you make it through cloudflare or are logged in?
    my $URL = "$fakku_host/search/" . uri_escape_utf8($title);

    $logger->debug("Using URL $URL to search on FAKKU.");

    my $res = $ua->max_redirects(5)->get($URL)->result;
    $logger->debug( "Got this HTML: " . $res->body );

    return $res->dom;
}

sub get_dom_from_fakku {

    my ( $url ) = @_;

    my $logger = get_local_logger();

    my $ua  = Mojo::UserAgent->new;
    my $res = $ua->max_redirects(5)->get($url)->result;

    my $html = $res->body;
    $logger->debug( "Got this HTML: " . $html );
    if ( $html =~ /.*error code: (\d*).*/gim ) {
        $logger->debug("Blocked by Cloudflare, aborting for now. (Error code $1)");
        die "The plugin has been blocked by Cloudflare. (Error code $1) Try opening FAKKU in your browser to bypass this.";
    }

    return $res->dom;
}

# get_tags_from_fakku(fURL)
# Parses a FAKKU URL for tags.
sub get_tags_from_fakku {

    my ( $url ) = @_;

    my $logger = get_local_logger();

    my $dom = get_dom_from_fakku($url);

    my @tags  = ();
    my $title =
      ( $dom->at('.content-name') )
      ? $dom->at('.content-name')->at('h1')->text
      : "";
    $logger->debug("Parsed title: $title");

    # We can grab some namespaced tags from the first few rows.
    my @namespaces = $dom->find('.row-left')->each;

    foreach my $div (@namespaces) {

        my $namespace = $div->text;
        $logger->debug("Parsed row: $namespace");

        unless ( $namespace eq "Tags"
            || $namespace eq "Pages"
            || $namespace eq "Description"
            || $namespace eq "Direction"
            || $namespace eq "Favorites" ) {

            my $content = $div->next->at('a')->text;
            remove_spaces($content);
            remove_newlines($content);
            $logger->debug("Matching tag: $content");

            push( @tags, "$namespace:$content" );
        }
    }

    # Miscellaneous tags are all the <a> links in the div with the "tags" class
    my @divs = $dom->at('.tags')->child_nodes->each;

    foreach my $div (@divs) {
        my $tag = $div->text;

        remove_spaces($tag);
        remove_newlines($tag);
        unless ( $tag eq "+" || $tag eq "" ) {
            push( @tags, $tag );
        }
    }

    return ( join( ', ', @tags ), $title );

}

1;
