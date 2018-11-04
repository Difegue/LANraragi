---
description: >-
  Use the QuickStarter .zip release to quickly try out the software on Windows!
  Small glitches CAN occur using this version.
---

# Windows \(QuickStarter\)

## Warning

The framework running LANraragi, Mojolicious, [has dropped official support for Windows](https://metacpan.org/pod/distribution/Mojolicious/lib/Mojolicious/Guides/FAQ.pod#How-well-is-Windows-supported-by-Mojolicious?).

In a similar way of thinking, I don't test the Windows version thoroughly to ensure it'll be 100% functional on all points, but I plan to keep building/providing the QuickStarter .zips for people to try out. It **does** work for most users, so there's no reason for it to explode in your face or something.

For prolonged use and easy updates, I very much recommend using one of the containerized installation methods insteads - Docker or Vagrant. Those methods use a tested Linux environment which I guarantee is functional \(at least until I botch a release again\).

{% hint style="danger" %}
Windows with a non-unicode codepage \(for example, CP-932 which is the old Shift-JIS codepage used by Japanese locales\) is known to work super badly with this! 
{% endhint %}

## Downloading and running the QuickStarter

Just download the QuickStarter .zip from one of [the releases](https://github.com/Difegue/LANraragi/releases) and extract it somewhere. The folder will look like this:

```text
berrybrew/
lanraragi/
redis/
unar/
start-lanraragi.bat
```

Just run the .bat and you're on your way!  
The first launch takes a bit longer due to having to download some more software dependencies.  
No Administrator privileges are required.

## What's installed on your machine

The QuickStarter downloads a Perl installation to `C:/berrybrew`.  
Apart from that, all data is self-contained in the QuickStarter folder, and can be moved between Windows machines freely.  
The database will be located at the root of the folder, as `dump.rdb`.  
The default content directory will be `/lanraragi/content`, but I would recommend changing it - if you can.

