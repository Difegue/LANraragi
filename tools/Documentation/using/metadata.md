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