# Getting started

## How To Write a Plugin for LRR

LANraragi supports a Plugin system for various purposes:

* Logging in to external web services
* Importing metadata from said web services and other sources
* Taking an URL from one of those web services and returning a matching, downloadable URL to add to the archive index
* Running scripts against the LRR system to manipulate and extract data at will

This part of the documentation aims at giving pointers to would-be Plugin developers.

## Available Language and Modules

Plugins are expected to be [Perl Modules](http://www.perlmonks.org/?node_id=102347).  
All Plugins need to declare their metadata through the `plugin_info` hash.  
Other subroutines need to be implemented depending on the Plugin type.

Once the module is recognized, it will be available for use in LANraragi.  
All Perl features are available for use, as well as all installed CPAN Modules and LRR API functions present.  
Basically, _as long as it can run, it will run_.

{% hint style="danger" %}
As you might've guessed, Plugins run with the same permissions as the main application.  
This means they can modify the application database at will, delete files, and execute system commands.  
None of this is obviously an issue if the application is installed in a proper fashion.\(Docker/Vagrant, or non-root user on Linux _I seriously hope you guys don't run this as root_\)

Still, as said in the User Documentation, be careful of what you do with Plugins.
{% endhint %}

## Plugin Metadata

Metadata follows a simple format, being all present in a hash returned by the `plugin_info` subroutine:

```perl
#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "My Plugin",
        type        => "metadata",
        #login_from  => "dummylogin",
        namespace   => "dummyplug",
        author      => "Hackerman",
        version     => "0.001",
        description => "This is the description of my Plugin",
        icon        => "This is a base64-encoded 20x20 image that will be displayed as an icon in the plugin list. Optional!"
        oneshot_arg => "This is the description for a one-shot argument that can be entered by the user when executing this plugin on a file",
        parameters  => [
            {type => "bool", desc => "Boolean parameter description"},
            {type => "string", desc => "String parameter description"},
            {type => "int", desc => "Integer parameter description"}
            ],
        # Downloader-specific metadata
        url_regex => "If this is a Downloader Plugin, this is the regex that will trigger said plugin if it matches the URL to download."
    );

}
```

There are no restrictions on what you can write in those fields, except for the `namespace`, which should preferrably be **a single word.**  
It's used as a unique ID for your Plugin in various parts of the app.  
The `login_from` parameter can be used to execute a login plugin before your plugin runs.  
The `type` field can be either:

* `login` for [Login Plugins](login.md)
* `metadata` for [Metadata Plugins](metadata.md)  
* `download` for [Downloader Plugins](downloaders.md)  
* `script` for [Script Plugins](scripts.md)  

The `parameters` array can contain as many arguments as you need. They can be set by the user in Plugin Configuration, and are transmitted every time.  
Typical uses for it include login credentials for a remote website, configuration options, etc. Basic stuff.  
The field **MUST** contain an array, even if it only has one argument inside!

## Installing and Testing your Plugin

Installing a Plugin is as simple as dropping the .pm file in LANraragi's Plugin directory.  
Restart the app, and your Plugin's name should appear on the initial listing.

{% hint style="info" %}
You can also sideload Plugins through Plugin Configuration in the webapp.
{% endhint %}

Once this is done, you can test your plugin by simply using it:

* Metadata plugins can be used by enabling them for Auto-Tagging or on individual archives.  
* Script plugins can be directly executed from Plugin Configuration.
* Login plugins can't be tested directly for now.  

{% hint style="info" %}
It is also possible to execute plugins through the [Client API](../extending-lanraragi/client-api.md).
{% endhint %}

If LANraragi is running in Debug Mode, debug messages from your plugin will be logged.

