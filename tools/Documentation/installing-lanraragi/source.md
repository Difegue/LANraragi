---
description: The following instructions are based on Debian Stretch.
---

# 🛠 Source Code (Linux/macOS)

## A small FYI about Vendor Perl

As you might have noticed, LANraragi entirely depends on the Perl programming language.  
A version of Perl ships already compiled on most Linux distributions(and macOS). It's usually called "Vendor Perl".

Using vendor Perl is [generally discouraged](http://www.modernperlbooks.com/mt/2012/01/avoiding-the-vendor-perl-fad-diet.html) due to possible fuck-ups by the Linux distribution creator.  
As such, you might want to install LANraragi with your own compiled Perl, using a tool such as [Perlbrew](https://perlbrew.pl).

For information, my personal tests are done using Debian's vendor Perl.

## Needed dependencies

```
apt-get update
apt-get upgrade -y
apt-get install build-essential make gnupg pkg-config \
cpanminus redis-server libarchive-dev imagemagick webp libssl-dev zlib1g-dev \
perlmagick ghostscript npm
```

_Base software dependencies._

{% hint style="info" %}
If your package manager requires you to specify which ImageMagick version to install, choose version 7.
{% endhint %}

{% hint style="info" %}
For macOS, you should be able to install the dependencies using Homebrew.
{% endhint %}

## Installing LRR

All you need to do is clone the git repo somewhere (or download one of [the releases](https://github.com/Difegue/LANraragi/releases)) and run the installer.  
I recommend doing this with a brand new Linux user account. (I'm using "koyomi" here):

```
git clone -b master http://github.com/Difegue/LANraragi /home/koyomi/lanraragi
cd /home/koyomi/lanraragi && sudo npm run lanraragi-installer install-full
```

{% hint style="info"}
Do not use `sudo` in the above command if you are using `perlbrew`.  
Arch users might need to install `perl-config-autoconf` and use env variable `export PERL5LIB=~/perl5/lib/perl5` before running the installer.
{% endhint %}

Once this is done, you can get started by running `npm start` and opening [http://localhost:3000](http://localhost:3000).

To change the default port or add SSL support, see this page:

{% content-ref url="../advanced-usage/network-interfaces.md" %}
[network-interfaces.md](../advanced-usage/network-interfaces.md)
{% endcontent-ref %}

{% hint style="info" %}
By default, LRR listens on all IPv4 Interfaces on port 3000, unsecured HTTP.
{% endhint %}

### Updating

Getting all the files from the latest release and pasting them in the directory of the application should give you a painless update 95% of the time.

To be on the safe side, make sure to rerun the installer once this is done:

```bash
npm run lanraragi-installer install-full
```
