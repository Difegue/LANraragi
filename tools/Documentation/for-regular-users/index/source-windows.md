---
description: Also known as .msi hell.
---

# From source \(Windows\)

With the Mojolicious port, all of LANraragi's software dependencies have working Windows versions, making native installs now possible!

### Needed dependencies

Download/Install the following MSIs.

* [Perl](https://strawberryperl.com/download/5.26.1.1/strawberry-perl-5.26.1.1-64bit.msi)
* [Redis](https://github.com/MicrosoftArchive/redis/releases/download/win-3.2.100/Redis-x64-3.2.100.msi)
* [Node and NPM](https://nodejs.org/dist/v9.4.0/node-v9.4.0-x64.msi)
* [unar and lsar](https://theunarchiver.com/downloads/unarWindows.zip)

Once Perl is installed, you'll want to run the following command to install PerlMagick: `ppm install Image-Magick`

### Installing LRR

Clone/Download the Git repository somewhere\(or download one of [the releases](https://github.com/Difegue/LANraragi/releases)\).  
Chock the unar/lsar executables in it, and run `npm run lanraragi-installer install-full`. You're done!

You can start LRR by running `npm start` and opening [http://localhost:3000](http://localhost:3000).

## Bonus: Windows Subsystem for Linux Installation

Due to this setup demanding a subsystem usually meant for developers, I wouldn't recommend it for standard users.  
However, it is deceptively simple:

* Step 1: Install the [Redis Windows Port](https://github.com/MicrosoftArchive/redis/releases/download/win-3.2.100/Redis-x64-3.2.100.msi)
* Step 2: Follow the [Linux Guide](source-windows.md#native-linux-installation) in your WSL terminal, omitting the part about installing Redis.

In this hybrid setup, LRR interacts with the Windows Redis server seamlessly. Magic!

Redis can be installed on the Linux side as well, but one would have to start it by hand alongside LRR on every OS boot.

