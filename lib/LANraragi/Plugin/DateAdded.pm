package LANraragi::Plugin::DateAdded;

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
        name  => "Date Added",
        namespace => "DateAddedPlugin",
        author => "Utazukin",
        version  => "0.1",
        description => "Adds the date the archive was added as a tag.",
        oneshot_arg => "Use file modified time.",
		global_args => ["Use file modified time"]
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    #LRR gives your plugin the recorded title for the file, the filesystem path to the file, and the custom arguments if available.
    shift;
    my ($title, $tags, $thumbhash, $file, $oneshotarg, @args) = @_;

    #Use the logger to output status - they'll be passed to a specialized logfile and written to STDOUT.
    my $logger = LANraragi::Utils::Generic::get_logger("Date Added Plugin","plugins");

    #Work your magic here - You can create subroutines below to organize the code better

    $logger->debug("Processing file: " . $file);
    my $newtags = "";
    if ($oneshotarg ne "no" && $oneshotarg ne "false" && ($args[0] eq "yes" || $args[0] eq "true" || $oneshotarg eq "yes" || $oneshotarg eq "true")) {
		$logger->info("Using file date");
		$newtags = "date_added:" . (stat($file))[9]; #9 is the unix time stamp for date modified.
    } else {
		$logger->info("Using current date");
		$newtags = "date_added:" . time();
    }
    return ( tags => $newtags );
}

1;

