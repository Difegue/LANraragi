LANraragi
============

Web interface and reader for storage of comics/manga on NAS, running on Perl/Redis/unar. (Imagemagick optional.)  

![](https://a.pomf.cat/vpqvmq.png)
*Comes in various flavors, from flat design apologist to sad panda.*  

##Features

* Stores your comics in archive format. (zip/rar/targz/lzma/7z/xz/cbz/cbr supported)  

* Read archives directly from your web browser: they're extracted automatically when you want to read them, and deleted when you're done. 

* Paged archive list with thumbnails-on-hover.  
![](https://a.pomf.cat/jooipu.png)

* Choose from 5 preinstalled library styles, or add your own with CSS.      

* Tag support: Add your own or import them from predefined sources when possible. Batch Tagging available !  

* Responsive, so you can read on your phone/tablet when taking a shit.  

![](https://a.pomf.cat/czkfyn.png)
*I tried to run it on a 3DS but the page was too heavy （´・ω・｀）*  

	
##Hotdog ! How do I install this ?  
You can find a basic installation guide [here](https://github.com/Difegue/LANraragi/blob/master/tools/Install.md) for Linux machines.  

##But I don't run Linux, got anything for me ?  
Got you covered ! Kind of.  
I wrote a Vagrantfile you can use with [Vagrant](https://www.vagrantup.com/downloads.html) to deploy a virtual machine on your computer with LANraragi preinstalled.  
Download [the Vagrant setup](https://github.com/Difegue/LANraragi/raw/master/tools/VagrantSetup) somewhere, and whip out a terminal :
```
vagrant plugin install vagrant-vbguest
vagrant up
```
Once it's deployed(it takes a while to download everything), you'll have a /lanraragi folder, which syncs to an install located at [http://localhost:8080/lanraragi](http://localhost:8080/lanraragi) .  
You can use 
```
vagrant halt
```  
to stop the VM when you're done.

##I got me a setup, how do I use this ?
config.pl contains a lot of variables you can define yourself. They're properly explained in the file itself, be sure to check it out.  
After that, just add your archives in the content folder, and it just works™


##Roadmap(jk this is never getting done)  

* Use Gulp for bundling front-end dependencies on top of bower  

* Tag overhaul with proper prefixes like language:english etc

* Reader overhaul because it's old and kinda bloated  



