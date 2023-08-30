package LANraragi::Plugin::Scripts::SourceFinder;

use strict;
use warnings;
no warnings 'uninitialized';

use Mojo::UserAgent;
use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Model::Stats;
use LANraragi::Utils::String qw(trim_url);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "Source Finder",
        type        => "script",
        namespace   => "urlfinder",
        author      => "Difegue",
        version     => "2.0",
        description => "Looks in the database if an archive has a 'source:' tag matching the given URL.",
        icon =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAIAAAAC64paAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAABZSURBVDhPzY5JCgAhDATzSl+e/2irOUjQSFzQog5hhqIl3uBEHPxIXK7oFXwVE+Hj5IYX4lYVtN6MUW4tGw5jNdjdt5bLkwX1q2rFU0/EIJ9OUEm8xquYOQFEhr9vvu2U8gAAAABJRU5ErkJggg==",
        oneshot_arg => "URL to search."
    );

}

# Mandatory function to be implemented by your script
sub run_script {
    shift;
    my $lrr_info = shift;                 # Global info hash
    my $logger   = get_plugin_logger();

    # Only info we need is the URL to search
    my $url = $lrr_info->{oneshot_param};
    $logger->debug( "Looking for URL " . $url );

    trim_url($url);

    if ( $url eq "" ) {
        return ( error => "No URL specified!", total => 0 );
    }

    my $recorded_id = LANraragi::Model::Stats::is_url_recorded($url);
    if ($recorded_id) {
        return (
            total => 1,
            id    => $recorded_id
        );
    }

    # Specific variant for EH/Ex URLs, where we'll check with the other domain as well.
    my $last_chance_id = "";
    if ( $url =~ /https?:\/\/exhentai\.org\/g\/([0-9]*)\/([0-z]*)\/*.*/gi ) {
        my $url2 = "https://e-hentai.org/g/$1/$2";
        $last_chance_id = LANraragi::Model::Stats::is_url_recorded($url2);
    }

    if ( $url =~ /https?:\/\/e-hentai\.org\/g\/([0-9]*)\/([0-z]*)\/*.*/gi ) {
        my $url2 = "https://exhentai.org/g/$1/$2";
        $last_chance_id = LANraragi::Model::Stats::is_url_recorded($url);
    }

    if ($last_chance_id) {
        return (
            total => 1,
            id    => $last_chance_id
        );
    }

    return ( error => "URL not found in database.", total => 0 );
}

1;
