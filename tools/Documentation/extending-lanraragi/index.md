---
description: I'd like to interject for a moment
---

# 🏗 Setup a Development Environment

## Quick rundown

LRR is written in Perl on the server-side with the help of the [Mojolicious](http://mojolicious.org) framework, with basic JQuery on the clientside.  
**npm** is used for JavaScript dependency management and basic shortcuts, while **cpanm** is used for Perl dependency management.

As of v.0.5.5, a basic Client API is available for you to write clients that can connect to a LANraragi instance.

## Quick setup

Once you've got a running LANraragi instance, you can basically dive right into the files to modify stuff to your needs. As you need raw access to the files, a native OS install is needed!\
I recommend a Linux or WSL install, as the _morbo_ development server only works on Linux.

Said development server can be ran with the `npm run dev-server` command.  
The major difference is that this server will automatically reload when you modify any file within LANraragi. Background worker included!

You'll also probably want to enable **Debug Mode** in the LRR Options, as that will allow you to view debug-tier logs, alongside the raw Mojolicious logs.

## Using MSYS2

The environment for development is **UCRT64**, other have not been tested.

Since Mojolicious and other perl dependencies are not designed to run on Windows they need to be patched. The patches can be found in `tools/build/windows` alongside other utility scripts.

You need to provide a redis-compatible server.

To setup an environment that can be used for development you need to do the following steps:

1. Update the environment with the `pacman -Syu` command.
2. cd into the LRR directory.
3. Run the script for installing native dependencies `./tools/build/windows/install-deps.sh`
4. Restart the environment (close and open the shell).
5. Run the script for installing perl dependencies `./tools/build/windows/install.sh`

Finally you can launch LRR with the `perl ./script/launcher.pl -d -v ./script/lanraragi` command.

There is no support for hot-reload, multithreading/multiprocess or a dev server. The only supported Mojo server is Daemon, this applies to development or production installs.

### UTF-8 support

If you have issues with path names getting mangled you need to patch perl to enable support for UTF-8. A recent Windows SDK is required for the patching tools.

1. Open a Visual Studio developer console.
2. cd into `<msys install dir>\ucrt64\bin`.
3. Run the `mt.exe -manifest <lrr dir>\tools\build\windows\perl.exe.manifest "-outputresource:perl.exe;#1"` command.

This will tell perl to use UTF-8 mode and accept any special characters. If you update the environment you might need to patch it again.

## Using Github Codespaces

The LRR Git repository contains [devcontainer.json](https://github.com/Difegue/LANraragi/tree/dev/.devcontainer) configuration for [Codespaces](https://github.com/Difegue/LANraragi/codespaces), so you can easily spin up a development VM using that. 
Deployment might take some time, as the VM will download all dependencies.  

## Using Docker Compose

You can use [Docker Compose](https://docs.docker.com/compose/) for quickly bringing up a LANraragi instance suitable for development.
Run `docker compose up -d` inside `tools/build/docker` and hack away!
