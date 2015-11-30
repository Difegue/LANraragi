#LANraragi Installation Guide  
This guide is based on a bare-bones **Debian Wheezy** installation.  
If you use another Linux flavor, you probably know which package manager to use.  
For Windows users, see below.  

##Install required software:  

* A **web server**. I'll be using apache for this, but there's no reason you shouldn't be able to run it with nginx.  
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
cpanm -i HTML::Table Capture::Tiny Tie::File Digest::SHA Redis CGI::Ajax URI::Escape Image::Info
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

* **Imagemagick**. Should be built-in. Otherwise:  
```
apt-get install imagemagick
```

Download the current build in your directory:  
```
wget https://github.com/Difegue/LANraragi/archive/master.zip
unzip master.zip -d /var/www
mv /var/www/LANraragi-master/ /var/www/panda
```

Get the JS dependencies and add them to the js folder:  
```
wget https://raw.githubusercontent.com/javve/list.js/v1.1.1/dist/list.min.js
wget https://raw.githubusercontent.com/javve/list.pagination.js/v0.1.1/dist/list.pagination.min.js
wget https://raw.githubusercontent.com/stowball/jQuery-rwdImageMaps/master/jquery.rwdImageMaps.min.js
wget https://code.jquery.com/jquery-2.1.4.min.js
mv *.js /var/www/panda/js
```

Configure apache so that your LANraragi directory can execute .pl files.  
Something like this in **sites-enabled**:  
```
	<Directory /var/www/panda/>
		Options +ExecCGI
		AddHandler cgi-script .cgi .pl
	</Directory>
```

Be sure to set **read-write permissions** for your web server on the LANraragi directory. 
```
chown -R www-data /var/www/panda
chmod -R 755 /var/www/panda
```

Access your directory, and you're good to go! Setup the directories and password in config.pl next. 

##For Windows Users: 
http://httpd.apache.org/docs/2.2/platform/windows.html for Apache.  
http://learn.perl.org/installing/windows.html for Perl and cpanm.  
http://www.imagemagick.org/script/binary-releases.php for Imagemagick.  
http://theunarchiver.googlecode.com/files/unar1.8.1_win.zip for unar.  
https://msopentech.com/opentech-projects/redis/ for Redis.

It hasn't been tested(and I ought to someday), but a LANraragi install should run well on a Windows system if you install these and go through the steps of the Linux installation. 
**Remember to add unar to your $PATH.**
