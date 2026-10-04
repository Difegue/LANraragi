package LANraragi::Utils::Hitagi;

use v5.36;
use utf8;

use IO::Socket qw(SHUT_WR);
use IO::Socket::UNIX;

my $available = defined($ENV{HITAGI_SOCK});

sub hitagi_send ( $command ) {
    my $client = IO::Socket::UNIX->new(
        Type => SOCK_STREAM(),
        Peer => $ENV{HITAGI_SOCK},
    );

    $client->send( $command );
    $client->shutdown( SHUT_WR );

    my $reply = "";
    $client->recv( $reply, 512 );

    $client->close();

    return $reply;
}

sub restart_all() {
    hitagi_send( "-r all" );
    return 0;
}

sub restart( $process ) {
    return int(hitagi_send( "-r $process" ));
}

sub stop( $process ) {
    return int(hitagi_send( "-s $process" ));
}

sub pid( $process ) {
    return int(hitagi_send( "-p $process" ));
}

sub available {
    return $available;
}

1;
