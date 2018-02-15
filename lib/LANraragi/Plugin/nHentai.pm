package LANraragi::Plugin::nHentai;

use strict;
use warnings;

#Plugins can freely use all Perl packages already installed on the system 
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use URI::Escape;
use Mojo::UserAgent;

#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;

#Meta-information about your plugin.
sub plugin_info {

	return (
		#Standard metadata
	    name  => "nHentai",
	    namespace => "nhplugin",
	    author => "Difegue",
	    version  => "1.0",
	    description => "Searches nHentai for tags matching your archive.",
	    #If your plugin uses/needs custom arguments, input their name here. 
	    #This name will be displayed in plugin configuration next to an input box for global arguments, and in archive edition for one-shot arguments.
	    global_arg => "",
	    oneshot_arg => "nHentai Gallery URL (Will attach tags matching this exact gallery to your archive)"
	);

}

#Mandatory function to be implemented by your plugin
sub get_tags {

	#LRR gives your plugin the recorded title for the file, the filesystem path to the file, and the custom arguments if available.
	shift;
    my ($title, $thumbhash, $file, $globalarg, $oneshotarg) = @_;

    my $logger = LANraragi::Model::Plugins::get_logger("nHentai");

    #Work your magic here - You can create subs below to organize the code better
    my $galleryID = "";
   
	#Quick regex to get the nh gallery id from the provided url.
	if ($oneshotarg =~ /.*\/g\/([0-9]*)\/.*/  ) { 
		$galleryID = $1;
	} else {
		#Get Gallery ID by hand if the user didn't specify a URL
		$galleryID = &get_gallery_id_from_title($title);
	}

    #Use the logger to output status - they'll be passed to LRR's standard output and a specialized logfile.
    $logger->info("Detected nhentai gallery id is $galleryID");

    #If no tokens were found, return a hash containing an error message. LRR will display that error to the client. 
    if ($galleryID eq "") {
    	return ( error => "No matching nHentai Gallery Found!");
    }

    my $newtags = &get_tags_from_NH($galleryID);

    #Return a hash containing the new metadata - it will be integrated in LRR.
    return ( tags => $newtags );
}


######
## NH Specific Methods
######

#get_gallery_id_from_title(title)
#Uses the website's search API to find a gallery and returns its gallery ID.
sub get_gallery_id_from_title {

	my $title = $_[0];
	my $URL = "https://nhentai.net/api/galleries/search?query=\"".uri_escape($title);

	my $ua = Mojo::UserAgent->new;

	my $res = $ua->get($URL)->result;

	my $content = $res->json;

	#get the first gallery of the search results
	my $gallery = $content->{"result"};
	$gallery = @$gallery[0];

	return $gallery->{"id"};
}

# get_tags_from_NH(galleryID)
# Parses the JSON obtained from the nhentai API to get the tags.
sub get_tags_from_NH {

	my $gID = $_[0];
	my $tag = "";
	my $returned = "";

	my $logger = LANraragi::Model::Plugins::get_logger("nHentai");

	my $URL = "https://nhentai.net/api/gallery/$gID";

	my $ua = Mojo::UserAgent->new;

	my $res = $ua->get($URL)->result;
	
	my $textrep = $res->body;
	$logger->info("nH API returned this JSON: $textrep");

	my $json = $res->json;
	my $tags = $json->{"tags"};

	foreach $tag (@$tags)
	{
		#Try using the "type" attribute to craft a namespace. 
		#The basic "tag" type the NH API adds by default will be ignored here.
		my $namespace = "";

		unless ($tag->{"type"} eq "tag" ) {
			$namespace = $tag->{"type"}.":";
		}

		$returned.=", ".$namespace.$tag->{"name"}; 
		
	}

	$logger->info("Sending the following tags to LRR: $returned");
	return substr $returned, 2; #Strip first comma and space

}

1;