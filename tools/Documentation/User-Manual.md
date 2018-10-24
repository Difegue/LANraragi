- [First Steps and Configuration](#first-steps-and-configuration)
- [Adding and Reading Archives](#adding-and-reading-archives)
- [Reader Options](#reader-options)
- [Importing Metadata (Plugins)](#importing-metadata-plugins)
- [Other Options](#other-options)
  * [Themes](#themes)
  * [Database Backup/Restore](#database-backup-restore)
  * [Statistics](#statistics)
  * [Logs](#logs)
  * [Favorite Tags](#favorite-tags)


If you're reading this, you're probably in front of a freshly-unboxed LANraragi installation.  
Here are a few guidelines to make the most out of it.

## First Steps and Configuration

**Hot Tip** : If you want to change the used Redis address/database (the defaults are good enough for 98% of people), you can do so by editing the lrr.conf file at the root.

The first step you'll probably do is head to the Configuration page to change/disable the default password.  

When logged in as Admin in LRR, you have access to the full functionalities of the app.  
Unlogged users can only read (and download) archives that are already on the server.  

If you're running the app on a server that's potentially accessible by others, I recommend leaving password protection enabled and changing the default password. (Although there's already a big red popup to remind you of that, you can't really say it enough)  

Besides password protection, the Configuration page has a few detailed lesser settings you can tweak at will.  

## Adding and Reading Archives

One of LRR's core concepts is the **content folder.**  
This folder contains all the user-generated data:  
- Archives (in zip/rar/targz/lzma/7z/xz/cbz/cbr format)  
- Thumbnails for said archives
- The Redis database (_Docker/Vagrant only_)  

By default, this folder is placed at the root of the LRR installation, but you can configure it to use any folder on your machine instead.  

You can add archives to the application by either copying them to the content folder, or using the built-in uploader tool.  
They'll be automatically indexed and added to the database.  
Plugins will also be ran automatically to try and fetch metadata for them, if enabled. (See the "Importing Metadata" section for more information.)  
 
**Hot Tip** : If you plan on setting your content folder to a folder that already contains archives, you might want to enable said Plugin auto-execution beforehand, so that metadata will be fetched for your files as they're added. You can still do it afterwards on a per-archive basis.

When reading an archive, it is automatically extracted to a temporary folder.  
This folder is then simply loaded into the built-in Web Reader.  

## Reader Options

In the reader, you can use the keyboard arrows or the built-in arrow icons to move from page to page.  
You can also simply click the right or left side of the image.  
When reading an archive, the three button icons on the rightside of the page offer various options.  
![](https://a.pomf.cat/tdqtur.JPG)  

You can click the information icon on the right-side of the Reader to get a quick refresher about its controls.  
The Reader Options button shows the various options you can toggle to change the reading experience. (Double page, Japanese read order, etc.)

The Page Overlay button (also actionable by pressing CTRL) will show all the pages of the currently opened archive, allowing for quick navigation and preview.  
![Reader with overlay](https://raw.githubusercontent.com/Difegue/LANraragi/dev/tools/_screenshots/reader_overlay.jpg)  

Automatic bookmarking is also present: When reopening the archive, it'll show you the page you last stopped at.

## Importing Metadata (Plugins)

LANraragi supports the use of **Plugins** to fetch tags for your archives.  
Said Plugins can be used in two different ways:

- On a per-archive basis
- Automatically on every newly added archive.  

To use a plugin on a single archive, you need to access its **editing** page by clicking the pencil icon on the main view.  
![](https://a.pomf.cat/wuspdt.PNG)  

To use plugins automatically, you need to enable the option in Configuration first.  
![](https://a.pomf.cat/wvarmm.PNG)  
Once this is done, you can use the **Plugin Configuration** page to choose which plugins will be automatically executed, and set their options if they need any.  
![](https://a.pomf.cat/mpwcti.PNG)  

LRR ships with a few plugins out of the box, in the _/lib/LANraragi/Plugins_ folder.  
To install other Plugins (in .pm format), drag them to this folder and they'll appear in Plugin Configuration. 
 
You can also install Plugins through the "Install Plugin" button in Plugin Configuration.  
This feature requires Debug Mode to be enabled for security purposes. Debug Mode can be disabled once you're done installing Plugins.

**Hot Tip** : Plugins have as much control over your system as the main LANraragi application does! When installing Plugins from unknown sources, do a little research first. 

## Other Options

### Themes

The front-end interface of LANraragi is customizable out of the box through CSS.  
A few themes are built-in already. Theme Preference is saved on a per-user basis.  

To change Theme, click the matching button on the footer of every page:  
![](https://a.pomf.cat/gpuqyn.PNG)  

You can write your own themes by modifying the existing ones - Dropping them in the _/public/themes_ folder will make them selectable by anyone. (For Docker/Vagrant Users who don't have access to the LRR folder - We're working on something.)

### Database Backup/Restore

Right as it says on the tin. This page allows you to backup the entire database to a JSON file.  
This includes, for every file:  
- The unique ID of the archive (For the more technologically-enclined: LRR uses a SHA-1 hash of the first 512KBs of the file as the ID)
- The saved tags 
- The saved title 

This JSON can then be restored in another LRR instance, if it has archives with matching unique IDs.

### Statistics

This page shows basic stats about your content folder, as well as your most used tags.  
![](https://a.pomf.cat/weotok.PNG)  

### Logs

This page allows you to quickly see logs from the app, in case something went wrong.  
If you enable _Debug Mode_ in Configuration, more logs will be displayed.  

**Hot Tip** : If you enable Debug Mode for troubleshooting purposes, make sure to disable it once you're done!

### Favorite Tags

In Configuration, you can set five tags as your **favorites**.  
They'll appear in the archive index as shortcut buttons, which you can toggle to instantly perform a search for said tag.  
Toggling multiple buttons at once is an OR operation, not an AND -- Selecting _jojo_ and _touhou_ will give you archives containing one or both of those tags.

**Hot Tip** : If you do want AND searches in your favorites, you can do so using a quick regex:  
```jojo.*touhou``` for instance, will only search for archives containing both those tags.
