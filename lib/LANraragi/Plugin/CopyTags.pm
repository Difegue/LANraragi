package LANraragi::Plugin::CopyTags;

use strict;
use warnings;

use LANraragi::Model::Plugins;

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name      => "Tag Copier",
        namespace => "copytags",
        author    => "Difegue",
        version   => "1.0",
        description =>
"This plugin just copies the tags it has in its configuration to any archive it's applied to.",
        global_args => ["Tags to copy"]
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
