---
description: >-
  For computers that are unable to easily use Docker or WSL(Basically just Windows 7 and 8), Vagrant allows you to quickly get started nonetheless.
---

# Vagrant

## Using the Vagrantfile

You can use the available Vagrantfile with [Vagrant](https://www.vagrantup.com/downloads.html) to deploy a virtual machine on your computer with LANraragi preinstalled.  

{% hint style="info" %}
This method requires [VirtualBox](https://www.virtualbox.org/) to be installed on your machine! I recommend version [6.0.4](https://download.virtualbox.org/virtualbox/6.0.4/). 

{% endhint %}

Download [the Vagrantfile setup](https://github.com/Difegue/LANraragi/raw/master/tools/VagrantSetup) and put it in your future LANraragi folder, and enter the following commands in a terminal pointed to that folder:

```text
vagrant plugin install vagrant-vbguest
vagrant up
```

Once the Vagrant machine is up and provisioned, you can access LANraragi at [http://localhost:3000](http://localhost:3000).  
Archives you upload will be placed in the directory of the Vagrantfile.

The Vagrant machine is a simple Docker wrapper, so the database will also be stored in this directory. \(As database.rdb\)

You can use `vagrant halt` to stop the VM when you're done.  
To start it up again, use the following commands:
```text
vagrant provision
vagrant up
```

Keep in mind that the Vagrant setup, just like Docker, will always use the latest release.

{% hint style="info" %}
You can switch to nightlies by downloading the Vagrantfile available [here](https://github.com/Difegue/LANraragi/raw/master/tools/VagrantSetup_nightly) and replacing your vanilla Vagrantfile with it. 

{% endhint %}

