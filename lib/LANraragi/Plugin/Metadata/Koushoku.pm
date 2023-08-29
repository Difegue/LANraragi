package LANraragi::Plugin::Metadata::Koushoku;

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
use LANraragi::Utils::String qw(trim);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name      => "Koushoku",
        type      => "metadata",
        namespace => "kskmetadata",
        author    => "Difegue",
        version   => "1.0",
        description =>
          "Searches KSK for tags matching your archive. <br/><i class='fa fa-exclamation-circle'></i> This plugin will use the source: tag of the archive if it exists.",
        icon =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAAFiUAABYlAUlSJPAAAANkSURBVDhPJZJpU5NXGIbf/9Ev0g+MM7Udp9WWDsVOsRYQKEVZQ4BsZnt9sy9shgShBbTYaTVCKY1B1pBEQggGFOogKEvYdOoXfszVQ/rhmTkz59zXc9/PeaRO12163DZCbgc+8y06HTJ+h5UOp4xLvoXdoOFBf5Auu4LS3obc0oJDp8VhNtLlcyN1uRWcZj13vS5cBi1+mwWPYiLY6cYjG+lxKoR8LgHpw9BQz+OBAbS1tch6DR1uO1Kox4dWVcfdDg9uswGnVSc66wn47QJmwtreTEPFVZxCoKosJ3hbRmlpRt8kNEIrdfscNN+o4tfeHhz6VhHBgqG1nsHeDpxGDV6zDkWjIvxLH25tK2+WUkzcG8JrNdJ/x4803NuJrr4G7Y/X8+UWIl1TDUGfgsfUjl2nwm/WMjrUh72tEXXFNYoKP+b74ks4FQOStuEnVNVlWBtv8kBYcmhVBJwWLOo6vKY2fvbaSD0ZxdnWxKWCj1CVXiEyPIBVuAz6bUiySc0dj0zAbsZtaM1fRH4fwm/RMDYYYCP2lNnfBsn89ZghxcIjMfmxng5GQ92ExIwkj6Kn5UYF6uofhMUG2mvLycYi7GaTnKwvk0vH+XctzXE6weupCFvRCP9MjLMx+Tfdulak4s8KqSr5kppvLmNT3WRQWN5Oz7ObibObnmMnMSXECxwtxdidi7L+Z5jlP0bYnJnEKX5PUpeVshqdINzl475dZnN+kqPsIocrApCa5fVchP3kDAeLc3nQ1vQTNqcjbCZncbQ3It1XZLLhR7wUtTMZZWd2Ugj+f3yYjpFLzbC/OM1BZoHcygJ7KeFEuHu7lsJmViN5G+o4jsd5+fAhKyMjecDJUoK9xDTH4uG753E+bCxxtJpkX5xzmQS5FyniU2MYNCKCsbo8b/84GWf7aZSt2Wi+81kdPU+wPj1OOOAhIHbi3Yu0GGqS07evqCv7llCXA+n6VxcpKTzHwsgwH1bTvBf0g7NOwu7J6jPGQn4iQ4H8XPZErNPNdYIWPZfPn6OvUwDUlVe59vknfHe+gLGAn9PtNQ7XnpHLJjgUdQZ6vy4iCMDxaiq/D8WFBXx9oZCA+DFJI3agougiVV9cyEOqij6l32UkFr6Xz7yfibG3PM/eSoLs1Di2+loaS0uovFIkFlDhPxYUixj0Cgg3AAAAAElFTkSuQmCC",
        parameters  => [ { type => "bool", desc => "Save archive title" } ],
        oneshot_arg => "Koushoku Gallery URL (Will attach tags matching this exact gallery to your archive)"
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;                     # Global info hash
    my $ua       = $lrr_info->{user_agent};

    my ($savetitle) = @_;                     # Plugin parameters

    my $logger = get_plugin_logger();

    # Work your magic here - You can create subs below to organize the code better
    my $ksk_URL = "";

    # If the user specified a oneshot argument, use it as-is.
    # We could stand to pre-check it to see if it really is a FAKKU URL but meh
    if ( $lrr_info->{oneshot_param} ) {
        $ksk_URL = $lrr_info->{oneshot_param};
    } elsif ( $lrr_info->{existing_tags} =~ /.*source:\s*ksk\.moe\/view\/([0-9]*)\/([0-z]*)\/*.*/gi ) {
        my $gID    = $1;
        my $gToken = $2;
        $ksk_URL = "https://ksk.moe/view/$gID/$gToken";
        $logger->debug("Skipping search and using $gID / $gToken from source tag");
    } else {

        # Search for a KSK URL if the user didn't specify one
        $ksk_URL = search_for_ksk_url( $lrr_info->{archive_title}, $ua );
    }

    # Do we have a URL to grab data from?
    if ( $ksk_URL ne "" ) {
        $logger->debug("Detected Koushoku URL: $ksk_URL");
    } else {
        $logger->info("No matching Koushoku Gallery Found!");
        return ( error => "No matching Koushoku Gallery Found!" );
    }

    my ( $newtags, $newtitle );
    eval { ( $newtags, $newtitle ) = get_tags_from_ksk( $ksk_URL, $ua ); };

    if ($@) {
        return ( error => $@ );
    }

    $logger->info("Sending the following tags to LRR: $newtags");

    #Return a hash containing the new metadata - it will be integrated in LRR.
    if ( $savetitle && $newtags ne "" ) { return ( tags => $newtags, title => $newtitle ); }
    else                                { return ( tags => $newtags ); }
}

######
## KSK-Specific Methods
######

# search_for_ksk_url(title, useragent)
# Uses the website's search to find a gallery and returns its gallery ID.
sub search_for_ksk_url {

    my ( $title, $ua ) = @_;
    my $dom = get_search_result_dom( $title, $ua );

    # Get the first link on the page that has rel="bookmark"
    my $path = $dom->at('a[rel="bookmark"]')->attr('href');

    if ( $path ne "" ) {
        return "https://ksk.moe" . $path;
    } else {
        return "";
    }

}

sub get_search_result_dom {

    my ( $title, $ua ) = @_;
    my $logger = get_plugin_logger();

    # Use the regular search page.
    my $URL = "https://ksk.moe/browse?s=" . uri_escape_utf8($title);

    $logger->debug("Using URL $URL to search.");

    my $res = $ua->max_redirects(5)->get($URL)->result;
    $logger->debug( "Got this HTML: " . $res->body );

    return $res->dom;
}

# get_tags_from_ksk(fURL, useragent)
# Parses a KSK URL for tags.
sub get_tags_from_ksk {

    my ( $url, $ua ) = @_;
    my $logger = get_plugin_logger();

    my $dom = get_dom_from_ksk( $url, $ua );

    # Title is the first h1 block
    my $title = $dom->at('h1')->text;
    $title = trim($title);
    $logger->debug("Parsed title: $title");

    # Get all the links with rel="tag"
    my @tags     = ();
    my @tags_dom = $dom->find('a[rel="tag"]')->each;

    # Use the href to get the tag name and namespace.
    @tags_dom = map { $_->attr('href') } @tags_dom;

    foreach my $href (@tags_dom) {

        # "/tags/blahblah" => "blahblah", "/artists/blah%20blah" => "artist:blah blah"
        if ( $href =~ /\/(.*)\/(.*)/ ) {
            $logger->debug("Matching tag: $1 / $2");

            # url-decode it before pushing
            my $tag = uri_unescape($2);
            $tag = trim($tag);

            if ( $1 eq "artists" ) {
                $tag = "artist:" . $tag;
            }

            if ( $1 eq "parodies" ) {
                $tag = "parody:" . $tag;
            }

            if ( $1 eq "magazines" ) {
                $tag = "magazine:" . $tag;
            }

            push( @tags, lc $tag );
        }
    }

    return ( join( ', ', @tags ), $title );

}

sub get_dom_from_ksk {

    my ( $url, $ua ) = @_;
    my $logger = get_plugin_logger();

    my $res = $ua->max_redirects(5)->get($url)->result;
    $logger->trace( "Got this HTML: " . $res->body );
    my $dom = $res->dom;
}

1;
