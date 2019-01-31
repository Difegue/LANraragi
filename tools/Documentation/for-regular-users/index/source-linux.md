---
description: The following instructions are based on Debian Stretch.
---

# From source \(Linux\)

## A small FYI about Vendor Perl

As you might have noticed, LANraragi entirely depends on the Perl programming language.  
A version of Perl usually ships already compiled on most Linux distributions. It's usually called "Vendor Perl".

Using vendor Perl is [generally discouraged](http://www.modernperlbooks.com/mt/2012/01/avoiding-the-vendor-perl-fad-diet.html) due to possible fuck-ups by the Linux distribution creator.  
As such, you might want to install LANraragi with your own compiled Perl, using a tool such as [Perlbrew](https://perlbrew.pl/).

For information, my personal tests are done using Debian's vendor Perl.

## Needed dependencies

```text
apt-get update
apt-get upgrade -y
apt-get install build-essential make gnupg \
cpanminus redis-server libarchive-dev libjpeg-dev libpng-dev libssl-dev zlib1g-dev
```

_Base software dependencies._

```text
curl -sL https://deb.nodesource.com/setup_9.x | bash -
apt-get install -y nodejs
```

_Node.js and NPM._

## Installing LRR

All you need to do is clone the git repo somewhere \(or download one of [the releases](https://github.com/Difegue/LANraragi/releases)\) and run the installer.  
I recommend doing this with a brand new Linux user account. \(I'm using "koyomi" here\):

```text
git clone -b master http://github.com/Difegue/LANraragi /home/koyomi/lanraragi
cd /home/koyomi/lanraragi && sudo npm run lanraragi-installer install-full
```

Once this is done, you can get started by running `npm start` and opening [http://localhost:3000](http://localhost:3000).

{% hint style="info" %}
By default, LRR listens on all IPv4 Interfaces on port 3000. You can change this by setting your wished listen location as a parameter of `npm start`:

```bash
npm start http://127.0.0.1:8000

> LANraragi@0.5.0 start /mnt/c/Users/Tamamo/Desktop/lanraragi
> perl ./script/lanraragi daemon -l "http://127.0.0.1:8000"

ｷﾀ━━━━━━(ﾟ∀ﾟ)━━━━━━!!!!!
[LANraragi] LANraragi 0.5.0 (re-)started. (Production Mode)
[...]
[Mojolicious] Listening at "http://127.0.0.1:8000"
```

All listen locations [supported by "listen" in Mojo::Server::Daemon](http://www.mojolicious.org/perldoc/Mojo/Server/Daemon#listen) are valid.
{% endhint %}

