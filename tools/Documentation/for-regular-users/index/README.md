---
description: What's the best way to install this autism enabler? Here's the Quick Rundown™
---

# Installing LANraragi

## Quick Rundown

### Containers: Simply the best

As LRR is a server app first and foremost, its setup is a bit more complex than your usual Desktop application.  
Therefore, for unexperienced users, I recommend using a **container/VM** install like Docker or Vagrant.  
They're clean, easy to update, and automatically built/tested.

{% page-ref page="docker.md" %}

{% page-ref page="vagrant.md" %}

### Installing from source on Unix systems

{% page-ref page="source-linux.md" %}

Installing from **source** is a more involved procedure, but it does put you in full control and able to hack up the app's files as you wish.

### Windows: 🙇‍ _please understand_ 🙇‍

I used to provide a one-click Windows source port version, but have encountered increasing issues with it as I introduced modern features and dependencies.  
If you just want to try the software, you can still use the old one-click Quickstarter for [v.0.5.6.](https://github.com/Difegue/LANraragi/releases/download/v.0.5.6/LRR_0.5.6_QuickStarter_Windows.zip)

It's _technically_ still possible to run the software on a Strawberry Perl release if you compile all the dependencies needed. The page below is outdated but can serve as a good place to start:

{% page-ref page="source-windows.md" %}

Keep in mind that Batch Tagging will not work at all under Windows due to its reliance on [Mojolicious subprocesses.](https://metacpan.org/pod/distribution/Mojolicious/lib/Mojolicious/Guides/FAQ.pod#How-well-is-Windows-supported-by-Mojolicious?) In a similar fashion, many features will probably stop working as releases progress and I use more Linux-specific features out of convenience.

### Bonus: Windows Subsystem for Linux Installation

Due to this setup demanding a subsystem usually meant for developers, I wouldn't recommend it for standard users.  
However, it is deceptively simple:

* Step 1: Install the [Redis Windows Port](https://github.com/tporadowski/redis)
* Step 2: Follow the Linux Guide in your WSL terminal, omitting the part about installing Redis.

{% page-ref page="source-linux.md" %}

In this hybrid setup, LRR interacts with the Windows Redis server seamlessly. Magic!

Redis can be installed on the Linux side as well, but one would have to start it by hand alongside LRR on every OS boot.

### Bonus 2: A memo about reverse proxies

A common post-install setup is to make requests to the app transit through a gateway server such as Apache or nginx.  
If you do so, please note that archive uploads through LRR will likely **not work out of the box** due to maximum sizes on uploads those servers can enforce. The example below is for nginx:  

```
server {
    listen 80;

    server_name lanraragi.[REDACTED].net;

    return 301 https://$host$request_uri;
}
server {
    listen 443 ssl;
    index index.php index.html index.htm;
    server_name lanraragi.[REDACTED].net;

    client_max_body_size 0;   <----------------------- This line here

    # Cert Stuff Omitted

    location / {
        proxy_pass http://0.0.0.0:3000;
    }
}
```