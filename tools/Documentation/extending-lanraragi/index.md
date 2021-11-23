---
description: I'd like to interject for a moment
---

# 🏗 Setup a Development Environment

## Quick rundown

LRR is written in Perl on the server-side with the help of the [Mojolicious](http://mojolicious.org) framework, with basic JQuery on the clientside.\
**npm** is used for JavaScript dependency management and basic shortcuts, while **cpanm** is used for Perl dependency management.

As of v.0.5.5, a basic Client API is available for you to write clients that can connect to a LANraragi instance.

## Quick setup

Once you've got a running LANraragi instance, you can basically dive right into the files to modify stuff to your needs. As you need raw access to the files, a native OS install is needed!\
I recommend a Linux or WSL install, as the _morbo_ development server only works on Linux.

Said development server can be ran with the `npm run dev-server` command.\
The major difference is that this server will automatically reload when you modify any file within LANraragi. Background worker included!

You'll also probably want to enable **Debug Mode** in the LRR Options, as that will allow you to view debug-tier logs, alongside the raw Mojolicious logs.
