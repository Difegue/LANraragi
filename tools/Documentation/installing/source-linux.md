# Install from source on Linux

The following instructions are based on **Debian Stretch.**

## A small FYI about Vendor Perl

As you might have noticed, LANraragi entirely depends on the Perl programming language.  
A version of Perl usually ships already compiled on most Linux distributions. It's usually called "Vendor Perl".  

Using vendor Perl is [generally discouraged](http://www.modernperlbooks.com/mt/2012/01/avoiding-the-vendor-perl-fad-diet.html) due to possible fuck-ups by the Linux distribution creator.  
As such, you might want to install LANraragi with your own compiled Perl, using a tool such as [Perlbrew](https://perlbrew.pl/).  

And this is just fine! However, I'll consider we're using Vendor Perl here, for the following reasons:  
* The Debian Vendor Perl works flawlessly with LANraragi, and due to Debian being one of the most used Linux distros, it's likely users can just use it as-is and avoid losing an hour building their own Perl.  
* The [PerlMagick](http://search.cpan.org/~jcristy/PerlMagick-6.89-1/Magick.pm) package, required by LRR, needs the ImageMagick source headers to be built.  
As such, it's not automatically installed by our installer scripts. Vendor Perl users can just install the prebuilt version from Apt. Perlbrew/Plenv users will have to download said headers and build it on their own.

## Needed dependencies

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

## Installing LRR 

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