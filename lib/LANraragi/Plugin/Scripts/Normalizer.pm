package LANraragi::Plugin::Scripts::Normalizer;

use strict;
use warnings;
no warnings 'uninitialized';

use LANraragi::Utils::Logging qw(get_logger);
use LANraragi::Utils::Database qw(redis_encode redis_decode invalidate_cache);
use LANraragi::Model::Config;

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name      => "The Normalizer",
        type      => "script",
        namespace => "unicodenorm",
        author    => "Difegue",
        version   => "1.0",
        description =>
          "Normalize all metadata in the database to Unicode NFC. <br>Consider running this once if you're upgrading from 0.7.6."
    );

}

# Mandatory function to be implemented by your script
sub run_script {
    shift;
    my $lrr_info = shift;    # Global info hash

    my $logger = get_logger( "Normalizer", "plugins" );
    my $redis  = LANraragi::Model::Config->get_redis;

    my @keys = $redis->keys('????????????????????????????????????????');    #40-character long keys only => Archive IDs

    #Parse the archive list and add them to JSON.
    foreach my $id (@keys) {

        my %hash = $redis->hgetall($id);
        my ( $name, $title, $tags, $thumbhash ) = @hash{qw(name title tags thumbhash)};

        # Decode and re-encode, redis_encode applies NFC
        ( $_ = redis_decode($_) ) for ( $name, $title, $tags );
        ( $_ = redis_encode($_) ) for ( $name, $title, $tags );

        # hset again and we're done
        $redis->hset( $id, "name",  $name );
        $redis->hset( $id, "title", $title );
        $redis->hset( $id, "tags",  $tags );
    }

    invalidate_cache();
    $redis->quit();

    return ( success => 1 );
}

1;
