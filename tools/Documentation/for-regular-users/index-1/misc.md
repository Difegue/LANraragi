# Other Options

## Themes

The front-end interface of LANraragi is customizable out of the box through CSS.  
A few themes are built-in already. Theme Preference is saved on a per-user basis.

To change Theme, click the matching button on the footer of every page:  
![](https://a.pomf.cat/gpuqyn.PNG)

You can write your own themes by modifying the existing ones - Dropping them in the _/public/themes_ folder will make them selectable by anyone. \(For Docker/Vagrant Users who don't have access to the LRR folder - We're working on something.\)

## Database Backup/Restore

Right as it says on the tin. This page allows you to backup the entire database to a JSON file.  
This includes, for every file:

* The unique ID of the archive \(For the more technologically-enclined: LRR uses a SHA-1 hash of the first 512KBs of the file as the ID\)
* The saved tags 
* The saved title 

This JSON can then be restored in another LRR instance, if it has archives with matching unique IDs.

## Statistics

This page shows basic stats about your content folder, as well as your most used tags.  
![](https://a.pomf.cat/weotok.PNG)

## Logs

This page allows you to quickly see logs from the app, in case something went wrong.  
If you enable _Debug Mode_ in Configuration, more logs will be displayed.

{% hint style="warning" %}
If you enable Debug Mode for troubleshooting purposes, make sure to disable it once you're done!
{% endhint %}

## Favorite Tags

In Configuration, you can set five tags as your **favorites**.  
They'll appear in the archive index as shortcut buttons, which you can toggle to instantly perform a search for said tag.  
Toggling multiple buttons at once is an OR operation, not an AND -- Selecting _jojo_ and _touhou_ will give you archives containing one or both of those tags.

{% hint style="info" %}
If you do want AND searches in your favorites, you can do so using a quick regex:  
`jojo.*touhou` for instance, will only search for archives containing both those tags.
{% endhint %}

