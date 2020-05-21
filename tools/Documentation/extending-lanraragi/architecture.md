---
description: Read up on all the badly hacked nitty gritty that makes LRR tick here.
---

# Architecture & Style

## Installation Script

The _install.pl_ script is essentially a sequence of commands executed to install the backend and frontend dependencies needed to run LRR, as well as basic environment checks.

## Specific environment variables you can apply to change LRR behavior

Those variables were introduced for the Homebrew package, but they can be declared at anytime on any type of install; LRR will try to use them.

* `LRR_DATA_DIRECTORY` - Data directory override. If this variable is set to a path, said path will house the content folder.  
* `LRR_TEMP_DIRECTORY` - Temporary directory override. If this variable is set to a path, the temporary folder will be there instead of `/public/temp`.
* `LRR_LOG_DIRECTORY` - Log directory override. Changes the location of the `log` folder.  
* `LRR_FORCE_DEBUG` - Debug Mode override. This will force Debug Mode to be enabled regardless of the user setting.
* `LRR_NETWORK` - Network Interface. See the dedicated page in Advanced Operations.  

## Coding Style

While Perl's mantra is "There's more than one way to do it", I try to make LRR follow the PBP, aka Perl Best Practices.  
This is done by the use of the [Perl::Critic](https://metacpan.org/pod/Perl::Critic) module, which reports PBP violations.  
If installed, you can run the critic on the entire LRR source tree through the `npm run critic` shortcut command.  
Critic is automatically run on every commit made to LRR at the level 5 thanks to [Github Actions](https://github.com/Difegue/LANraragi/blob/dev/.github/main.workflow).

I also run [perltidy](https://en.wikipedia.org/wiki/PerlTidy) on the source tree every now and then for consistency.  
The rules used in perltidy passes are stored in the .perltidyrc file at the source root.

Some extras:

* Code width limit is stupid for long strings and comments \(ie the base64 pngs in plugin metadata\), which is perltidy's default behavior.
* The visual indentation when setting a bunch of variables at once a perltidy thing, but I actually really like it! I leave it in and try to repro it whenever it makes sense.
* The codebase does have issues with variable naming -- perl packages usually go for snakecase buuut short variables are ok in flatcase \(as per [perlstyle](https://perldoc.perl.org/perlstyle.html) \)
* `'`'s should only be used for escaping `"` easily and vice-versa but I don't really care about that one. 😐

A small practice I try to keep on my own for LRR's packages is to use methods \(arrow notation, `Class::Name->do_thing`\) to call subroutines that take no arguments, and functions \(namespace notation, `Class::Name::do_thing($param)`\) to call subs with arguments. It doesn't really matter much, but it looks cleaner to me!  
Also makes it easier if one day I take the OOP pill for this project, as methods always get the current object \(or class name\) as the first parameter of their call.

Packages in the `Utils` folder export most of their functions, as those are used by Plugins as well.  
I recommend trying to only use exported functions in your code, and consider the rest as internal API suspect to change/breakage.

## Main App Architecture

```text
root/
|- .github       <- Github-specific files
|  |- action-run-tests <- Run the LRR Test Suite
|  |- ISSUE_TEMPLATE   <- Template for bug reports
|  |- workflows        <- Github Actions workflows
|     |- CD               <- Continuous Delivery, Nightly builds
|     |- CI               <- Tests
|     +- Release          <- Build latest and upload .zip to release post on GH
|  +- FUNDING.yml      <- Github Sponsors file
|
|- content       <- Default content folder
|
|- lib           <- Core application code
|  |- LANraragi.pm  <- Entrypoint for the app, contains basic startup code and routing to Controllers
|  |- Shinobu.pm    <- Background Worker (see below)
|  +- LANraragi
|     |- Controller <- One Controller per page
|        +- *.pm       <- Index, Config, Reader, Api, etc.
|     |- Model      <- Application code that doesn't rely on Mojolicious
|        |- Api.pm     <- Api business implementation
|        |- Backup.pm  <- Encodes/Decodes Backup JSONs
|        |- Config.pm  <- Communicates with the Redis DB to store/retrieve Configuration
|        |- Plugins.pm <- Executes Plugins on archives
|        |- Reader.pm  <- Archive Extraction
|        |- Search.pm  <- Search Engine
|        +- Stats.pm   <- Tag Cloud and Statistics
|     +- Plugin     <- LRR Plugins are stored here
|        |- Login
|        |- Metadata
|        +- Scripts
|     +- Utils      <- Generic Functions
|
|- log           <- Application Logs end up here
|
|- public        <- Files available to Web Clients
|  |- css           <- Global CSS sheets
|     |- lrr.css
|     +- vendor        <- Third-party CSS sheets obtained through NPM
|  |- img           <- Image resources
|  |- js            <- JavaScript functions
|     |- *.js
|     +- vendor        <- Third-party JS obtained through NPM
|  |- temp          <- Archives are extracted in this folder to be served to clients. Also used for thumbnail creation.
|  +- themes        <- Contains CSS sheets for Themes.
|
|- script
|  |- backup        <- Standalone script for running database backups.
|  |- launcher.pl   <- Launcher, uses either Morbo or Hypnotoad to run the bootstrap script
|  +- lanraragi     <- Bootstrap script, starts LANraragi.pm
|
|- tests         <- Tests go here
|
|- templates     <- Templates for Web pages
|  +- *.html.tt2
|
|- tools         <- Contains scripts for building and installing LRR.
|  |- Documentation <- What you're reading right now
|  |- build         <- Build tools and scrpits
|     |- windows          <- Windows build script and submodule link to the Karen WPF Bootstrapper
|     |- docker           <- Dockerfile and configuration files for LRR Docker Container
|     |- homebrew         <- Script and configuration files for the LRR Homebrew cask
|     |- vagrant          <- Vagrantfile for LRR Vagrant Machine
|  |- cpanfile      <- Perl dependencies description
|  |- install.pl    <- LANraragi Installer
|  |- lanraragi-systemd.service <- Example SystemD service
|  +- logo.png      <- Self-explanatory
|
|- lrr.conf      <- Mojolicious configuration file
|- .shinobu-pid  <- Last known PID of the Background Worker
|- .perltidy.rc  <- PerlTidy config file to match the coding style
+- package.json  <- NPM file, contains front-end dependency listing and shortcuts
```

## Background Worker Architecture

The Shinobu Background Worker runs in parallel of the LRR Mojolicious Server and handles various tasks repeatedly:

* Scanning the content folder for new archives using inotify watches
* Adding new archives and executing Plugins on them if enabled
* Regenerates the JSON cache when metadata or archive count changes

It's a second process spawned through the Proc::Background Perl Module.

## About the Search Cache

When you perform a search in LRR, that search is saved to a cache in order to be served faster the next time it's queried.  
This cache is busted as soon as the archive index is modified in any way.\(be it editing metadata or adding/removing archives\)

## Behaviour in Debug Mode

In Debug Mode, the Mojolicious server auto-restarts on every file modification.  
You also get access to the Mojolicious logs in LRR's built-in Log View. More logs are also published when in Debug mode.

## Database Architecture

You can look inside the LRR Redis database at any moment through the `redis-cli` tool.

The base architecture is as follows:

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
|  |- apikey
|  |- fav1/5 <- Favorite tags, if set by the user.
|  +- enablepass <- Enable/Disable Password Authentication.
|
+- LRR_SEARCHCACHE <- Search Cache
   |- $columnfilter-$filter-$sortkey-$sortorder-$newonly <- Unique ID for a search. The search result is serialized and saved as the value for this ID.
   +- --title-asc-0 <- Example ID for a search made on titles with no filters.
```

{% hint style="info" %}
The archive IDs computed by LRR are created by taking the first 500KBs of the file, and computing a SHA-1 hash from this data.

You can find the code used for the calculation in _LANraragi::Utils::Database_.
{% endhint %}

