package LANraragi::Plugin::Scripts::nHentaiSourceConverter;

use strict;
use warnings;
no warnings 'uninitialized';

use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::Database qw(invalidate_cache);
use LANraragi::Model::Config;

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name      => "nHentai Source Converter",
        type      => "script",
        namespace => "nhsrcconv",
        author    => "Guerra24",
        version   => "1.0",
        description =>
          "Converts \"source:id\" tags with 6 or less digits into \"source:https://nhentai.net/g/id\""
    );

}

# Mandatory function to be implemented by your script
sub run_script {
    shift;
    my $lrr_info = shift;    # Global info hash

    my $logger = get_plugin_logger();
    my $redis  = LANraragi::Model::Config->get_redis;

    my @keys = $redis->keys('????????????????????????????????????????');    #40-character long keys only => Archive IDs

    my $count = 0;
    #Parse the archive list and add them to JSON.
    foreach my $id (@keys) {

        my %hash = $redis->hgetall($id);
        my ( $tags ) = @hash{qw(tags)};

        if ( $tags =~ s/source:(\d{1,6})/source:https:\/\/nhentai\.net\/g\/$1/igm ) {
            $count++;
        }

        $redis->hset( $id, "tags",  $tags );
    }

    invalidate_cache();
    $redis->quit();

    return ( modified => $count );
}

1;
