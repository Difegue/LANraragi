package LANraragi::Plugin::EHentai

use strict;
use warnings;

#Meta-information about your plugin.
sub plugin_info {

	return (
		#Standard metadata
	    name  => "E-Hentai(Text)",
	    author => "Difegue",
	    version  => "1.0",
	    description => "Searches for the archive's title and author on E-Hentai, and returns tags if it finds any.",
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
    return (
			title  => "",
		    artist => "",
		    series => "",
		    language => "",
		    event => "",
		    tags => ""
			);
}
1;