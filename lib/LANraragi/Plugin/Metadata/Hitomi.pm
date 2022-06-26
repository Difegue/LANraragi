package LANraragi::Plugin::Metadata::Hitomi;

use strict;
use warnings;
use utf8;

#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use URI::Escape;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json);

#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_plugin_logger);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "Hitomi",
        type        => "metadata",
        namespace   => "hitomiplugin",
        author      => "doublewelp",
        version     => "0.1",
        description => "Searches Hitomi.la for tags matching your archive. 
          <br>Supports reading the ID from files formatted as \"{Id} Title\" (curly brackets optional)
		  <br><i class='fa fa-exclamation-circle'></i> This plugin will use the source: tag of the archive if it exists (ex.: source:https://hitomi.la/galleries/XXXXX).",
		parameters  => [ { type => "bool", desc => "Add gender emojis ( ♂️ / ♀️) to tags" },
						 { type => "bool", desc => "Save archive title" }
						],
        icon =>
           "data:image/png;base64,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",
        oneshot_arg => "Hitomi Gallery URL (Will attach tags matching this exact gallery to your archive)"
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;    # Global info hash
    my ($gendertag, $savetitle) = @_;    # Plugin parameters
    my $logger = get_plugin_logger();

    # Work your magic here - You can create subs below to organize the code better
    my $galleryID = "";

    # Quick regex to get the nh gallery id from the provided url or source tag.
    if ( $lrr_info->{oneshot_param} =~ /.*\/g\/([0-9]+).*/ ) {
        $galleryID = $1;
        $logger->debug("Skipping search and using gallery $galleryID from oneshot args");
    } elsif ( $lrr_info->{existing_tags} =~ /.*source:\s*(?:https?:\/\/)?hitomi\.la\/galleries\/([0-9]*).*/gi ) {

        # Matching URL Scheme like 'https://' is only for backward compatible purpose.
        $galleryID = $1;
        $logger->debug("Skipping search and using gallery $galleryID from source tag");
    } else {

        #Get Gallery ID by hand if the user didn't specify a URL
        $galleryID = get_gallery_id_from_title( $lrr_info->{archive_title} );
    }

    # Did we detect a Hitomi gallery?
    if ( defined $galleryID ) {
        $logger->debug("Detected Hitomi gallery id is $galleryID");
    } else {
        $logger->info("No matching Hitomi Gallery Found!");
        return ( error => "No matching Hitomi Gallery Found!" );
    }

    #If no tokens were found, return a hash containing an error message.
    #LRR will display that error to the client.
    if ( $galleryID eq "" ) {
        $logger->info("No matching Hitomi Gallery Found!");
        return ( error => "No matching Hitomi Gallery Found!" );
    }

    my %hashdata = get_tags_from_Hitomi( $galleryID, $gendertag, $savetitle);

    $logger->info( "Sending the following tags to LRR: " . $hashdata{tags} );

    #Return a hash containing the new metadata - it will be integrated in LRR.
    return %hashdata;
}

######
## Hitomi Specific Methods
######

sub get_gallery_id_from_title {

    my ($title) = @_;

    my $logger = get_plugin_logger();

	$logger->debug("Attempting to parse id from title $title");
    if ( $title =~ /\{?(\d+)\}?/gm ) {
        $logger->debug("Got $1 from file.");
        return $1;
    }

    return;
}

# retrieves js from Hitomi
sub get_js_from_hitomi {

    my ($gID) = @_;
	
	my $logger = get_plugin_logger();
    
    my $gJS = "https://ltn.hitomi.la/galleries/$gID.js";
	
	$logger->debug("Hitomi JS: $gJS");

	my $ua = Mojo::UserAgent->new;
	my $res = $ua->get($gJS)->result;
	$logger->debug("Hitomi raw JS: ". $res->body);
	
	if ( $res->is_error ) {
        return;
    }
	
	my $jsonstring = "{}";
	if ( $res->body =~ /var.*galleryinfo.*= (.*)/gmi ) {
        $jsonstring = $1;
    }

    $logger->debug("Tentative new JSON: $jsonstring");

	$logger->debug("Beginning JSON decode");
    my $json = decode_json $jsonstring;
	$logger->debug("JSON decode successful");
    return $json;
	
}

#Extract tags from Hitomi JSON
sub get_tags_from_taglist {

    my ($json, $gendertag) = @_;
	
	my $logger = get_plugin_logger();

	$logger->debug("Extracting tags array");
    my @tags_list = @{ $json->{"tags"} };
    my @tags      = ();
	
	$logger->debug("Cycling tags array");
    foreach my $tag (@tags_list) {
		my $name = $tag->{"tag"};
        my $male = $tag->{"male"};
        my $female = $tag->{"female"};
		
		if($gendertag) {
			if($male eq 1){
				$name = $name . " ♂️"
			}
			
			if($female eq 1){
				$name = $name . " ♀️"
			}
		}

		push( @tags, $name );
    }
	
	$logger->debug("Extracting parodies array");
    my @parodies_list = @{ $json->{"parodys"} };
	$logger->debug("Cycling parodies array");
    foreach my $tag (@parodies_list) {
		my $name = $tag->{"parody"};

		push( @tags, "parody:" . $name );
    }
	
	$logger->debug("Extracting artists array");
    my @artists_list = @{ $json->{"artists"} };
	$logger->debug("Cycling artists array");
    foreach my $tag (@artists_list) {
		my $name = $tag->{"artist"};

		push( @tags, "artist:" . $name );
    }
	
	$logger->debug("Extracting groups array");
    my @group_list = @{ $json->{"groups"} };
	$logger->debug("Cycling groups array");
    foreach my $tag (@group_list) {
		my $name = $tag->{"group"};

		push( @tags, "group:" . $name );
    }
	
	if(defined $json->{"characters"}) {
		$logger->debug("Extracting characters array");
		my @characters_list = @{ $json->{"characters"} };
		$logger->debug("Cycling characters array");
		foreach my $tag (@group_list) {
			my $name = $tag->{"character"};

			push( @tags, "character:" . $name );
		}
	}
	
	$logger->debug("Extracting type value");
	push( @tags, "type:" . $json->{"type"});
	
	$logger->debug("Extracting language value");
	push( @tags, "language:" . $json->{"language"});
	
    return @tags;
}

sub get_title_from_json {
    my ($json) = @_;
    return $json->{"title"};
}

sub get_tags_from_Hitomi {

    my ( $gID , $gendertag, $savetitle) = @_;

    my %hashdata = ( tags => "" );
	
	my $logger = get_plugin_logger();

    my $json = get_js_from_hitomi($gID);
	$logger->debug("Got fully formed JS from Hitomi");

    if ($json) {
        my @tags = get_tags_from_taglist($json, $gendertag);
        push( @tags, "source:https://hitomi.la/galleries/$gID.html" ) if ( @tags > 0 );
		$hashdata{tags} = join( ', ', @tags );
		$hashdata{title} = get_title_from_json($json) if ($savetitle);
    }

    return %hashdata;
}

1;
