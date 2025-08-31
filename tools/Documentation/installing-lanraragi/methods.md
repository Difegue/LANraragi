---
description: This is a by-OS breakdown of how you can install the software on your machine.
---

# ❓ Which installation method is best for me?

As LRR is a server app first and foremost, its setup is a bit more complex than your usual Desktop application.  
However, a lot of work as been done behind the scenes to make it easy!

Look at the methods below for something that fits your OS and usage.

## Linux/macOS: _Homebrew_

[Homebrew](https://brew.sh) allows you to quickly setup LRR on macOS and Linux without relying on containers or modifying your preinstalled system libaries.

![brew](<../.screenshots/brew.jpg>)

{% content-ref url="macos.md" %}
[macos.md](macos.md)
{% endcontent-ref %} 

{% hint style="info" %}
While not a part of the main repo, you can check out the [Nix](community.md) package as well if brew isn't to your taste.
{% endhint %}

## Windows 10/11: _LRR for Windows_

{% hint style="warning" %}
This method works on **64-bit** editions of Windows 10 only.
{% endhint %}

![win10](../.screenshots/karen.png)

I provide a dedicated installer for Windows machines as of 0.6.0, complete with a GUI and autostart.

{% content-ref url="windows.md" %}
[windows.md](windows.md)
{% endcontent-ref %}

## Linux/macOS/Windows 10: _Docker_

Taking a page from sysadmin books, you can easily install LRR as a **container** with Docker.  
They're lightweight, easy to update, and automatically built/tested. I recommend this for NAS setups!

{% content-ref url="docker.md" %}
[docker.md](docker.md)
{% endcontent-ref %}

## Linux/macOS: _Installing from Source_

Installing from **source** is a more involved procedure, but it does put you in full control and able to hack up the app's files as you wish.

{% content-ref url="source.md" %}
[source.md](source.md)
{% endcontent-ref %}

## Linux/Community: _Community provided install packages_

Ready-to-install packages provided by voluntary maintainers or by a linux distribution itself.

{% content-ref url="community.md" %}
[community.md](community.md)
{% endcontent-ref %}

## FreeBSD/Jail

Similar to installing from source with an altered process for FreeBSD compatability.

{% content-ref url="jail.md" %}
[jail.md](jail.md)
{% endcontent-ref %}

## Windows 7 or 8: don't

![I really hope you guys don't do this](../.screenshots/shiggy.png)

Switch to 10 or Linux.  
