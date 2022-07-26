---
description: Read up on all the badly hacked nitty gritty that makes LRR tick here.
---

# 🏛 Architecture & Style

## Installation Script

The _install.pl_ script is essentially a sequence of commands executed to install the backend and frontend dependencies needed to run LRR, as well as basic environment checks.

## Specific environment variables you can apply to change LRR behavior

Those variables were introduced for the Homebrew package, but they can be declared at anytime on any type of install; LRR will try to use them.

* `LRR_DATA_DIRECTORY` - Data directory override. If this variable is set to a path, said path will house the content folder.
* `LRR_THUMB_DIRECTORY` - Thumbnail directory override. If this variable is set to a path, said path will house the generated archive thumbnails.
* `LRR_TEMP_DIRECTORY` - Temporary directory override. If this variable is set to a path, the temporary folder will be there instead of `/public/temp`.
* `LRR_LOG_DIRECTORY` - Log directory override. Changes the location of the `log` folder.
* `LRR_FORCE_DEBUG` - Debug Mode override. This will force Debug Mode to be enabled regardless of the user setting.
* `LRR_NETWORK` - Network Interface. See the dedicated page in Advanced Operations.

## Coding Style

While Perl's mantra is "There's more than one way to do it", I try to make LRR follow the PBP, aka Perl Best Practices.  
This is done by the use of the [Perl::Critic](https://metacpan.org/pod/Perl::Critic) module, which reports PBP violations.  
If installed, you can run the critic on the entire LRR source tree through the `npm run critic` shortcut command.  
Critic is automatically run on every commit made to LRR at the level 5 thanks to [GitHub Actions](../../../.github/main.workflow).

I also run [perltidy](https://en.wikipedia.org/wiki/PerlTidy) on the source tree every now and then for consistency.  
The rules used in perltidy passes are stored in the .perltidyrc file at the source root.

Some extras:

* Code width limit is stupid for long strings and comments (ie the base64 pngs in plugin metadata), which is perltidy's default behavior.
* The visual indentation when setting a bunch of variables at once a perltidy thing, but I actually really like it! I leave it in and try to repro it whenever it makes sense.
* The codebase does have issues with variable naming -- perl packages usually go for snakecase buuut short variables are ok in flatcase (as per [perlstyle](https://perldoc.perl.org/perlstyle.html) )
* `'`'s should only be used for escaping `"` easily and vice-versa but I don't really care about that one. 😐

A small practice I try to keep on my own for LRR's packages is to use methods (arrow notation, `Class::Name->do_thing`) to call subroutines that take no arguments, and functions (namespace notation, `Class::Name::do_thing($param)`) to call subs with arguments. It doesn't really matter much, but it looks cleaner to me!\
Also makes it easier if one day I take the OOP pill for this project, as methods always get the current object (or class name) as the first parameter of their call.

Packages in the `Utils` folder export most of their functions, as those are used by Plugins as well.  
I recommend trying to only use exported functions in your code, and consider the rest as internal API suspect to change/breakage.

## Main App Architecture

```
root/
|- .devcontainer <- VSCode setup files for Codespaces
|- .github       <- GitHub-specific files
|  |- action-run-tests <- Run the LRR Test Suite
|  |- ISSUE_TEMPLATE   <- Template for bug reports
|  |- workflows        <- GitHub Actions workflows
|     |- CD               <- Continuous Delivery, Nightly builds
|     |- CI               <- Tests
|     +- Release          <- Build latest and upload .zip to release post on GH
|  +- FUNDING.yml      <- GitHub Sponsors file
|
|- content       <- Default content folder
|
|- lib           <- Core application code
|  |- LANraragi.pm  <- Entrypoint for the app, contains basic startup code and routing to Controllers
|  |- Shinobu.pm    <- Background Worker (see below)
|  +- LANraragi
|     |- Controller <- One Controller per page
|     |  |- Api     <- API implementation
|     |  |  +- ...   
|        +- *.pm       <- Index, Config, Reader, etc.
|     |- Model      <- Application code that doesn't rely on Mojolicious
|        |- Archive.pm <- Serve files from archives and OPDS catalog
|        |- Backup.pm  <- Encodes/Decodes Backup JSONs
|        |- Category.pm <- Save/Read Category data
|        |- Config.pm  <- Communicates with the Redis DB to store/retrieve Configuration
|        |- Plugins.pm <- Executes Plugins on archives
|        |- Reader.pm  <- Archive Extraction
|        |- Search.pm  <- Search Engine
|        |- Stats.pm   <- Tag Cloud and Statistics
|        +- Upload.pm  <- Handle incoming files (Download System)
|     +- Plugin     <- LRR Plugins are stored here
|        |- Login
|        |- Metadata
|        +- Scripts
|     +- Utils      <- Generic Functions
|        |- *.pm 
|        +- Minion.pm <- Minion jobs are implemented here
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
|  |  |- server.pid <- PID of the currently running Prefork Manager process, if existing
|  |  |- shinobu.pid   <- Last known PID of the Shinobu File Watcher (Serialized Proc::Simple object)
|  |  +- minion.pid    <- Last known PID of the Minion Job Queue (Serialized Proc::Simple object)
|  +- themes        <- Contains CSS sheets for Themes.
|
|- script
|  |- backup        <- Standalone script for running database backups.
|  |- launcher.pl   <- Launcher, uses either Morbo or Prefork to run the bootstrap script
|  +- lanraragi     <- Bootstrap script, starts LANraragi.pm
|
|- tests         <- Tests go here
|
|- templates     <- Templates for Web pages
|  +- *.html.tt2
|
|- tools         <- Contains scripts for building and installing LRR.
|  |- _screenshots  <- Screenshots
|  |- Documentation <- What you're reading right now
|  |- build         <- Build tools and scrpits
|     |- windows          <- Windows build script and submodule link to the Karen WPF Bootstrapper
|     |- docker           <- Dockerfile and configuration files for LRR Docker Container
|     |- homebrew         <- Script and configuration files for the LRR Homebrew cask
|  |- cpanfile      <- Perl dependencies description
|  |- install.pl    <- LANraragi Installer
|  +- lanraragi-systemd.service <- Example SystemD service
|
|- lrr.conf      <- Mojolicious configuration file
|- .perltidy.rc  <- PerlTidy config file to match the coding style
|- .eslintrc.json   <- ESLint config file to match the coding style
+- package.json  <- NPM file, contains front-end dependency listing and shortcuts
```

## Shinobu Architecture

The Shinobu File Watcher runs in parallel of the LRR Mojolicious Server and handles various tasks:

* Scanning the content folder for new archives at start
* Keeping track of new/deleted archives using inotify watches
* Adding new archives to the database and executing Plugins on them if enabled

It's a second process spawned through the Proc::Simple Perl Module.  
Heavier tasks are handled by a [Minion](https://docs.mojolicious.org/Minion) Job Queue, which is much more closely linked to Mojo and basically just werks™

## About the Search Cache

When you perform a search in LRR, that search is saved to a cache in order to be served faster the next time it's queried.  
This cache is busted as soon as the archive index is modified in any way.(be it editing metadata or adding/removing archives)

## Behaviour in Debug Mode

In Debug Mode:

* The Mojolicious server auto-restarts on every file modification,
* Logs are way more detailed,
* You get access to Mojolicious logs in LRR's built-in Log View,
* A Status dashboard becomes available at `http://LRR_URL/debug`.

## Database Architecture

You can look inside the LRR Redis database at any moment through the `redis-cli` tool.

The base architecture is as follows:

```
-Redis Database
|- **************************************** <- 40-character long ID for every logged archive
|  |- tags <- Saved tags
|  |- name <- Name of the archive file, kept for filesystem checks
|  |- title <- Title of the archive, as set by the User
|  |- file <- Filesystem path to archive
|  |- isnew <- Whether the archive has been opened in LRR once or not
|  +- thumbhash <- SHA-1 hash of the first image of the archive
|
|- LRR_PLUGIN_xxxxxxx <- Settings for a plugin with namespace xxxxxxx
|
|- LRR_TOTALPAGESTAT <- Total pages read
|
|- LRR_FILEMAP <- Shinobu Filemap, maps IDs in the database to their location on the filesystem
|
|- SET_xxxxxxxxxx <- A Category.
|
|- LRR_CONFIG <- Configuration keys, usually set through the LRR Configuration page.
|  |- htmltitle
|  |- motd
|  |- dirname  <- Content directory
|  |- thumbdir <- Thumbnail directory  
|  |- tempmaxsize <- Temp folder max size 
|  |- enableresize <- Whether automatic image resizing is enabled  
|  |- sizethreshold <- Auto-resizing threshold
|  |- readerquality <- Auto-resizing quality
|  |- enablecors <- Whether CORS headers are enabled 
|  |- tagruleson <- Whether tag rules are enabled
|  |- tagrules <- Tag rules, saved as a big ol' string
|  |- devmode  <- Whether debug mode is enabled
|  |- enablepass <- Enable/Disable Password Authentication.
|  |- nofunmode <- Whether No-Fun Mode is enabled
|  |- pagesize <- Amount of archives per Index page 
|  +- apikey <- Key for API requests
|
|- LRR_TAGRULES <- Computed Tag Rules, as a Redis list
|
+- LRR_SEARCHCACHE <- Search Cache
   |- $columnfilter-$filter-$sortkey-$sortorder-$newonly <- Unique ID for a search. The search result is serialized and saved as the value for this ID.
   +- --title-asc-0 <- Example ID for a search made on titles with no filters.
```

{% hint style="info" %}
The archive IDs computed by LRR are created by taking the first 512KBs of the file, and computing a SHA-1 hash from this data.

You can find the code used for the calculation in _LANraragi::Utils::Database_.
{% endhint %}
