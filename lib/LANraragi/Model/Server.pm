package LANraragi::Model::Server;

use strict;
use warnings;
use utf8;

use Exporter 'import';
our @EXPORT_OK = qw(set_restart_pending clear_restart_pending is_restart_pending);

use constant SERVER_KEY => "LRR_SERVER";

# Signal that LRR needs a restart.
sub set_restart_pending {
    my ($redis) = @_;
    $redis->hset( SERVER_KEY, "restart_pending", 1 );
}

# Clear need-restart flag.
sub clear_restart_pending {
    my ($redis) = @_;
    $redis->hdel( SERVER_KEY, "restart_pending" );
}

# Whether a restart is currently pending. Returns 1 or 0.
sub is_restart_pending {
    my ($redis) = @_;
    return $redis->hget( SERVER_KEY, "restart_pending" ) ? 1 : 0;
}

1;
