# Install using Vagrant

For computers that are unable to easily use Docker (Windows 7 for instance), Vagrant is an excellent alternative to get started quickly. 

## Using the Vagrantfile setup

You can use the available Vagrantfile with [Vagrant](https://www.vagrantup.com/downloads.html) to deploy a virtual machine on your computer with LANraragi preinstalled.  
Download [the Vagrantfile setup](https://github.com/Difegue/LANraragi/raw/master/tools/VagrantSetup) and put it in your future LANraragi folder, and enter the following commands in a terminal pointed to that folder:
```
vagrant plugin install vagrant-vbguest
vagrant up
```
Once the Vagrant machine is up and provisioned, you can access LANraragi at [http://localhost:3000](http://localhost:3000).  
Archives you upload will be placed in the directory of the Vagrantfile.  

The Vagrant machine is a simple Docker wrapper, so the database will also be stored in this directory. (As database.rdb)

You can use `` vagrant halt `` to stop the VM when you're done. To start it up again, use `` vagrant up ``.

Keep in mind that the Vagrant setup, just like Docker, will always use the latest files from Git.