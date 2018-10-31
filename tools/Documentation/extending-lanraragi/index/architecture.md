---
description: Read up on all the badly hacked nitty gritty that makes LRR tick here.
---

# Architecture & Style

## Coding Style

While Perl's mantra is "There's more than one way to do it", I try to make LRR follow the PBP, aka Perl Best Practices.  
This is done by the use of the [Perl::Critic](https://metacpan.org/pod/Perl::Critic) module, which reports PBP violations.  
If installed, you can run the critic on the entire LRR source tree through the `npm run critic` shortcut command.

I also run [perltidy](https://en.wikipedia.org/wiki/PerlTidy) on the source tree every now and then for consistency.

## Main App Architecture

```text
root/
|- content <- Default content folder 
|
|- lib <- Core application code
|  |- LANraragi.pm <- Entrypoint for the app, contains basic startup code and routing to Controllers
|  |- Shinobu.pm <- Background Worker (see below)
|  +- LANraragi
|     |- Controller <- One Controller per page
|        +- *.pm <- Index, Config, Reader, Api, etc.
|     |- Model <- Application code that doesn't rely on Mojolicious
|        |- Backup.pm <- Encodes/Decodes Backup JSONs
|        |- Config.pm <- Communicates with the Redis DB to store/retrieve Configuration
|        |- Plugins.pm <- Executes Plugins on archives
|        |- Reader.pm <- Archive Extraction 
|        +- Utils.pm <- Generic Functions 
|     +- Plugin <- LRR Plugins are stored here
|        +- *.pm
|
|- log <- Application Logs end up here
|
|- public <- Files available to Web Clients
|  |- css <- Global CSS sheets
|     |- lrr.css
|     +- vendor <- Third-party CSS sheets obtained through NPM
|  |- img <- Image resources
|  |- js <- JavaScript functions
|     |- *.js
|     +- vendor <- Third-party JS obtained through NPM
|  |- temp <- Archives are extracted in this folder to be served to clients. Also used for thumbnail creation.
|  +- themes <- Contains CSS sheets for Themes.
|
|- script
|  +- lanraragi <- Bootstrap script, starts LANraragi.pm
|
|- tests <- Tests go here
|
|- templates <- Templates for Web pages
|  +- *.html.tt2 
|
|- tools <- Contains scripts for building and installing LRR.
|  |- DockerSetup <- Dockerfile and configuration files for LRR Docker Container
|  |- VagrantSetup <- Vagrantfile for LRR Vagrant Machine
|  |- cpanfile <- Perl dependencies description
|  |- install.pl <- LANraragi Installer
|  |- logo.png/svg <- Self-explanatory
|
|- lrr.conf <- Mojolicious configuration file
+- package.json <- NPM file, contains front-end dependency listing and shortcuts
```

## Background Worker

The Shinobu Background Worker runs in parallel of the LRR Mojolicious Server and handles various tasks repeatedly:

* Scanning the content folder for new archives
* Adding new archives and executing Plugins on them if enabled
* Regenerates the JSON cache when metadata or archive count changes

It's a second process spawned through the Proc::Background Perl Module.

**About the JSON Cache**

The JSON cache represents all the current archives in the content folder, alongside their metadata.  
This cache is then loaded by the main page of LRR.

LANraragi by itself does not modify this cache in any way: It only consumes it.  
This allows it to always stay responsive/quick even with hundreds of archives in the database -- All the indexing work is left to the Shinobu worker.

**Behaviour in Debug Mode**

In Debug Mode, the Mojolicious server auto-restarts on every file modification.  
You also get access to the Mojolicious logs in LRR's built-in Log View.

## Installation Script

The _install.pl_ script is essentially a sequence of commands executed to install the backend and frontend dependencies needed to run LRR, as well as basic environment checks.

## Database Architecture

You can look inside the LRR Redis database at any moment through the `redis-cli` tool. The base architecture is as follows:

```text
-Redis Database
|- **************************************** <- 40-character long ID for every logged archive
|  |- tags <- Saved tags
|  |- name <- Name of the archive file, kept for filesystem checks
|  |- title <- Title of the archive, as set by the User 
|  |- file <- Filesystem path to archive
|  |- isnew <- Whether the archive has been opened in LRR once or not
|  +- thumbhash <- SHA-1 hash of the first image of the archive
|
|- LRR_CONFIG <- Configuration keys, usually set through the LRR Configuration page.
|  |- tempmaxsize  
|  |- autotag  
|  |- blacklist  
|  |- devmode  
|  |- readorder  
|  |- motd 
|  |- pagesize  
|  |- dirname  
|  |- htmltitle 
|  +- enablepass <- Enable/Disable Password Authentication. 
|
+- LRR_JSONCACHE <- JSON Cache Storage
   |- force_refresh <- If set to 1, Shinobu will rebuild the cache on its next iteration.
   |- archive_list <- JSON
   +- archive_count <- Number of archives in content folder. If the actual number differs from this saved value, a rebuild will be triggered.
```

