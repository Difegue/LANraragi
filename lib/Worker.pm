package Worker;

use strict;
use warnings;
use utf8;
use feature qw(say signatures);
no warnings 'experimental::signatures';

use FindBin;
use Minion;

#As this is a new process, reloading the LRR libs into INC is needed.
BEGIN { unshift @INC, "$FindBin::Bin/../lib"; }

use Mojolicious;    # Needed by Model::Config to read the Redis address/port.
use Mojo::Util qw(steady_time);

use LANraragi::Utils::Logging    qw(get_logger);

use LANraragi::Utils::Minion;
use LANraragi::Model::Config;

# Logger and Database objects
my $logger = get_logger( "Minion Worker", "minion" );

# Windows-only worker. Single threaded and non-forking.
sub initialize_from_new_process {

    $logger->info("Minion Worker started.");

    my $userdir = LANraragi::Model::Config->get_userdir;

    my $miniondb      = LANraragi::Model::Config->get_redisad . "/" . LANraragi::Model::Config->get_miniondb;
    my $redispassword = LANraragi::Model::Config->get_redispassword;

    # If the password is non-empty, add the required delimiters
    if ($redispassword) { $redispassword = "x:" . $redispassword . "@"; }

    say "Minion Worker will use the Redis database at $miniondb";

    my $minion = Minion->new(Redis => "redis://$redispassword$miniondb");

    LANraragi::Utils::Minion::add_tasks( $minion );
    $logger->debug("Registered tasks with Minion.");

    my $worker = $minion->repair->worker->register;
    my $running = 1;

    my $last_heartbeat = 0; 
    my $last_repair = 0;
    while ($running) {
        local $SIG{INT} = sub { $running = 0 };

        while(my $job = $worker->dequeue(3)) {
            if (defined(my $err = $job->execute)) {
                $job->fail($err);
            } else {
                $job->finish;
            }
        }
        $worker->register and $last_heartbeat = steady_time if ($last_heartbeat + 300) < steady_time;

        if (($last_repair + 21600) < steady_time) {
            $minion->repair;
            $last_repair = steady_time;
        }
    }
    $worker->unregister;
}

__PACKAGE__->initialize_from_new_process unless caller;

1;
