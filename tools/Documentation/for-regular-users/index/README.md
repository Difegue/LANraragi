---
description: What's the best way to install this autism enabler? Here's the Quick Rundown™
---

# Installing LANraragi

## Quick Rundown

### Containers: Simply the best

As LRR is a server app first and foremost, its setup is a bit more complex than your usual Desktop application.  
Therefore, for unexperienced users, I recommend using a **container** install like Docker or Vagrant.  
They're clean, easy to update, and automatically built/tested.

{% page-ref page="docker.md" %}

{% page-ref page="vagrant.md" %}

### Windows QuickStarter: Good enough

The **QuickStarter** zip is the easiest way to get started on Windows machines - Just open the .bat \(or the .ps1 for you powershell hipsters who want to feel special\) and you're good to go.

{% page-ref page="windows.md" %}

However, quirks in the Windows port mean you might encounter slight glitches depending on how your Windows is set up.

It's also slightly less clean, less tested, less everything. But it works for most users who try it. Your mileage may vary.

### Source Install: Let's get dangerous

_**I'm a super hacker, can I just install from source?**_

{% page-ref page="source-windows.md" %}

{% page-ref page="source-linux.md" %}

Installing from **source** is a more involved procedure, but it does put you in full control and able to hack up the app's files as you wish.

