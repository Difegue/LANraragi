---
description: >-
  Vagrant is probably the fastest way to get started for the moment, but it only works on Windows and macOS due to its reliance on SMB.
---

# Vagrant

## Using the Vagrantfile

You can use the available Vagrantfile with [Vagrant](https://www.vagrantup.com/downloads.html) to deploy a virtual machine on your computer with LANraragi preinstalled.  

{% hint style="info" %}
This method requires [VirtualBox](https://www.virtualbox.org/) to be installed on your machine!
{% endhint %}

Download [the Vagrantfile setup](https://github.com/Difegue/LANraragi/raw/master/tools/VagrantSetup) and put it in your future LANraragi folder, and enter the following commands in a terminal pointed to that folder:

```text
vagrant up
```

Vagrant might ask for admin rights while provisioning the VM. You can check the details as to why it does that [here](https://www.vagrantup.com/docs/synced-folders/smb.html). 

Once the Vagrant machine is up and provisioned, you can access LANraragi at [http://localhost:3000](http://localhost:3000).  
Archives you upload will be placed in the directory of the Vagrantfile.

The Vagrant machine is a simple Docker wrapper, so the database will also be stored in this directory. \(As database.rdb\)

You can use `vagrant halt` to stop the VM when you're done. To start it up again, use `vagrant up`.

Keep in mind that the Vagrant setup, just like Docker, will always use the latest release.

