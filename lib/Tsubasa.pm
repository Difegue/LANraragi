package Worker;

use v5.38;
use utf8;

use local::lib;

use FindBin;
use Sys::CpuAffinity;
use Minion;
use Config;

#As this is a new process, reloading the LRR libs into INC is needed.
BEGIN { unshift @INC, "$FindBin::Bin/../lib"; }

use Mojolicious;    # Needed by Model::Config to read the Redis address/port.
use Mojo::Util qw(steady_time);

use LANraragi::Utils::Logging    qw(get_logger);

use LANraragi::Utils::Minion;
use LANraragi::Model::Config;

use constant IS_UNIX => ( $Config{osname} ne 'MSWin32' );

# Logger and Database objects
my $logger = get_logger( "Minion Worker", "minion" );

# Minion worker
sub initialize_from_new_process {

    if ( !IS_UNIX ) {
        # Enable autoflush
        $| = 1;
    }

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

    my $worker = $minion->repair->worker;

    if ( IS_UNIX ) {
        my $numcpus = Sys::CpuAffinity::getNumCpus();
        $logger->info("Starting new Minion worker in subprocess with $numcpus parallel jobs.");

        $worker->status->{jobs} = $numcpus;
        $worker->on( dequeue => sub { pop->once( spawn => \&_spawn ) } );

        $worker->run;
    } else {
        $worker->register;
        my $running = 1;

        local $SIG{INT} = sub { $running = 0 };
        local $SIG{TERM} = sub { $running = 0 };

        my $last_heartbeat = 0; 
        my $last_repair = 0;
        while ($running) {
            while(my $job = $worker->dequeue(3)) {
                if (defined(my $err = eval { $job->execute })) {
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
}

sub _spawn {
    my ( $job, $pid )  = @_;
    my ( $id,  $task ) = ( $job->id, $job->task );
    my $logger = get_logger( "Minion Worker", "minion" );
    $job->app->log->debug(qq{Process $pid is performing job "$id" with task "$task"});
}

__PACKAGE__->initialize_from_new_process unless caller;

1;
