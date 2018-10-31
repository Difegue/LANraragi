# Dealing with Archives

## Content Folder

One of LRR's core concepts is the **content folder.**  
This folder contains all the user-generated data:

* Archives \(in zip/rar/targz/lzma/7z/xz/cbz/cbr format\)  
* Thumbnails for said archives
* The Redis database \(_Docker/Vagrant only_\)  

By default, this folder is placed at the root of the LRR installation, but you can configure it to use any folder on your machine instead.

You can add archives to the application by either copying them to the content folder, or using the built-in uploader tool.  
They'll be automatically indexed and added to the database.  
Plugins will also be ran automatically to try and fetch metadata for them, if enabled. \(See the "Importing Metadata" section for more information.\)

{% hint style="info" %}
If you plan on setting your content folder to a folder that already contains archives, you might want to enable **Plugin Auto-Execution** beforehand, so that metadata will be fetched for your files as they're added. 

You can still do it afterwards on a per-archive basis.
{% endhint %}

When reading an archive, it is automatically extracted to a temporary folder.  
This folder is then simply loaded into the built-in Web Reader.

## Reader Options

In the reader, you can use the keyboard arrows or the built-in arrow icons to move from page to page.  
You can also simply click the right or left side of the image.  
When reading an archive, the three button icons on the rightside of the page offer various options.  


![](https://a.pomf.cat/tdqtur.JPG)

You can click the information icon on the right-side of the Reader to get a quick refresher about its controls.  
The Reader Options button shows the various options you can toggle to change the reading experience. \(Double page, Japanese read order, etc.\)

The Page Overlay button \(also actionable by pressing CTRL\) will show all the pages of the currently opened archive, allowing for quick navigation and preview.  


![Reader with overlay](https://raw.githubusercontent.com/Difegue/LANraragi/dev/tools/_screenshots/reader_overlay.jpg)

Automatic bookmarking is also present: When reopening the archive, it'll show you the page you last stopped at.

