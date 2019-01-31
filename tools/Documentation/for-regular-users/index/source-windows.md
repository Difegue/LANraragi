---
description: Also known as MSI hell! The horror!
---

# From source \(Windows\)

With the Mojolicious port, all of LANraragi's software dependencies have working Windows versions, making native installs now possible!

### Needed dependencies

Download/Install the following MSIs.

* [Perl](https://strawberryperl.com/download/5.26.1.1/strawberry-perl-5.26.1.1-64bit.msi)
* [Redis](https://github.com/MicrosoftArchive/redis/releases/download/win-3.2.100/Redis-x64-3.2.100.msi)
* [Node and NPM](https://nodejs.org/dist/v9.4.0/node-v9.4.0-x64.msi)

You'll also need to download Windows ports of the used libraries:

* [libarchive, libpng and libjpeg](https://github.com/Difegue/LANraragi/tree/4cc6c123676514a3a9a49d5da21f89fc1608f154/tools/Documentation/for-regular-users/index/todo%20yooo/README.md)

### Installing LRR

Clone/Download the Git repository somewhere\(or download one of [the releases](https://github.com/Difegue/LANraragi/releases)\).  
Chock the libs in it, and run `npm run lanraragi-installer install-full`. You're done!

You can start LRR by running `npm start` and opening [http://localhost:3000](http://localhost:3000).

## Bonus: Windows Subsystem for Linux Installation

Due to this setup demanding a subsystem usually meant for developers, I wouldn't recommend it for standard users.  
However, it is deceptively simple:

* Step 1: Install the [Redis Windows Port](https://github.com/MicrosoftArchive/redis/releases/download/win-3.2.100/Redis-x64-3.2.100.msi)
* Step 2: Follow the [Linux Guide](source-windows.md#native-linux-installation) in your WSL terminal, omitting the part about installing Redis.

In this hybrid setup, LRR interacts with the Windows Redis server seamlessly. Magic!

Redis can be installed on the Linux side as well, but one would have to start it by hand alongside LRR on every OS boot.

