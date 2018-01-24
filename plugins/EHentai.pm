package LANraragi::Plugin::EH

use strict;
use warnings;

#Meta-information about your plugin.
sub plugin_info {

	return (
		#Standard metadata
	    name  => "red",
	    author => "orange",
	    version  => "1.0",
	    description => "",
	    #If your plugin uses/needs a custom argument, input its name here. 
	    #This name will be displayed in plugin configuration next to an input box.
	    custom_arg_name => ""
	);

}

#Mandatory function to be implemented by your plugin
sub get_tags {

	#LRR gives your plugin a hash containing all known metadata, the filesystem path to the file, and the custom argument if available.
    my (%metadata_hash, $file, $usrarg) = @_;

    #Work your magic here - You can create subs below to organize the code better


    #Return a hash containing the revised metadata - it will be integrated in LRR.
    return "";
}
1;