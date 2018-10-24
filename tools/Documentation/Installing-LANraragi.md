- [For users migrating from 0.4.x versions](#for-users-migrating-from-04x-versions)
- [Docker Installation (Recommended)](#docker-installation-recommended)
  * [Cloning the base LRR image](#cloning-the-base-lrr-image)
  * [Building your own](#building-your-own)
- [Vagrant Installation (Recommended for Dockerless machines)](#vagrant-installation-recommended-for-dockerless-machines)
- [Native Linux Installation](#native-linux-installation)
  * [A small FYI about Vendor Perl](#a-small-fyi-about-vendor-perl)
  * [Needed dependencies](#needed-dependencies)
  * [Installing LRR](#installing-lrr)
- [Automatic Windows Installation](#automatic-windows-installation)
  * [Downloading and running the QuickStarter](#downloading-and-running-the-quickstarter)
  * [What's installed on your machine](#whats-installed-on-your-machine)
- [Manual Windows Installation](#manual-windows-installation)
  * [Needed dependencies](#needed-dependencies-1)
  * [Installing LRR](#installing-lrr-1)
- [Windows Subsystem for Linux Installation](#windows-subsystem-for-linux-installation)

## For users migrating from 0.4.x versions  

The database format having slightly changed (a lot), you'll have to run a migration script if you want to keep your curated database.  
Drag [this script](https://github.com/Difegue/LANraragi/blob/master/tools/migrate-database.pl) to your 0.4 install folder, and execute it:
`perl migrate-database.pl 127.0.0.1:6379 0`  

Replace 127.0.0.1:6379 and 0 by your Redis address and Database number respectively (if you don't know those leave the above defaults).  
The script will produce a json file you'll be able to reimport into a 0.5 install. (Only after said 0.5 has recognized your archive files.)

## Docker Installation (Recommended)

A Docker image exists for deploying LANraragi installs to your machine easily without disrupting your already-existing web server setup.  
It also allows for easy installation on Windows/Mac !  

### Cloning the base LRR image

Download [the Docker setup](https://www.docker.com/products/docker) and install it. Once you're done, execute:  
``
docker run --name=lanraragi -p 3000:3000 --mount type=bind,source=[YOUR_CONTENT_DIRECTORY],target=/home/koyomi/lanraragi/content difegue/lanraragi
``  

**Hot Tip** : You can tell Docker to auto-restart the LRR container by adding the `--restart always` flag to this command.  

The content directory you have to specify in the command above will contain archives you either upload through the software or directly drop in, alongside generated thumbnails. (Standard behavior)

It will also house the LANraragi database(As database.rdb). This is **exclusive** to the Docker installation, as it allows the user to hotswap containers without losing any data.

Docker can only access drives you allow it to, so if you want to setup in a folder on another drive, be sure to give Docker access to it.  

Once your LANraragi container is loaded, you can access it at [http://localhost:3000](http://localhost:3000) .  
You can use the following commands to stop/start/remove the container(Removing it won't delete the archive directory you specified) : 
```
docker stop lanraragi
docker start lanraragi
docker rm lanraragi
```  
The previous command doesn't specify a version, so Docker will by default pull the _latest_ tag, which matches the latest stable release.  

[Tags](https://hub.docker.com/r/difegue/lanraragi/tags/) exist for major releases, so you can use those if you want to run another version:  
``
docker run [yadda yadda] difegue/lanraragi:0.4.0
``  

Or if you're feeling **extra dangerous**, you can run the last files directly from the _dev_ branch of the Git repo through the _nightly_ tag:  
``
docker run [zoinks] difegue/lanraragi:nightly
``


### Building your own

The previous setup gets a working LANraragi container from the Docker Hub, but you can build your own bleeding edge version by executing ``npm run docker-build``  from a cloned Git repo.  

This will use your cloned Git repo to build the image, modifications you might have made included.  

Of course, this requires a Docker installation.  
If you're running WSL(which can't run Docker natively), you can directly use the Docker for Windows executable with a simple symlink: 
`sudo ln -s '/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe' /usr/local/bin/docker`

## Vagrant Installation (Recommended for Dockerless machines)

You can use the available Vagrantfile with [Vagrant](https://www.vagrantup.com/downloads.html) to deploy a virtual machine on your computer with LANraragi preinstalled.  
Download [the Vagrantfile setup](https://github.com/Difegue/LANraragi/raw/master/tools/VagrantSetup) and put it in your future LANraragi folder, and enter the following commands in a terminal pointed to that folder:
```
vagrant plugin install vagrant-vbguest
vagrant up
```
Once the Vagrant machine is up and provisioned, you can access LANraragi at [http://localhost:3000](http://localhost:3000).  
Archives you upload will be placed in the directory of the Vagrantfile.  

The Vagrant machine is a simple Docker wrapper, so the database will also be stored in this directory. (As database.rdb)

You can use `` vagrant halt `` to stop the VM when you're done. To start it up again, use `` vagrant up ``.

Keep in mind that the Vagrant setup, just like Docker, will always use the latest files from Git.

## Native Linux Installation

The following instructions are based on **Debian Stretch.**

### A small FYI about Vendor Perl

As you might have noticed, LANraragi entirely depends on the Perl programming language.  
A version of Perl usually ships already compiled on most Linux distributions. It's usually called "Vendor Perl".  

Using vendor Perl is [generally discouraged](http://www.modernperlbooks.com/mt/2012/01/avoiding-the-vendor-perl-fad-diet.html) due to possible fuck-ups by the Linux distribution creator.  
As such, you might want to install LANraragi with your own compiled Perl, using a tool such as [Perlbrew](https://perlbrew.pl/).  

And this is just fine! However, I'll consider we're using Vendor Perl here, for the following reasons:  
* The Debian Vendor Perl works flawlessly with LANraragi, and due to Debian being one of the most used Linux distros, it's likely users can just use it as-is and avoid losing an hour building their own Perl.  
* The [PerlMagick](http://search.cpan.org/~jcristy/PerlMagick-6.89-1/Magick.pm) package, required by LRR, needs the ImageMagick source headers to be built.  
As such, it's not automatically installed by our installer scripts. Vendor Perl users can just install the prebuilt version from Apt. Perlbrew/Plenv users will have to download said headers and build it on their own.

### Needed dependencies

```  
apt-get update
apt-get upgrade -y
apt-get install build-essential make gnupg cpanminus redis-server unar imagemagick libimage-magick-perl libssl-dev zlib1g-dev
```  
_Base software dependencies._  

(Once again, if running under a non-vendor Perl, you'll have to build the [Image::Magick](http://search.cpan.org/~jcristy/PerlMagick-6.89-1/Magick.pm) Perl library on your own. This can usually be done by installing the [ImageMagick source headers](https://packages.debian.org/wheezy/armhf/libdevel/libmagickcore-dev) then building the library through cpanm: `cpanm Image::Magick` )


```  
curl -sL https://deb.nodesource.com/setup_9.x | bash -
apt-get install -y nodejs
```  
_Node.js and NPM._

### Installing LRR 

All you need to do is clone the git repo somewhere (or download one of [the releases](https://github.com/Difegue/LANraragi/releases)) and run the installer.  
I recommend doing this with a brand new Linux user account. (I'm using "koyomi" here):  

```  
git clone -b master http://github.com/Difegue/LANraragi /home/koyomi/lanraragi
cd /home/koyomi/lanraragi && sudo npm run lanraragi-installer install-full
```  
Once this is done, you can get started by running ``npm start`` and opening [http://localhost:3000](http://localhost:3000).  

**Hot Tip** : By default, LRR listens on all IPv4 Interfaces on port 3000. You can change this by setting your wished listen location as a parameter of ``npm start``:  
```
npm start http://127.0.0.1:8000

> LANraragi@0.5.0 start /mnt/c/Users/Tamamo/Desktop/lanraragi
> perl ./script/lanraragi daemon -l "http://127.0.0.1:8000"

ｷﾀ━━━━━━(ﾟ∀ﾟ)━━━━━━!!!!!
[LANraragi] LANraragi 0.5.0 (re-)started. (Production Mode)
[...]
[Mojolicious] Listening at "http://127.0.0.1:8000"
```
All listen locations [supported by "listen" in Mojo::Server::Daemon](http://www.mojolicious.org/perldoc/Mojo/Server/Daemon#listen) are valid.

## Automatic Windows Installation   

With the Mojolicious port, all of LANraragi's software dependencies have working Windows versions, making native installs now possible!

ℹ **Small Warning as of 0.5.3:**  
Mojolicious has [dropped official support for Windows](https://metacpan.org/pod/distribution/Mojolicious/lib/Mojolicious/Guides/FAQ.pod#How-well-is-Windows-supported-by-Mojolicious?).  
Native releases will continue to be published and work in the foreseeable future, but you might encounter slight instability.

### Downloading and running the QuickStarter  

Just download the QuickStarter .zip from one of [the releases](https://github.com/Difegue/LANraragi/releases) and extract it somewhere. The folder will look like this:  
```  
berrybrew/
lanraragi/
redis/
unar/
start-lanraragi.bat
```  
Just run the .bat and you're on your way!  
The first launch takes a bit longer due to having to download some more software dependencies.  
No Administrator privileges are required.

### What's installed on your machine  

The QuickStarter downloads a Perl installation to `C:/berrybrew`.  
Apart from that, all data is self-contained in the QuickStarter folder, and can be moved between Windows machines freely.  
The database will be located at the root of the folder, as `dump.rdb`.  
The default content directory will be `/lanraragi/content`, but I would recommend changing it.

## Manual Windows Installation

The steps below allow you to reproduce the automatic installation by hand.  

### Needed dependencies

Download/Install the following MSIs.

* [Perl](https://strawberryperl.com/download/5.26.1.1/strawberry-perl-5.26.1.1-64bit.msi)
* [Redis](https://github.com/MicrosoftArchive/redis/releases/download/win-3.2.100/Redis-x64-3.2.100.msi)
* [Node and NPM](https://nodejs.org/dist/v9.4.0/node-v9.4.0-x64.msi)
* [unar and lsar](https://theunarchiver.com/downloads/unarWindows.zip)

Once Perl is installed, you'll want to run the following command to install PerlMagick: `` ppm install Image-Magick ``

### Installing LRR 

Clone/Download the Git repository somewhere(or download one of [the releases](https://github.com/Difegue/LANraragi/releases)).  
Chock the unar/lsar executables in it, and run `` npm run lanraragi-installer install-full ``. You're done!

You can start LRR by running ``npm start`` and opening [http://localhost:3000](http://localhost:3000).

## Windows Subsystem for Linux Installation

Due to this setup demanding a subsystem usually meant for developers, I wouldn't recommend it for standard users.  
However, it is deceptively simple:  

* Step 1: Install the [Redis Windows Port](https://github.com/MicrosoftArchive/redis/releases/download/win-3.2.100/Redis-x64-3.2.100.msi)
* Step 2: Follow the [Linux Guide](#native-linux-installation) in your WSL terminal.

In this hybrid setup, LRR interacts with the Windows Redis server seamlessly. Magic!  

Redis can be installed on the Linux side as well, but one would have to start it by hand alongside LRR on every OS boot. 


