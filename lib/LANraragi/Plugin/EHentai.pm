package LANraragi::Plugin::EHentai;

use strict;
use warnings;

#Plugins can freely use all Perl packages already installed on the system 
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use URI::Escape;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::UserAgent;

#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;

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

	#LRR gives your plugin the recorded title for the file, the filesystem path to the file, and the custom arguments if available.
	shift;
    my ($title, $thumbhash, $file, $globalarg, $oneshotarg) = @_;

    my $logger = LANraragi::Model::Plugins::get_logger("E-Hentai");

    #Work your magic here - You can create subs below to organize the code better
    my $gID = "";
    my $gToken = "";

    #TODO: Setup Cookies if they're set and use exhentai

	#Quick regex to get the E-H archive ids from the provided url.
	if ($oneshotarg =~ /.*\/g\/([0-9]*)\/([0-z]*)\/*.*/ ) { 
		$gID = $1;
		$gToken = $2;
	} else {
		#Craft URL for Text Search on EH if there's no user argument
		($gID, $gToken) = &lookup_by_title($title);
	}

    #Use the logger to output status - they'll be passed to a specialized logfile and written to STDOUT.
    $logger->info("EH API Tokens are $gID / $gToken");

    #TODO: Error handling for empty tokens here - needs handling for an "error" field on the hash to be passed upstream.

    my $newtags = &get_tags_from_EH($gID, $gToken);

    #Return a hash containing the new metadata - it will be integrated in LRR.
    return (
		    tags => $newtags
			);
}

######
## EH Specific Methods
######

sub lookup_by_title {

	my $title = $_[0];
	my $logger = LANraragi::Model::Plugins::get_logger("E-Hentai");

	my $URL = "http://e-hentai.org/".
			"?f_doujinshi=1&f_manga=1&f_artistcg=1&f_gamecg=1&f_western=1&f_non-h=1&f_imageset=1&f_cosplay=1&f_asianporn=1&f_misc=1".
			"&f_search=".uri_escape($title)."&f_apply=Apply+Filter";

	#TODO: implement thumbhash mode
	#search with image SHA hash
	#	$URL = "http://e-hentai.org/".
	#			"?f_doujinshi=1&f_manga=1&f_artistcg=1&f_gamecg=1&f_western=1&f_non-h=1&f_imageset=1&f_cosplay=1&f_asianporn=1&f_misc=1".
	#			"&f_search=Search+Keywords&f_apply=Apply+Filter&f_shash=$thumbhash&fs_similar=1";

	 $logger->info("Using URL $URL (first pass)");

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
	return ($gID,$gToken);
}

#getTagsFromEHAPI(gID, gToken)
#Executes an e-hentai API request with the given JSON and returns 
sub get_tags_from_EH {
	
	my $uri = 'http://e-hentai.org/api.php';
	my $gID = $_[0];
	my $gToken = $_[1];

	my $ua = Mojo::UserAgent->new;

	my $logger = LANraragi::Model::Plugins::get_logger("E-Hentai");

	#Execute the request
	my $jsonresponse = $ua->post($uri => json => {method => "gdata", gidlist => [[$gID,$gToken]], namespace => 1})->result->json;

	unless (exists $jsonresponse->{"error"}){

		my $data = $jsonresponse->{"gmetadata"};
		my $tags = @$data[0]->{"tags"};

		my $return = join(", ", @$tags);
		$logger->info("Sending the following tags to LRR: $return");
		return $return;
	}	
	else #if an error occurs(no tags available) return an empty string.
		{ return ""; }
}

1;