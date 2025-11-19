use strict;
use warnings;
use utf8;

use Test::More;

use POSIX ":sys_wait_h";
use File::Temp qw(tempdir);
use Time::HiRes qw(sleep);
use Sys::CpuAffinity;

BEGIN { use_ok('LANraragi::Utils::RotatingLog'); }

sub log_dist {
    my ($tmpdir, $create_before_fork, $children, $messages_per_child, $batches) = @_;
    my $message_size    = 64;
    my $logpath         = "$tmpdir/lanraragi.log";

    my ($final_ok, $final_details, $final_gz) = (1, [], 0);

    BATCH: for my $batch (1..$batches) {
        my $shared_log;
        if ($create_before_fork) {
            $shared_log = LANraragi::Utils::RotatingLog->new(
                path                => $logpath,
                logfile             => 'lanraragi',
                tempdir             => $tmpdir,
                retention_count     => 5,
                max_rotation_size   => 4096,
            );
        }

        my @pids;
        my %pid_to_cid;
        for my $cid (1..$children) {
            my $pid = fork();
            die "fork failed: $!" unless defined $pid;
            if ($pid == 0) {
                my $exit_code = 0;
                my $payload = "child=$cid " . ("x" x $message_size);
                eval {
                    my $log = $shared_log // LANraragi::Utils::RotatingLog->new(
                        path    => $logpath,
                        logfile => 'lanraragi',
                        tempdir => $tmpdir
                    );
                    for my $i (1..$messages_per_child) {
                        $log->info("$payload i=$i");
                        sleep(0.0005) if ($i % 100 == 0);
                    }
                    1;
                } or do {
                    my $err = $@;
                    my $err_path = "$tmpdir/child_$cid.err";
                    if ( open my $efh, '>', $err_path ) {
                        print {$efh} $err;
                        close $efh;
                    }
                    $exit_code = 2;
                };
                exit $exit_code;
            }
            push @pids, $pid;
            $pid_to_cid{$pid} = $cid;
        }

        my $all_ok = 1;
        my @details;
        for my $pid (@pids) {
            my $kid         = waitpid($pid, 0);
            my $exit_status = $? >> 8;
            my $signal      = $? & 127;
            my $dumped_core = $? & 128 ? 1 : 0;
            my $cid         = $pid_to_cid{$pid};
            my $err_path    = "$tmpdir/child_$cid.err";
            my $err_msg     = "";
            if ( -e $err_path && open my $rfh, '<', $err_path ) {
                local $/;
                $err_msg = <$rfh>;
                close $rfh;
            }
            push @details, {
                pid     => $pid,
                cid     => $cid,
                exit    => $exit_status,
                sig     => $signal,
                core    => $dumped_core,
                error   => $err_msg
            };
            $all_ok &&= ($kid == $pid && $exit_status == 0);
        }

        opendir(my $dh, $tmpdir) or die "Cannot open dir $tmpdir: $!";
        my @gz = grep { /^lanraragi\.log\.\d+\.gz$/ } readdir($dh);
        closedir $dh;

        $final_ok       = $all_ok;
        $final_details  = \@details;
        $final_gz       = scalar(@gz);

        last BATCH if (!$all_ok);
    }

    return ($final_ok, $final_details, $final_gz);
}

note('testing init-time concurrent log rotation...');
{
    my $tmpdir              = tempdir( CLEANUP => 1 );
    my $create_before_fork  = 0;
    my $num_cpus            = Sys::CpuAffinity::getNumCpus();
    my $children            = $num_cpus < 16 ? $num_cpus : 16;
    my $messages_per_child  = 2000;
    my $batches             = 6;
    my ($ok, $details, $gz) = log_dist(
        $tmpdir,
        $create_before_fork,
        $children,
        $messages_per_child,
        $batches
    );
    # unless ($ok) {
    #     for my $d (@$details) {
    #         next if $d->{exit} == 0;
    #         diag("init-time: child $d->{cid} (pid $d->{pid}) exit=$d->{exit} sig=$d->{sig} core=$d->{core}");
    #         diag("init-time: child $d->{cid} error: $d->{error}") if $d->{error};
    #     }
    # }
    ok( $ok, "init-time concurrent rotation successful" );
    ok( $gz >= 1, "append-time rotation produced gzip archives" );
}

note('testing append-time log rotation...');
{
    my $tmpdir              = tempdir( CLEANUP => 1 );
    my $create_before_fork  = 1;
    my $children            = 1;
    my $messages_per_child  = 100000;
    my $batches             = 6;
    my ($ok, $details, $gz) = log_dist(
        $tmpdir,
        $create_before_fork,
        $children,
        $messages_per_child,
        $batches
    );
    # unless ($ok) {
    #     for my $d (@$details) {
    #         next if $d->{exit} == 0;
    #         diag("append-time: child $d->{cid} (pid $d->{pid}) exit=$d->{exit} sig=$d->{sig} core=$d->{core}");
    #         diag("append-time: child $d->{cid} error: $d->{error}") if $d->{error};
    #     }
    # }
    ok( $ok, "append-time log rotation successful" );
    ok( $gz >= 1, "append-time rotation produced gzip archives" );
}

note('testing concurrent append-time concurrent log rotation...');
{
    my $tmpdir              = tempdir( CLEANUP => 1 );
    my $create_before_fork  = 1;
    my $children            = 8;
    my $messages_per_child  = 9000;
    my $batches             = 6;
    my ($ok, $details, $gz) = log_dist(
        $tmpdir,
        $create_before_fork,
        $children,
        $messages_per_child,
        $batches
    );
    # unless ($ok) {
    #     for my $d (@$details) {
    #         next if $d->{exit} == 0;
    #         diag("concurrent: child $d->{cid} (pid $d->{pid}) exit=$d->{exit} sig=$d->{sig} core=$d->{core}");
    #         diag("concurrent: child $d->{cid} error: $d->{error}") if $d->{error};
    #     }
    # }
    ok( $ok, "prefork concurrent append successful" );
    ok( $gz >= 1, "concurrent append produced gzip archives" );
}

done_testing();

