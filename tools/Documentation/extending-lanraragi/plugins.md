# Plug-ins

## How To Write a Plugin for LRR

LANraragi supports a Plugin system for importing metadata from various sources: External Web APIs, embedded text files, etc.  
This part of the documentation aims at giving pointers to would-be Plugin developers.

### Available Language and Modules

Plugins are expected to be [Perl Modules](http://www.perlmonks.org/?node_id=102347).  
Only one subroutine needs to be implemented for the module to be recognized: `get_tags`, which contains your working code. You're free to implement other subroutines for cleaner code, of course.  
Besides this subroutine, you also need to implement the `plugin_info` hash, which contains the metadata for your Plugin.

Once the module is recognized, it will be available for use in LANraragi.  
All Perl features are available for use, as well as all installed CPAN Modules and LRR API functions present.  
Basically, _as long as it can run, it will run_.

{% hint style="danger" %}
As you might've guessed, Plugins run with the same permissions as the main application.  
This means they can modify the application database at will, delete files, and execute system commands.  
None of this is obviously an issue if the application is installed in a proper fashion.\(Docker/Vagrant, or non-root user on Linux _I seriously hope you guys don't run this as root_\)

Still, as said in the User Documentation, be careful of what you do with Plugins.
{% endhint %}

### Plugin Metadata

Metadata follows a simple format, being all present in a hash returned by the `plugin_info` subroutine:

```perl
#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "My Plugin",
        type        => "metadata",
        namespace   => "dummyplug",
        author      => "Hackerman",
        version     => "0.001",
        description => "This is the description of my Plugin",
        icon        => "This is a base64 20x20 image that will be displayed as an icon in the plugin list. Optional!"
        oneshot_arg => "This is the description for a one-shot argument that can be entered by the user when executing this plugin on a file",
        parameters  => [
            {type => "bool", desc => "Boolean parameter"},
            {type => "string", desc => "String parameter"},
            {type => "int", desc => "Integer parameter"}
            ]
    );

}
```

There are no restrictions on what you can write in those fields, except for the namespace, which should preferrably be **a single word.**  
It's used as a unique ID for your Plugin in various parts of the app.  
The `parameters` array can contain as many arguments as you need. The `type` field should stay as "metadata" for the time being.

### Expected Input

The following section deals with writing the `get_tags` subroutine.  
When executing your Plugin, LRR will call this subroutine and pass it the following variables:

```perl
sub get_tags {

    #First lines you should have in the subroutine
    shift;
    my ($title, $tags, $thumbhash, $file, $oneshotarg, @args) = @_;
```

* _$title_: The title of the archive, as entered by the User. 
* _$tags_: The tags that are already in LRR for this archive, if there are any.
* _$thumbhash_: A SHA-1 hash of the first image of the archive.
* _$file_: The filesystem path to the archive.
* _$oneshotarg_: Value of your one-shot argument, if it's been set by the User.
* _@args_: Array containing all your other arguments, if their values have been set by the User.

### Global and One-Shot Arguments

Besides information about the archive, LRR can also transmit to your plugin multiple kinds of arguments: Global arguments and a One-Shot Argument.

The **Global Arguments** can be set by the user in Plugin Configuration, and are transmitted every time.  
Typical uses for it include login credentials for a remote website, configuration options, etc. Basic stuff.

The **One-Shot Argument** can be set by the user every time he uses your Plugin on a specific file, through LRR's Edit Menu.  
It's more meant for special overrides you'd want to use for this specific file:  
For example, in E-Hentai and nHentai plugins, it can be used to set a specific Gallery URL you want to pull tags from.

If you want the user to be able to enter those arguments, the `parameters` and `oneshot_arg` fields must be present in `plugin_info`, and contain brief descriptions of what your arguments are for.

One-Shot Arguments can only be strings, but other parameters can be either a boolean, an integer or a string, depending on your needs.  
Descriptions will be shown to the user. For `parameters`, the field **MUST** contain an array, even if it only has one argument inside!

### Expected Output

Once you're done and obtained your tags, all that's needed for LRR to handle them is to return a hash containg said tags.  
Tags are expected to be separated by commas, like this:

`return ( tags => "my:new, tags:here, look ma no namespace" );`

From 0.5.6-EX onwards, plugins can also modify the title of the archive:  
`return ( tags => "some:tags", title=>"My new epic archive title" );`  
This parameter is completely optional. \(The tags one isn't however, but it can very well be empty.\)

If you couldn't obtain tags for some reason, you can tell LRR that an error occurred by returning a hash containing an "error" field:

`return ( error => "my error :(" );`

If you do this, no tags will be added for this archive, and the error will be logged/displayed to the user.

### Installing and Testing your Plugin

Installing a Plugin is as simple as dropping the .pm file in LANraragi's Plugin directory.  
Restart the app, and your Plugin's name should appear on the initial listing.

Once this is done, you can test your plugin by simply using it, either by enabling it for Auto-Tagging or on individual archives.  
If LANraragi is running in Debug Mode, debug messages from your plugin will be logged.

## Boilerplate and Frequently used API functions

### Plugin Template

Examples speak better than words: The code below is a fully-working plugin stub.

```perl
package LANraragi::Plugin::MyNewPlugin;

use strict;
use warnings;

#Plugins can freely use all Perl packages already installed on the system 
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use Mojo::UserAgent;

use LANraragi::Model::Plugins;

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name  => "Plugin Boilerplate",
        type  => "metadata",
        namespace => "dummyplug",
        author => "Hackerman",
        version  => "0.001",
        description => "This is base boilerplate for writing LRR plugins.",
        icon => "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAABmJLR0QAAAAAAAD5Q7t/AAAACXBI\nWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH4wYDFCYzptBwXAAAAB1pVFh0Q29tbWVudAAAAAAAQ3Jl\nYXRlZCB3aXRoIEdJTVBkLmUHAAAAjUlEQVQ4y82UwQ7AIAhDqeH/f7k7kRgmiozDPKppyisAkpTG\nM6T5vAQBCIAeQQBCUkiWRTV68KJZ1FuG5vY/oazYGdcWh7diy1Bml5We1yiMW4dmQr+W65mPjFjU\n5PMg2P9jKKvUdxWMU8neqYUW4cBpffnxi8TsXk/Qs8GkGGaWhmes1ZmNmr8kuMPwAJzzZSoHwxbF\nAAAAAElFTkSuQmCC",
        #If your plugin uses/needs custom arguments, input their name here. 
        #This name will be displayed in plugin configuration next to an input box for global arguments, and in archive edition for one-shot arguments.
        oneshot_arg => "This is a one-shot argument that can be entered by the user when executing this plugin on a file",
        parameters  => [
            {type => "bool", desc => "Enable the DOOMSDAY DEVICE"},
            {type => "int",  desc => "Number of iterations"}
        ]
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    #LRR gives your plugin the recorded title for the file, the filesystem path to the file, and the custom arguments if available.
    shift;
    # Here, I replace @args by two variables directly matching my global arguments -- Feel free to use this variant if you prefer it.
    my ($title, $tags, $thumbhash, $file, $oneshotarg, $doomsday, $iterations) = @_;

    #Use the logger to output status - they'll be passed to a specialized logfile and written to STDOUT.
    my $logger = LANraragi::Utils::Generic::get_logger("My Cool Plugin","plugins");

    if ($doomsday) {
        return ( error => "You fools! You've messed with the natural order!");
    }

    #Work your magic here - You can create subroutines below to organize the code better
    $logger->info("Gettin' tags");
    my $newtags = get_tags_from_somewhere($iterations); #To be implemented
    my $error = 0;

    #Something went wrong? Return an error.
    if ($error) {
        $logger->error("Oh no");
        return ( error => "Error Text Here");
    }

    #Otherwise, return the tags you've harvested.
    return ( tags => $newtags );
}

sub get_tags_from_somewhere {

    my $iterations = shift;
    my $logger = LANraragi::Utils::Generic::get_logger("My Cool Plugin","plugins");

    $logger->info("I'm supposed to be iterating $iterations times but I don't give a damn my man");

    #Tags are expected to be submitted as a single string, containing tags split up by commas. Namespaces are optional.
    return "my:new, tags:here, look ma no namespace"; 
}

1;
```

### API Functions

This section contains a few bits of code for things you might want to do with Plugins.

#### **Write messages to the Plugin Log**

```perl
#Use the logger to output status - they'll be passed to a specialized logfile and written to STDOUT.
my $logger = LANraragi::Generic::Utils::get_logger("MyPluginName","plugins");

$plugin->debug("This message will only show if LRR is in Debug Mode")
$plugin->info("You know me the fighting freak Knuckles and we're at Pumpkin Hill");
$plugin->warn("You ready?");
$plugin->error("Oh no");
```

The logger is a preconfigured [Mojo::Log](http://mojolicious.org/perldoc/Mojo/Log) object.

#### **Make requests to a remote WebService**

[Mojo::UserAgent](http://mojolicious.org/perldoc/Mojo/UserAgent) is a full-featured HTTP client coming with LRR you can use.

```perl
use Mojo::UserAgent;

my $ua = Mojo::UserAgent->new;

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

#### **Read values in the LRR Database**

```perl
use LANraragi::Model::Config;

my $redis = LANraragi::Model::Config::get_redis;

my $value = $redis->get("key");
```

This uses the excellent [Perl binding library](http://search.cpan.org/~dams/Redis-1.991/lib/Redis.pm) for Redis.

#### **Extract files from the archive being examined**

If you're running 0.5.2 or later:

```perl
#Check if info.json is in the archive located at $file
if (LANraragi::Utils::Archive::is_file_in_archive($file,"info.json")) {

        #Extract info.json
        LANraragi::Utils::Archive::extract_file_from_archive($file, "info.json");

        #Extracted files go to public/temp/plugin
        my $filepath = "./public/temp/plugin/info.json";

        #Do whatever you need
}
```

