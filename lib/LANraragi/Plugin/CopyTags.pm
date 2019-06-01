package LANraragi::Plugin::CopyTags;

use strict;
use warnings;

use LANraragi::Model::Plugins;

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "Tag Modifier",
        type        => "metadata",
        namespace   => "copytags",
        author      => "Difegue",
        version     => "2.0",
        description => "Apply custom tag modifications. (Add/Delete)",
        parameters  => {"Tags, separated by commas." => "string"}
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my ( $title, $tags, $thumbhash, $file, $oneshotarg, @args ) = @_;

    my $logger = LANraragi::Utils::Generic::get_logger( "Tag Copy", "plugins" );

    #Tags to copy is the first global argument
    $logger->debug("Sending the following tags to LRR: " . $args[0] );
    return ( tags => $args[0] );

}

1;
