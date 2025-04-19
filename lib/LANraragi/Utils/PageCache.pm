package LANraragi::Utils::PageCache;

use v5.36;

use strict;
use warnings;
use utf8;

use LANraragi::Utils::Logging  qw(get_logger);
use CHI;
use LANraragi::Utils::TempFolder qw(get_temp);

# Contains all functions related to caching entire pages
use Exporter 'import';
our @EXPORT_OK = qw(fetch put);

my $cache = undef;

sub initialize() {
    my $logger = get_logger( "PageCache", "lanraragi" );
    my $disk_size = LANraragi::Model::Config->get_tempmaxsize."m";
    $logger->debug("Initializing cache, disk size: ".$disk_size);

    $cache = CHI->new(
        driver     => 'FastMmap',
        cache_size => $disk_size,
        root_dir => get_temp,
    );
}

# Fetches data from cache if available. Returns undef if nothing is there
sub fetch( $key ) {
    if (!defined($cache)) {
        initialize;
    }
    my $logger = get_logger( "PageCache", "lanraragi" );
    $logger->debug("Fetch $key");

    my $content = $cache->get($key);
    if (defined $content) {
        $logger->debug("Cache HIT for $key");
    } else {
        $logger->debug("Cache MISS for $key");
    }
    return $content;
}

# Attempts to store data in the cache. Do not assume that fetch will work immediately after, cache may be disabled etc
sub put( $key, $content ) {
    if (!defined($cache)) {
        initialize;
    }
    my $logger = get_logger( "PageCache", "lanraragi" );
    $logger->debug("Put $key");

    $cache->set($key, $content);
}

sub clear() {
    if (!defined($cache)) {
        initialize;
    }

    my $logger = get_logger( "PageCache", "lanraragi" );
    $logger->debug("Clearing cache");
    $cache->clear();
}

1;
