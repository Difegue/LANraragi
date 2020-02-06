package LANraragi::Plugin::Metadata::DateAdded;

use strict;
use warnings;

#Plugins can freely use all Perl packages already installed on the system 
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use Mojo::UserAgent;

use LANraragi::Model::Plugins;

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "Date Added",
        type        => "metadata",
        namespace   => "DateAddedPlugin",
        author      => "Utazukin",
        version     => "0.2",
        description => "Adds the unix time stamp of the date the archive was added as a tag under the \"date_added\" namespace.",
        icon        => "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAACXBIWXMAAAsTAAALEwEAmpwYAAAA\nB3RJTUUH4wYCFQY4HfiAJAAAAB1pVFh0Q29tbWVudAAAAAAAQ3JlYXRlZCB3aXRoIEdJTVBkLmUH\nAAADKUlEQVQ4y6WVsUtrVxzHP+fmkkiqJr2CQWKkvCTwJgkJDpmyVAR1cVOhdq04tHNB7BD8A97S\nXYkO3dRRsMSlFoIOLYFEohiDiiTNNeaGpLn5dRDv06ev75V+4SyH8/2c3/n+zuEoEeFTqtfrb5RS\nJZ/P98m1iMirI5fLMT8/L+FwWEKhkIRCIXn79q2srKxIpVL5qE/7cINms8ny8rIkEgkpl8skk0lm\nZ2eZmZkhHo+TzWYJBoOyvr4u7Xb7RYHq6ZEvLi6Ynp6WVqvFwsIC4+PjRCIRDMNAKcXNzQ2lUols\nNsvOzg6xWIxMJqOeRuEAq9UqqVRKhoaGmJubY2pqCl3XiUajXF5e0t/fz+DgIIVCAbfbzdbWFtvb\n24yMjLC/v6+eZWjbNqurq5JIJGRtbU0syxLbtsU0TXmqXq8njUZDRERubm4knU6LYRiSyWScDBER\nGo0G4XBYFhcX5fz8XP4yTbGLf0hnd0s+plqtJru7u7K0tCSRSEQ6nc77ppycnFCv10kmk4yOjoII\n2kiIv3//lfbGu1dvh1KKVCrF2NgYmqaRy+UAHoCHh4f4fD4mJiZwuVz4fT74YhDvTz/TPv2TX378\ngWKx+Azo9/sZGBhAKYVhGBSLxa8doGmaABiGQT6fp9VqPbg0jcr897w7+I3FxUVs23aAlmVxe3tL\nPB7n/v6eWq22D6A/lq+UotlsEo1G8Xg8jvFNOMzCN99iGF/icrmc+b6+PrxeL6enp7hcLpR6aLT+\nuEDTNEqlErFYDMuy8Hq9AHg8HpaXv3uRYbfbRdM0TNNE096/Dweo6zoHBwfE43F0XXeAjyf4UJVK\nhUql8iwGJ8NHeb1e9vb2CAaDADQajRcgy7IACAQCHB0d/TtQ0zQuLi7Y3Nzk+vqacrkMwNXVFXd3\nd7Tbbc7Ozuh0OmxsbHB1dfViQ/21+3V8fIxpmkxOTmKaJrZt0263sW0b27ZJp9M0m010XX8RhwN8\nNPV6PQCKxSL5fB7DMAgEAnS7XarVKtVqFbfbjVIK27ZRSjkeB9jtdikUChQKBf6vlIg4Gb3Wzc/V\n8PDwV36//1x9zhfwX/QPryPQMvGWTdEAAAAASUVORK5CYII=",
        parameters  => [
          {type => "bool", desc => "Use file modified time instead of current time."}
        ],
        oneshot_arg => "Use file modified time (yes/true), or use current time (no/false). <br/>Leaving blank uses the global setting (default: current time)"
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    #LRR gives your plugin the recorded title for the file, the filesystem path to the file, and the custom arguments if available.
    shift;
    my ($title, $tags, $thumbhash, $file, $oneshotarg, $use_filetime) = @_;

    #Use the logger to output status - they'll be passed to a specialized logfile and written to STDOUT.
    my $logger = LANraragi::Utils::Logging::get_logger("Date Added Plugin","plugins");

    #Work your magic here - You can create subroutines below to organize the code better

    $logger->debug("Processing file: " . $file);
    my $newtags = "";
    my $oneshot_file_time = $oneshotarg =~ /^(yes|true)$/i;
    my $oneshot_current_time = $oneshotarg =~ /^(no|false)$/i;

    if ($oneshot_file_time || ($use_filetime && !$oneshot_current_time)) {
		$logger->info("Using file date");
		$newtags = "date_added:" . (stat($file))[9]; #9 is the unix time stamp for date modified.
    } else {
		$logger->info("Using current date");
		$newtags = "date_added:" . time();
    }
    return ( tags => $newtags );
}

1;

