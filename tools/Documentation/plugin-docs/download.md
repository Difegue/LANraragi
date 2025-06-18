# Downloader Plugins

Downloader Plugins are used as part of LANraragi's built-in downloading feature.

## Required subroutines

Only one subroutine needs to be implemented for the module to be recognized: `provide_url`, which contains your working code. You're free to implement other subroutines for cleaner code, of course.

Your plugin also needs an extra field in its metadata: `url_regex`, which contains a Regular Expression that'll be used by LANraragi to know if your Downloader should be used.
For example, if your regex is `https?:\/\/example.com.*`, LANraragi will invoke your plugin if the user wants to download an URL that comes from `example.com`.

{% hint style="info" %}
In case of multiple Downloaders matching the given URL, the server will invoke the first plugin that matches.
{% endhint %}

### Expected Input

The following section deals with writing the `provide_url` subroutine.
When executing your Plugin, LRR will call this subroutine and pass it the following variables:

```perl
sub provide_url {

    #First lines you should have in the subroutine
    shift;
    my $lrr_info = shift; # Global info hash
    my ($param1, $param2) = @_; # Plugin parameters
```

The variables match the parameters you've entered in the `plugin_info` subroutine.

The `$lrr_info` hash contains three variables you can use in your plugin:

* _$lrr\_info->{url}_: The URL that needs to be downloaded.
* _$lrr\_info->{user\_agent}_: [Mojo::UserAgent](https://mojolicious.org/perldoc/Mojo/UserAgent) object you can use for web requests. If this plugin depends on a Login plugin, this UserAgent will be pre-configured with the cookies from the Login.
* _$lrr\_info->{tempdir}_: A temporary directory path where you can store files. This is useful when you need to download and process multiple images, and are assembling the archive locally.

### Expected Output

LRR expects Downloaders to return a hash containing either a new URL that can be downloaded directly, *or* a path to a file that has already been downloaded.

For returning a URL to download:

`return ( download_url => "http://my.remote.service/download/secret-archive.zip" );`

{% hint style="info" %}
Said URL should **directly** point to a file -- Any form of HTML will trigger a failed download.
{% endhint %}

For returning a local file path (that you've already downloaded/created):

`return ( file_path => "/path/to/downloaded/file.zip" );`

If your script errored out, you can immediately stop the plugin execution and tell LRR that an error occurred by throwing an exception:

`die "my error :(\n";`

or by returning a hash containing an "error" field (**this method is deprecated**):

`return ( error => "my error :(" );`

If you do this, the error will be logged/displayed to the user.

## Plugin Template

```perl
package LANraragi::Plugin::Download::MyNewDownloader;

use strict;
use warnings;

# Plugins can freely use all Perl packages already installed on the system
# Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use Mojo::UserAgent;

# You can also use LRR packages when fitting.
# All packages are fair game, but only functions explicitly exported by the Utils packages are supported between versions.
# Everything else is considered internal API and can be broken/renamed between versions.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_logger);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "Example.com Downloader",
        type        => "download",
        namespace   => "dummydl",
        author      => "Hackerman",
        version     => "0.1",
        description => "This is base boilerplate for writing LRR downloaders. Returns a static URL if you try to download a URL from http://example.com.",
        icon        => "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAIAAAAC64paAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAABZSURBVDhPzY5JCgAhDATzSl+e/2irOUjQSFzQog5hhqIl3uBEHPxIXK7oFXwVE+Hj5IYX4lYVtN6MUW4tGw5jNdjdt5bLkwX1q2rFU0/EIJ9OUEm8xquYOQFEhr9vvu2U8gAAAABJRU5ErkJggg==",

        # Downloader-specific metadata
        url_regex => "https?:\/\/example.com.*"
    );

}

## Mandatory function to be implemented by your script
sub provide_url {
    shift;
    my $lrr_info = shift; # Global info hash
    my ($useposts) = @_; # Plugin parameters

    my $logger = get_logger( "Dingus Downloader", "plugins" );

    # Get the url
    my $url = $lrr_info->{url};
    $logger->debug("We have been given the following URL: $url" );

    # This is the downloadable url we'll give back. It can be completely different from the base domain provided.
    my $reply = "https://archive.org/download/quake-essays-sep-15-fin-4-graco-l-cl/QUAKE_essays_SEP15_FIN4_GRACoL_CL.pdf";

    # Just for fun, use the provided useragent to see if we've been given a real URL
    my $ua = $lrr_info->{user_agent};
    my $res = $ua->get($url)->result;

    if ($res->is_success) {
         return ( download_url => $reply );
    }
    elsif ($res->is_error) {
        die "Dingus! ".$res->message;
    }

}

1;
```
