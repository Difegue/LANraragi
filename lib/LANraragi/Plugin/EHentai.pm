package LANraragi::Plugin::EHentai;

use strict;
use warnings;

#Plugins can freely use all Perl packages already installed on the system 
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use URI::Escape;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::UserAgent;

#Meta-information about your plugin.
sub plugin_info {

	return (
		#Standard metadata
	    name  => "E-Hentai",
	    namespace => "ehplugin",
	    author => "Difegue",
	    version  => "1.0",
	    description => "Searches g.e-hentai/exhentai for tags matching your archive.",
	    #If your plugin uses/needs custom arguments, input their name here. 
	    #This name will be displayed in plugin configuration next to an input box for global arguments, and in archive edition for one-shot arguments.
	    global_arg => "Exhentai Cookie ID/Pass (Use the following syntax: ipb_member_id/ipb_hash_pass )",
	    oneshot_arg => "E-H Gallery URL (Will attach tags matching this exact gallery to your archive)"
	);

}

#Mandatory function to be implemented by your plugin
sub get_tags {

	#LRR gives your plugin the recorded title for the file, the current tags, the filesystem path to the file, and the custom arguments if available.
    my ($title, $tags, $thumbhash, $file, $globalarg, $oneshotarg, $logger) = @_;

    #Work your magic here - You can create subs below to organize the code better
    my $apiJSON;

    #Setup Cookies if they're set and use exhentai

    #Craft URL for Text Search on EH if there's no user argument
    if ($oneshotarg eq "") {
    	$apiJSON = &lookup_by_title($title);
    } else {
    	#Quick regex to get the E-H archive ids from the provided url.
    	if ($oneshotarg =~ /.*\/g\/([0-9]*)\/([0-z]*)\/*.*/ ) { 
			$apiJSON = qq({"method": "gdata","gidlist": [[$1,"$2"]]});
		}
    }

    #Use the logger to output status - they'll be passed to LRR's standard output and a specialized logfile.
    $logger->info("JSON passed to the EH API is $apiJSON");

    my $newtags = &get_tags_from_EH($apiJSON);

    #Return a hash containing the new metadata - it will be integrated in LRR.
    return (
			title => $title,
		    tags => $newtags
			);
}

######
## EH Specific Methods
######

sub lookup_by_title {

	my $title = $_[0];

	my $URL = "http://g.e-hentai.org/".
			"?f_doujinshi=1&f_manga=1&f_artistcg=1&f_gamecg=1&f_western=1&f_non-h=1&f_imageset=1&f_cosplay=1&f_asianporn=1&f_misc=1".
			"&f_search=".uri_escape($title)."&f_apply=Apply+Filter";

	#TODO: implement thumbhash mode
	#search with image SHA hash
	#	$URL = "http://g.e-hentai.org/".
	#			"?f_doujinshi=1&f_manga=1&f_artistcg=1&f_gamecg=1&f_western=1&f_non-h=1&f_imageset=1&f_cosplay=1&f_asianporn=1&f_misc=1".
	#			"&f_search=Search+Keywords&f_apply=Apply+Filter&f_shash=$thumbhash&fs_similar=1";

	return &ehentai_parse($URL);
}

#eHentaiLookup(URL)
#Performs a remote search on g.e-hentai, and builds the matching JSON to send to the API for data.
sub ehentai_parse() {

 	my $URL = $_[0];

	my $ua = Mojo::UserAgent->new;

    my $content = $ua->get($URL)->result->body;
	
    #TODO: Improve this with the Mojo built-in DOM parser

	#now for the parsing of the HTML we obtained.
	#the first occurence of <tr class="gtr0"> matches the first row of the results. 
	#If it doesn't exist, what we searched isn't on E-hentai.
	my @benis = split('<tr class="gtr0">', $content);

	#Inside that <tr>, we look for <div class="it5"> . the <a> tag inside has an href to the URL we want.
	my @final = split('<div class="it5">',$benis[1]);

	my $url = (split('e-hentai.org/g/',$final[1]))[1];
	
	my @values = (split('/',$url));

	my $gID = $values[0];
	my $gToken = $values[1];

	#Returning shit yo
	return qq({"method": "gdata","gidlist": [[$gID,"$gToken"]]});
}

#getTagsFromEHAPI(JSON)
#Executes an e-hentai API request with the given JSON and returns 
sub get_tags_from_EH {
	
	my $uri = 'http://e-hentai.org/api.php';
	my $json = $_[0];

	my $ua = Mojo::UserAgent->new;

	#Execute the request
	my $jsonresponse = $ua->post($uri => json => $json)->result->json;
	my $hash = decode_json($jsonresponse);

	unless (exists $hash->{"error"}){

		my $data = $hash->{"gmetadata"};
		my $tags = @$data[0]->{"tags"};

		my $return = join(", ", @$tags);
		return $return; #Strip first comma
	}	
	else #if an error occurs(no tags available) return an empty string.
		{ return ""; }
}

1;