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

* The Required **Perl packages**. I recommend installing cpanminus (curl -L http://cpanmin.us | perl - --sudo App::cpanminus) to make it easier: 
``` 
cpanm -i HTML::Table Image::Info File::Tee Tie::File  
```
* **unar**. 
```
apt-get install unar
```

* **Imagemagick**. Should be built-in. Otherwise:  
```
apt-get install imagemagick
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

##For Windows Users:  
http://httpd.apache.org/docs/2.2/platform/windows.html for Apache.  
http://learn.perl.org/installing/windows.html for Perl and cpanm.  
http://www.imagemagick.org/script/binary-releases.php for Imagemagick.  
http://theunarchiver.googlecode.com/files/unar1.8.1_win.zip for unar.  

It hasn't been tested, but a LANraragi install should run well on a Windows system if you install these.  
**Remember to add unar to your $PATH.**