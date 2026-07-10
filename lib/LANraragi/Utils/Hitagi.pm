package LANraragi::Utils::Hitagi;

use v5.38;
use utf8;

use IO::Socket qw(SHUT_WR);
use IO::Socket::UNIX;

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
}

sub restart( $process ) {
    return int(hitagi_send( "-r $process" ));
}

sub stop( $process ) {
    return hitagi_send( "-s $process" );
}

sub pid( $process ) {
    return int(hitagi_send( "-p $process" ));
}

sub available {
    return defined($ENV{HITAGI_SOCK});
}

1;
