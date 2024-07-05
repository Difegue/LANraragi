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
use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::String  qw(trim trim_CRLF);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "FAKKU",
        type        => "metadata",
        namespace   => "fakkumetadata",
        login_from  => "fakkulogin",
        author      => "Difegue, Nodja, Nixis198",
        version     => "0.97",
        description =>
          "Searches FAKKU for tags matching your archive. If you have an account, don't forget to enter the matching cookie in the login plugin to be able to access controversial content. <br/><br/>  
           <i class='fa fa-exclamation-circle'></i> <b>This plugin can and will return invalid results depending on what you're searching for!</b> <br/>The FAKKU search API isn't very precise and I recommend you use the Chaika.moe plugin when possible.",
        icon =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAAFiUAABYlAUlSJPAAAACZSURBVDhPlY+xDYQwDEWvZgRGYA22Y4frqJDSZhFugiuuo4cqPGT0iTjAYL3C+fGzktc3hEcsQvJq6HtjE2Jdv4viH4a4pWnL8q4A6g+ET9P8YhS2/kqwIZXWnwqChDxPfCFfD76wOzJ2IOR/0DSwnuRKYAKUW3gq2OsJTYM0jr7QVRVwlabJEaw3ARYBcmFXeomxphIeEMIMmh3lOLQR+QQAAAAASUVORK5CYII=",
        oneshot_arg => "FAKKU Gallery URL (Will attach tags matching this exact gallery to your archive)",
        parameters  => [ { type => "bool", desc => "Add 'Source' tag" } ]
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info     = shift;                     # Global info hash
    my $ua           = $lrr_info->{user_agent};
    my ($add_source) = @_;

    my $logger = get_plugin_logger();

    # Work your magic here - You can create subs below to organize the code better

    my $cookie_jar = $ua->cookie_jar;
    my $cookies    = $cookie_jar->all;

    $logger->debug("Checking Cookies");
    if (@$cookies) {

        my $neededCookie = 0;

        for my $cookie (@$cookies) {
            if ( $cookie->name eq "fakku_sid" ) {
                $neededCookie = 1;
                $logger->debug("Found fakku_sid");
                last;    # Exit the loop if the cookie is found
            }
        }

        if ($neededCookie) {
            $logger->debug("The needed cookie was found.");
        } else {
            $logger->debug("The needed cookie was not found.");
            return ( error => "Not logged in to FAKKU! Set your FAKKU SID in the plugin settings page!" );
        }
    } else {
        $logger->debug("No Cookies were found!");
        return ( error => "Not logged in to FAKKU! Set your FAKKU SID in the plugin settings page!" );
    }

    my $fakku_URL = "";

    # Looks for the "source:" in the existing tags.
    my @oldTags = split( ',', $lrr_info->{existing_tags} );
    my $pattern = qr/^source:(.+)$/;

    foreach my $oldtag (@oldTags) {
        if ( $oldtag =~ $pattern ) {
            my $foundURL = $1;
            if ( $foundURL =~ /fakku\.net/ ) {    #Makes sure the found url is a fakku.net url.
                $fakku_URL = $foundURL;
            }
        }
    }

    # If the user specified a oneshot argument, use it as-is.
    # We could stand to pre-check it to see if it really is a FAKKU URL but meh
    if ( $lrr_info->{oneshot_param} ) {
        $fakku_URL = $lrr_info->{oneshot_param};
    }
    if ( $fakku_URL eq "" ) {

        # Search for a FAKKU URL if the user didn't specify one or none found in the tags.
        $fakku_URL = search_for_fakku_url( $lrr_info->{archive_title}, $ua );
    }

    # Do we have a URL to grab data from?
    if ( $fakku_URL ne "" ) {
        $logger->debug("Detected FAKKU URL: $fakku_URL");
    } else {
        $logger->info("No matching FAKKU Gallery Found!");
        return ( error => "No matching FAKKU Gallery Found!" );
    }

    my ( $newtags, $newtitle, $newSummary );
    eval { ( $newtags, $newtitle, $newSummary ) = get_tags_from_fakku( $fakku_URL, $ua, $add_source ); };

    if ($@) {
        return ( error => $@ );
    }

    $logger->info("Sending the following tags to LRR: $newtags");

    #Return a hash containing the new metadata - it will be integrated in LRR.
    return ( tags => $newtags, title => $newtitle, summary => $newSummary );
}

######
## FAKKU-Specific Methods
######

my $fakku_host = "https://www.fakku.net";

# search_for_fakku_url(title)
# Uses the website's search to find a gallery and returns its gallery ID.
sub search_for_fakku_url {

    my ( $title, $ua ) = @_;

    my $dom = get_search_result_dom( $title, $ua );

    # Get the first link on the page that starts with '/hentai/'
    my $path = $dom->at('[href^="/hentai/"]')->attr('href');

    if ( $path ne "" ) {
        return $fakku_host . $path;
    } else {
        return "";
    }

}

sub get_search_result_dom {

    my ( $title, $ua ) = @_;

    my $logger = get_plugin_logger();

# Strip away (some) characters that break search
# Note: The F! search backend sometimes fails to match you anyway. :/ The autosuggest API would work better but then again, CF issues
# * Changed the ' filter to '\w*, meaning instead of just stripping the apostrophe, we also strip whatever is after it ("we're" > "we" instead of "we're" > "were").
#      This is because just removing the apostrophe will return wrong (or no) results (to give an example "Were in love" would not return anything, whereas "we in love" would)
# * Added @ to the filters, because it's not supported by F*'s search engine either
# * Added a space ahead of the - (hyphen) filter, to only remove hyphens directly prepended to something else (those are the only ones that break searches, probably because the search engine treats them as exclusions as most engines would).
    $title =~ s/ -|'\w*|~|!|@//g;

    # Removes everything inside [ ] as well as the brackets themselves
    $title =~ s/\[([^\[\]]|(?0))*]//g;

    # Removes everything inside () as well as the parentheses themselves
    $title =~ s/\(.*$//g;

    # Visit the base host once to set cloudflare cookies and jank
    $ua->max_redirects(5)->get($fakku_host);

# Use the regular search page.
# The autosuggest API (fakku.net/suggest/blahblah) yields better results but is blocked unless you make it through cloudflare or are logged in?
    my $URL = "$fakku_host/search/" . uri_escape_utf8($title);

    $logger->debug("Using URL $URL to search on FAKKU.");

    my $res = $ua->max_redirects(5)->get($URL)->result;

    # $logger->debug( "Got this HTML: " . $res->body );

    return $res->dom;
}

sub get_dom_from_fakku {

    my ( $url, $ua ) = @_;

    my $logger = get_plugin_logger();

    my $res = $ua->max_redirects(5)->get($url)->result;

    my $html = $res->body;

    # $logger->debug( "Got this HTML: " . $html );
    if ( $html =~ /.*error code: (\d*).*/gim ) {
        $logger->debug("Blocked by Cloudflare, aborting for now. (Error code $1)");
        die "The plugin has been blocked by Cloudflare. (Error code $1) Try opening FAKKU in your browser to bypass this.";
    }

    return $res->dom;
}

# get_tags_from_fakku(fURL)
# Parses a FAKKU URL for tags.
sub get_tags_from_fakku {

    my ( $url, $ua, $add_url ) = @_;

    my $logger = get_plugin_logger();

    my $dom = get_dom_from_fakku( $url, $ua );

    # find the "suggest more tags" link and use parent div
    # this is not ideal, but the divs don't have named classes anymore
    my $tags_parent = $dom->at('[data-tippy-content="Suggest More Tags"]')->parent;

    # div that contains other divs with title, namespaced tags (artist, magazine, etc.) and misc tags
    my $metadata_parent = $tags_parent->parent->parent;

    my $title = $metadata_parent->at('h1')->text;
    $title = trim($title);
    $logger->debug("Parsed title: $title");

    my @tags = ();

    # Finds the DIV for the Summary.
    my $summ_selector =
      '.table-cell.w-full.align-top.text-left.space-y-2.leading-relaxed.link\:text-blue-700.dark\:link\:text-white';
    my $summ_div = $dom->at($summ_selector);
    my $summary;

    # If the Summary DIV doesn't exist, return a blank string.
    if ( defined $summ_div ) {
        $summary = $summ_div->all_text;
    } else {
        $summary = "";
    }

    # If no FAKKU description exists, just keep it blank.
    if ( $summary eq "No description has been written." ) {
        $summary = "";
    }

    # We can grab some namespaced tags from the first few div.
    my @namespaces = $metadata_parent->children('div')->each;

    foreach my $div (@namespaces) {

        my @row = $div->children->each;

        next if ( scalar @row != 2 );

        my $namespace = $row[0]->text;

        $logger->debug("Evaluating row: $row[1]");
        my $value =
          ( $row[1]->at('a') )
          ? $row[1]->at('a')->text
          : $row[1]->text;

        $value = trim($value);
        $value = trim_CRLF($value);

        # for the edgecase if the gallery is in the top 10 of 2 categories
        if ( $value eq "in  this month." || $value eq " in  this month." ) {
            next;
        }

        $logger->debug("Parsed row: $namespace");
        $logger->debug("Matching tag: $value");

        unless ( $namespace eq "Tags"
            || $namespace eq "Pages"
            || $namespace eq "Description"
            || $namespace eq "Direction"
            || $namespace eq "Favorites"
            || $value eq "" ) {
            push( @tags, "$namespace:$value" );
        }
    }

    # might be worth filtering by links starting with '/tags/*' but that filters out the special "unlimited" tag
    my @tag_links = $tags_parent->find('a')->each;

    foreach my $link (@tag_links) {
        my $tag = $link->text;

        $tag = trim($tag);
        $tag = trim_CRLF($tag);
        unless ( $tag eq "+" || $tag eq "" ) {
            push( @tags, lc $tag );
        }
    }

    # Adds the source tag is enabled.
    if ($add_url) {
        $url =~ s{^https://www\.}{}i;
        push( @tags, "source:" . $url );
    }

    return ( join( ', ', @tags ), $title, $summary );

}

1;
