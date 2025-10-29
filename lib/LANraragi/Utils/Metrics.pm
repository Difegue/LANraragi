package LANraragi::Utils::Metrics;

use strict;
use warnings;
use utf8;

# Extract endpoint path from request and normalize to route templates to prevent cardinality explosion.
# During normalization, query parameters are removed and path parameters are replaced with router placeholders.
# If a path is undefined, return "/unknown".
sub extract_endpoint {
    my $path = shift;

    return "/unknown" unless defined $path;

    # Remove query parameters and fragments
    $path =~ s/[?#].*$//;

    # Handle root path
    return "/" if $path eq "" || $path eq "/";

    # Archive endpoints
    $path =~ s{/api/archives/[a-f0-9]{40}(/|$)}{/api/archives/:id$1}g;
    $path =~ s{/api/archives/:id/progress/\d+}{/api/archives/:id/progress/:page};

    # Category endpoints
    $path =~ s{/api/categories/bookmark_link/[^/]+(/|$)}{/api/categories/bookmark_link/:id$1}g;
    $path =~ s{/api/categories/[^/]+/[a-f0-9]{40}(/|$)}{/api/categories/:id/:archive$1}g;
    $path =~ s{/api/categories/([^/]+)(/|$)}{
        my ($segment, $trailing) = ($1, $2);
        if ($segment eq 'bookmark_link') {
            "/api/categories/bookmark_link$trailing";
        } else {
            "/api/categories/:id$trailing";
        }
    }ge;

    # Tankoubon endpoints  
    $path =~ s{/api/tankoubons/[^/]+/[a-f0-9]{40}(/|$)}{/api/tankoubons/:id/:archive$1}g;
    $path =~ s{/api/tankoubons/[^/]+(/|$)}{/api/tankoubons/:id$1}g;

    # Minion endpoints
    $path =~ s{/api/minion/([^/]+)/queue(/|$)}{/api/minion/:jobname/queue$2}g;
    $path =~ s{/api/minion/[^/]+/detail(/|$)}{/api/minion/:jobid/detail$1}g;
    $path =~ s{/api/minion/[^/]+$}{/api/minion/:jobid}g;

    # OPDS endpoints
    $path =~ s{/api/opds/[^/]+/pse(/|$)}{/api/opds/:id/pse$1}g;
    $path =~ s{/api/opds/[^/]+(/|$)}{/api/opds/:id$1}g;

    # Plugin endpoints
    $path =~ s{/api/plugins/([^/]+)$}{
        my $segment = $1;
        if ($segment =~ /^(use|queue)$/) {
            "/api/plugins/$segment";
        } else {
            "/api/plugins/:type";
        }
    }ge;

    return $path;
}

# Escape label values according to OpenMetrics specification
# https://prometheus.io/docs/specs/om/open_metrics_spec/#escaping
sub escape_label_value {
    my $value = shift;
    return "" unless defined $value;
    
    # OpenMetrics escaping rules:
    # Line feed \n (0x0A) -> literally \\n
    # Double quotes -> \"  
    # Backslash -> \\\\
    $value =~ s/\\/\\\\/g;    # Escape backslashes first
    $value =~ s/"/\\"/g;      # Escape double quotes
    $value =~ s/\n/\\n/g;     # Escape newlines
    
    return $value;
}

# Read and parse /proc/self/stat to return user/system CPU time and process start time.
# https://man7.org/linux/man-pages/man5/proc_pid_stat.5.html （note the starting index difference)
# https://man7.org/linux/man-pages/man3/sysconf.3.html
sub read_proc_stat {
    return undef unless -r "/proc/self/stat";

    open my $fh, '<', "/proc/self/stat" or return undef;
    my $stat_line = <$fh>;
    close $fh;

    return undef unless $stat_line;
    my @fields = split /\s+/, $stat_line;
    my $ticks_per_sec = eval { require POSIX; POSIX::sysconf(POSIX::_SC_CLK_TCK()) };
    return undef unless $ticks_per_sec;

    my $boot_time = get_boot_time();
    return undef unless defined $boot_time;

    return {
        utime     => ($fields[13] || 0) / $ticks_per_sec,                   # User CPU time in seconds
        stime     => ($fields[14] || 0) / $ticks_per_sec,                   # System CPU time in seconds
        starttime => $boot_time + (($fields[21] || 0) / $ticks_per_sec),    # Process start time (absolute)
    };
}

# Read and parse /proc/self/statm to return virtual and resident memory size
# Must have valid page size in order to return memory stats.
# https://man7.org/linux/man-pages/man5/proc_pid_statm.5.html
# https://man7.org/linux/man-pages/man3/sysconf.3.html
sub read_proc_statm {
    return undef unless -r "/proc/self/statm";

    open my $fh, '<', "/proc/self/statm" or return undef;
    my $statm_line = <$fh>;
    close $fh;

    return undef unless $statm_line;
    my @fields = split /\s+/, $statm_line;
    my $page_size = eval { require POSIX; POSIX::sysconf(POSIX::_SC_PAGESIZE()) };
    return undef unless $page_size;

    return {
        vsize => ($fields[0] || 0) * $page_size, # Virtual memory size in bytes
        rss   => ($fields[1] || 0) * $page_size, # Resident memory size in bytes
    };
}

# Get max file descriptors and number of open file descriptors as map
# if max fd is unlimited, return map value as undef.
# https://man7.org/linux/man-pages/man5/proc_pid_fd.5.html
sub read_fd_stats {
    my $open_fds    = 0;
    my $max_fds     = undef;

    if ( opendir my $fd_dir, "/proc/self/fd" ) {
        $open_fds = grep { /^\d+$/ } readdir($fd_dir);
        closedir $fd_dir;
    }

    if ( open my $fh, '<', "/proc/self/limits" ) {
        while ( my $line = <$fh> ) {
            if ( $line =~ /^Max open files\s+\S+\s+(\S+)/ ) {
                $max_fds = $1 eq 'unlimited' ? undef : int($1);
                last;
            }
        }
        close $fh;
    }

    return {
        open => $open_fds,
        max  => $max_fds,
    };
}

# Get IO stats from /proc/self/io
# https://man7.org/linux/man-pages/man5/proc_pid_io.5.html
sub read_proc_io_bytes {
    return undef unless -r "/proc/self/io";
    my $read_bytes  = 0;
    my $write_bytes = 0;

    if ( open my $fh, '<', "/proc/self/io" ) {
        while ( my $line = <$fh> ) {
            if ( $line =~ /^(read_bytes):\s*(\d+)$/ ) {
                $read_bytes = int($2);
            } elsif ( $line =~ /^(write_bytes):\s*(\d+)$/ ) {
                $write_bytes = int($2);
            }
        }
        close $fh;
    }

    return {
        read_bytes  => $read_bytes,   # Bytes read from storage
        write_bytes => $write_bytes,  # Bytes written to storage
    };
}

# Get system boot time from /proc/stat
# Adapted from Net::Prometheus::ProcessCollector::linux to return boot time as a variable.
# https://metacpan.org/release/PEVANS/Net-Prometheus-0.14/source/lib/Net/Prometheus/ProcessCollector/linux.pm
# https://man7.org/linux/man-pages/man5/proc_stat.5.html
sub get_boot_time {
    return undef unless -r "/proc/stat";
    open my $fh, '<', "/proc/stat" or return undef;
    while ( my $line = <$fh> ) {
        if ( $line =~ /^btime (\d+)/ ) {
            close $fh;
            return int($1);
        }
    }
    close $fh;
    return undef;
}

1;
