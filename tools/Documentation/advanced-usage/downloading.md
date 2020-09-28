---
description: >-
  Download remote URLs directly to LANraragi!
---

# Downloading Archives

Starting with version 0.7.3, LANraragi can directly download URLs to its content folder.  
This allows you to seamlessly add archives from the Internet to your LRR instance for safekeeping.

![Upload Center with a PDF downloaded](../.gitbook/assets/download.png)  

By default, we will try to download any URL you chuck at us! This will mostly work for simple URLs that point directly to a file we support.  
(For example, something like this very nice Quake booklet: https://archive.org/download/quake-essays-sep-15-fin-4-graco-l-cl/QUAKE_essays_SEP15_FIN4_GRACoL_CL.pdf will download without a fuss.)  

For non-direct links, you will need to have a matching **Downloader Plugin** configured.  
LANraragi currently ships with Downloaders handling E-H and Chaika links.  

![Downloader Plugins](../.gitbook/assets/downloaders.png)  

{% hint style="info" %}
Just like with Metadata plugins, Downloaders might require using a matching **Login Plugin** to authenticate to the remote website.
{% endhint %}
