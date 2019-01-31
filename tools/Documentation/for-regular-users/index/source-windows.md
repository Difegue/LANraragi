---
description: Also known as MSI hell! The horror!
---

# From source \(Windows\)

{% hint style="danger" %}
This installation method is a **major** pain due to the lack of prebuilt libraries for some of the dependencies.

If you really want to run on Windows, I recommend you use the [Windows Subsystem for Linux](https://docs.microsoft.com/en-us/windows/wsl/install-win10) with the Linux source install instead.
{% endhint %}

## Needed dependencies

Download/Install the following MSIs.

* [Perl](https://strawberryperl.com/download/5.26.1.1/strawberry-perl-5.26.1.1-64bit.msi)
* [Redis for Windows](https://github.com/tporadowski/redis)
* [Node and NPM](https://nodejs.org/dist/v9.4.0/node-v9.4.0-x64.msi)

You'll also need to download the sources for the following dependencies and compile them yourself \(using either Strawberry Perl's included MinGW compiler or Visual Studio\):

* [libarchive](https://libarchive.org/)
* [libpng](http://www.libpng.org/pub/png/libpng.html)
* [libjpeg](https://libjpeg-turbo.org/)

## Installing LRR

Clone/Download the Git repository somewhere\(or download one of [the releases](https://github.com/Difegue/LANraragi/releases)\).  
Chock the libs in it, and run `npm run lanraragi-installer install-full`. You're done!

You can start LRR by running `npm start` and opening [http://localhost:3000](http://localhost:3000).

