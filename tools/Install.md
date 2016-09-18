LANraragi Installation Guide  
============

You can find below three ways to get a LANraragi installation: Docker, Vagrant, or regular Linux with Apache.

#Docker Installation
A Docker image exists for deploying LANraragi installs to your machine easily without disrupting your already-existing web server setup.(Or installing on Windows/Mac.)  
Download [the Docker setup](https://www.docker.com/products/docker) and install it. Once you're done, get the CLI out :  
```
docker run --name=lanraragi -p 8080:80 -v [YOUR_ARCHIVE_DIRECTORY]:/var/www/lanraragi/content difegue/lanraragi

```
Setting in your own archive directory. This directory will contain archives you either upload through the app or directly drop in.  

On OSX, you should use something like :  
```
/Users/<path>
```  
And on Windows :  
```
/c/Users/<path>
```  
Once your LANraragi container is loaded, you can access it at [http://localhost:8080/lanraragi](http://localhost:8080/lanraragi) .  
You can use the following commands to stop/start/remove the container(Removing it won't delete the archive directory you specified) : 
```
docker stop lanraragi
docker start lanraragi
docker rm lanraragi
```  

This whole setup gets a working LANraragi container from the Docker Hub, but you can build your own bleeding edge version by downloading [the Docker setup](https://github.com/Difegue/LANraragi/raw/master/tools/DockerSetup) and executing :
```
docker build -t whateverthefuckyouwant/lanraragi [PATH_TO_THE_DOCKERFILE]
```  
This will get the latest revision from the git repo and grab bower dependencies on its own.  

#Vagrant Installation 
I wrote a Vagrantfile you can use with [Vagrant](https://www.vagrantup.com/downloads.html) to deploy a virtual machine on your computer with LANraragi preinstalled.  
Download [the Vagrant setup](https://github.com/Difegue/LANraragi/raw/master/tools/VagrantSetup) somewhere, and whip out a terminal :
```
vagrant plugin install vagrant-vbguest
vagrant up
```
Once it's deployed(it takes a while to download everything), you'll have a /lanraragi folder, which syncs to an install located at [http://localhost:8080/lanraragi](http://localhost:8080/lanraragi) .  
You can use 
```
vagrant halt
```  
to stop the VM when you're done.  

The Vagrant setup automatically gets the latest revision from the git repo and grabs bower dependencies on its own. If the current development version has issues or the bower dependencies fail, please use the files from one of [the releases](https://github.com/Difegue/LANraragi/releases).

#Manual Linux Installation  

This guide is based on a bare-bones **Debian Jessie** installation.  
If you use another Linux flavor, you probably know which package manager to use.  
For Windows users, use the Vagrant or Docker solutions outlined in the Readme.  

##Install required software:  

* A **web server**. I'll be using apache for this, but there's no reason you shouldn't be able to run it with nginx if you can wrestle through CGI.  
```
apt-get install apache2
```

* **Perl**. Should be built-in. Otherwise:  
```
apt-get install perl
```

* The Required **Perl packages**. I recommend installing cpanminus to make it easier: 
``` 
apt-get install cpanminus
apt-get install make
cpanm -i CGI Template Redis JSON::Parse CGI::Session File::ShareDir::Install CGI::Session::Driver::redis Image::Info IPC::Cmd LWP::Simple Digest::SHA URI::Escape Authen::Passphrase
```
Go watch some anime while it downloads all the dependencies.  
Follow this link if you get locale errors while building the extra packages.
https://www.thomas-krenn.com/en/wiki/Perl_warning_Setting_locale_failed_in_Debian

* **unar**. 
```
apt-get install unar
```

* **Redis**. 
```
apt-get install redis-server
```

* **Imagemagick and the Perl bindings**.  
```
apt-get install imagemagick perlmagick
```

Download the current build in your directory:  
```
git clone https://github.com/Difegue/LANraragi.git /var/www/lanraragi
```

Use Bower to get the front-end dependencies:  
```
apt-get install npm
npm install -g bower
cd /var/www/lanraragi
bower install
```  

Those last two steps can be replaced by merely downloading one of [the releases](https://github.com/Difegue/LANraragi/releases) and unzipping in /var/www/lanraragi, if you don't feel like being bleeding edge.  

##Configuration:  

Configure apache so that your LANraragi directory can execute .pl files.  
Something like this in **sites-enabled**:  
```
	<Directory /var/www/lanraragi/>
		Options ExecCGI
		AddHandler cgi-script .cgi .pl
	</Directory>
```

Be sure to set **read-write permissions** for your web server on the LANraragi directory. 
```
chown -R www-data /var/www/lanraragi
chmod -R 755 /var/www/lanraragi
```

If your Redis database has a different port or number from the default, edit **functions/functions_config.pl** to change it.  
That file is also used for other advanced settings, give it a look.  

Access your directory, and you're good to go! Login with the default admin password (kamimamita) next to setup directories and change your password.  

##For Windows Users: 
It's not possible yet to get the Linux build running under the new Windows 10 Linux subsystem due to sockets fuckery.  
Consider using the Vagrant or Docker files if you want a "just werks" solution.
