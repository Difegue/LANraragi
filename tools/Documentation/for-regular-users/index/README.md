---
description: What's the best way to install this autism enabler? Here's the Quick Rundown™
---

# Installing LANraragi

## Quick Rundown

### Containers: Simply the best

As LRR is a server app first and foremost, its setup is a bit more complex than your usual Desktop application.  
Therefore, for unexperienced users, I recommend using a **container/VM** install like Docker or Vagrant.  
They're clean, easy to update, and automatically built/tested.  

**Vagrant** is easier to install and start up, if you're only looking to use the app on your local machine.

{% page-ref page="vagrant.md" %}

**Docker** works out of the box in Windows 10, macOS and Linux.  
If you're running an older version of Windows, you can manage using the [Legacy Docker Toolbox](https://docs.docker.com/toolbox/toolbox_install_windows/), but I recommend you use Vagrant instead.

{% page-ref page="docker.md" %}


### Installing from source on Unix systems

{% page-ref page="source-linux.md" %}

Installing from **source** is a more involved procedure, but it does put you in full control and able to hack up the app's files as you wish.

### Windows: Windows Subsystem for Linux Installation

Due to this setup demanding a subsystem usually meant for developers, I wouldn't recommend it for standard users.  
However, it is deceptively simple:

* Step 1: Install the [Redis Windows Port](https://github.com/tporadowski/redis)
* Step 2: Follow the Linux Guide in your WSL terminal, omitting the part about installing Redis.

{% page-ref page="source-linux.md" %}

In this hybrid setup, LRR interacts with the Windows Redis server seamlessly. Magic!

Redis can be installed on the Linux side as well, but one would have to start it by hand alongside LRR on every OS boot.

{% hint style="info" %}
I used to provide a one-click Windows source port version, but have encountered increasing issues with it as I introduced modern features and dependencies.  
If you just want to try the software, you can still use the old one-click Quickstarter for [v.0.5.6.](https://github.com/Difegue/LANraragi/releases/download/v.0.5.6/LRR_0.5.6_QuickStarter_Windows.zip)
{% endhint %}


### Bonus: A memo about reverse proxies

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