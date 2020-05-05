# Using external readers

If the built-in Web Reader is not enough for you, LANraragi's content can be consumed by multiple external applications who provide their own readers.  

## Dedicated LANraragi readers  

Dedicated LANraragi readers use the Client API to provide an experience closely matching the capabilities of the Web interface.  

{% page-ref page="../extending-lanraragi/client-api.md" %}

Here are some existing clients:

### [Ichaival \(Android\)](https://github.com/Utazukin/Ichaival)  

[Download it here.](https://github.com/Utazukin/Ichaival)  
![ichaival](../.gitboook/assets/ichaival.png)

**Features:**  

* View and search your LANraragi database  
* View tags  
* Read archives  
* Bookmark archives to keep track of your current page  
* Sort archives by date (requires archives to be tagged with the DateAdded plugin)  

### [LRReader \(Windows 10\)](https://github.com/Guerra24/LRReader)  

[Download it here.](https://github.com/Guerra24/LRReader)  
![lrreader](https://s3.guerra24.net/projects/lrr/screenshots/01.png)

**Features:**

* Archives list.
* Search.
* Archive overview and reader.
* Bookmarks.
* Multiple servers/profiles.
* Manage your server from within the app.

### Tachiyomi reader  

![Tachiyomi](../.gitbook/assets/tachiyomi.jpg)

The open-source [Tachiyomi](https://tachiyomi.org/) Android reader has a readymade plugin to consume the LANraragi API.  
You can download it [here.](https://github.com/inorichi/tachiyomi-extensions/blob/repo/apk/tachiyomi-all.lanraragi-v1.2.1.apk)

## Generic OPDS readers  

![Example OPDS reader](../.gitbook/assets/opds.jpg)

Some readers can leverage the [OPDS Catalog](https://opds.io/) exposed by LANraragi to visualize and read the available archives.  
Those programs can't exploit all of LRR's features(Search, Database backup, Streaming images), but they might have reading features you won't find in the current dedicated clients.  

The URL for the OPDS Catalog is `[YOUR_LANRARAGI_URL]/api/opds`.  
You can use [the Demo](https://lrr.tvc-16.science/api/opds) as an example.  
Refer to your reader's documentation to figure out where to put this URL.  

{% hint style="warning" %}
If you have No-Fun Mode enabled, remember that you'll need to add the API Key to this URL for the catalog to be available to your reader application.  
{% endhint %}

The following readers have been tested with the OPDS Catalog:  

* **[Moon+ Reader \(Android\)](https://play.google.com/store/apps/details?id=com.flyersoft.moonreader)**  

* **[Librera Reader \(Android\)](https://librera.mobi/)**  

* **[Challenger Comics Viewer \(Android\)](https://play.google.com/store/apps/details?id=org.kill.geek.bdviewer)**  

* **[AlfaReader \(Windows 7/8/10\)](https://www.alfareader.org)**  

The following readers haven't been tested but should work:  

* **[TiReader (iOS)](http://tireader.com/)**  

* **[Chunky Reader (iOS)](http://chunkyreader.com/)**  
