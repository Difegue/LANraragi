# Frequently used API functions

This section contains a few bits of code for things you might want to do with Plugins.

## **Write messages to the Plugin Log**

```perl
# Import the LRR logging module
use LANraragi::Utils::Logging qw(get_logger);
# Use the logger to output status - they'll be passed to a specialized logfile and written to STDOUT.
my $logger = get_logger("MyPluginName","plugins");

$plugin->debug("This message will only show if LRR is in Debug Mode")
$plugin->info("You know me the fighting freak Knuckles and we're at Pumpkin Hill");
$plugin->warn("You ready?");
$plugin->error("Oh no");
```

The logger is a preconfigured [Mojo::Log](http://mojolicious.org/perldoc/Mojo/Log) object.

## **Make requests to a remote WebService**

[Mojo::UserAgent](http://mojolicious.org/perldoc/Mojo/UserAgent) is a full-featured HTTP client coming with LRR you can use.

```perl
use Mojo::UserAgent;

my $ua = $lrr_info->{user_agent};

#Get HTML from a simple GET request
$ua->get("http://example.com")->result->body;

#Make a POST request and get the JSON result
my $rep = $ua->post(
        "https://jsonplaceholder.typicode.com/" => json => {
            stage  => "Meteor Herd",
            location   => [ [ "space", "colony" ] ],
            emeralds => 3
        }
    )->result;

#JSON decoded to a perl object
my $jsonresponse = $rep->json;

#JSON decoded to a string
my $textrep      = $rep->body;
```

## **Read values in the LRR Database**

```perl
my $redis = LANraragi::Model::Config->get_redis;

my $value = $redis->get("key");
```

This uses the excellent [Perl binding library](http://search.cpan.org/~dams/Redis-1.991/lib/Redis.pm) for Redis.

## **Extract files from the archive being examined**

If you're running 0.5.2 or later:

```perl
use LANraragi::Utils::Archive qw(is_file_in_archive extract_file_from_archive);

#Check if info.json is in the archive located at $file
if (is_file_in_archive($file,"info.json")) {

        #Extract info.json
        extract_file_from_archive($file, "info.json");

        #Extracted files go to public/temp/plugin
        my $filepath = "./public/temp/plugin/info.json";

        #Do whatever you need
}
```
