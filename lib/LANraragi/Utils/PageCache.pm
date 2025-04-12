package LANraragi::Utils::PageCache;

use v5.36;

use strict;
use warnings;
use utf8;

use LANraragi::Utils::Logging  qw(get_logger);

# Contains all functions related to caching entire pages
use Exporter 'import';
our @EXPORT_OK = qw(fetch put);

# Fetches data from cache if available. Returns undef if nothing is there
sub fetch( $key ) {
    my $logger = get_logger( "PageCache", "lanraragi" );
    $logger->debug("Fetch $key");

    # TODO: Implement filesystem caching, if that's needed!
    my $redis  = LANraragi::Model::Config->get_redis;
    my $content = $redis->get($key);
    if (defined $content) {
        $logger->debug("Cache HIT for $key");
    } else {
        $logger->debug("Cache MISS for $key");
    }
    return $content;
}

# Attempts to store data in the cache. Do not assume that fetch will work immediately after, cache may be disabled etc
sub put( $key, $content ) {
    my $logger = get_logger( "PageCache", "lanraragi" );
    $logger->debug("Put $key");

    # TODO: Implement filesystem caching, if that's needed!
    my $redis  = LANraragi::Model::Config->get_redis;

    # Some random long expiry
    $redis->set($key,  $content, 'EX', 999999);
}

1;
