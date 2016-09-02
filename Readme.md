LANraragi
============

Web interface and reader for storage of comics/manga on NAS, running on Perl/Redis/unar with a dash of Imagemagick and Bower.  
You can find a demo [here](http://faglord.party/lanraragi).

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

![](https://my.mixtape.moe/owobfn.png)

	
##Hotdog ! How do I install this ?  
You can find a basic installation guide [here](https://github.com/Difegue/LANraragi/blob/master/tools/Install.md) for Linux machines.  

##Docker Installation
A Docker image exists for deploying LANraragi installs to your machine easily without disrupting your already-existing web server setup.(Or installing on Windows/Mac.)  
Download [the Docker setup](https://www.docker.com/products/docker) and install it. Once you're done, get the CLI out :  
```
docker run --name=lanraragi -p 8080:80 -v [YOUR_ARCHIVE_DIRECTORY]:/var/www/lanraragi/content difegue/lanraragi

```
Setting in your own archive directory. This directory will contain archives you either upload through the app or directly drop in.  

On OSX, you should use something like :  
```
/Users/<path>
```  
And on Windows :  
```
/c/Users/<path>
```  
Once your LANraragi container is loaded, you can access it at http://localhost:8080/lanraragi](http://localhost:8080/lanraragi) .  
You can use the following commands to stop/start/remove the container(Removing it won't delete the archive directory you specified) : 
```
docker stop lanraragi
docker start lanraragi
docker rm lanraragi
```  

This whole setup gets the LANraragi container from the Docker Hub, but you can roll your own by downloading [the Docker setup](https://github.com/Difegue/LANraragi/raw/master/tools/DockerSetup) and executing :
```
docker build -t whateverthefuckyouwant/lanraragi [PATH_TO_THE_DOCKERFILE]
```  

##Vagrant Installation 
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

The Vagrant setup automatically gets the latest revision from the git repo and grabs bower dependencies on its own. If the current development version has issues or the bower dependencies fail, please use the files from one of [the releases](https://github.com/Difegue/LANraragi/releases).

##I got me a setup, how do I use this ?
First, login with the default admin password (kamimamita), and hit the configuration page.  
There are multiple settings you can change, including but not limited to the content folder, your password or the reading order.
Afterwards, add your archives in the content folder or through the upload page, and it just works™


##Potential roadmap for when I feel motivated enough to take this up again    

* Use Gulp for bundling front-end dependencies on top of bower  

* Database backup/restoration  

* Moving away from CGI

