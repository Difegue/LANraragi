LANraragi
============

![Demo(fuck das lewd)!](http://b.1339.cf/pfilhue.png "")
Web interface and reader for a server-stored directory of comics (as archives).
Supports tags, and runs on a basic installation of Perl with the following packages installed:  

	* HTML:Table  
	* Capture::Tiny  	
	* Tie::File
	* Digest::SHA
	* Redis
	* LWP::Simple
	* JSON::Parse
	* Switch
	* IPC::Cmd
	
You can find a basic installation guide [here](https://github.com/Difegue/LANraragi/blob/master/Install.md).
	
Installations of unar and Redis are also required. (For Windows users, be sure to have unar and lsar in your $PATH.)  
You will also require ImageMagick installed on your server to use thumbnails and image compression. (These are optional.)


UI and project mostly inspired by the good folks over at sadpanda, and the Wani takedowns. ;_;7

Note that this is a rather simple project and is only meant to be a frontend to an archive, if you're looking for a non-Web, non-Server solution I'd recommend [the Hydrus suite](http://github.com/hydrusnetwork).
(Which has also the benefit of being way more advanced.)

[Demo website here!](http://maximumlewd.science)  
config.pl contains a lot of variables you can define yourself. They're properly explained in the file itself.  

![wow!](http://b.1339.cf/ltcdirj.png "")
