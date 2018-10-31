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