package LANraragi::Utils::Metrics;

use strict;
use warnings;
use utf8;

use Exporter 'import';
our @EXPORT_OK = qw(extract_endpoint read_proc_stat read_proc_statm count_open_fds get_clock_ticks get_page_size get_boot_time);

# Extract endpoint path from request and normalize to route templates
sub extract_endpoint {
    my ($path) = @_;

    return "/unknown" unless defined $path;

    # Remove query parameters and fragments
    $path =~ s/[?#].*$//;

    # Handle root path
    return "/" if $path eq "" || $path eq "/";

    # Normalize paths to route templates to prevent cardinality explosion
    # Replace actual IDs/values with parameter placeholders
    # Handle more specific patterns first, then general ones

    # Archive endpoints (SHA-1 specific)
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

# Read and parse /proc/self/stat
sub read_proc_stat {
    return undef unless -r "/proc/self/stat";

    open my $fh, '<', "/proc/self/stat" or return undef;
    my $stat_line = <$fh>;
    close $fh;

    return undef unless $stat_line;

    # Parse /proc/self/stat format
    # Fields we care about: utime(14), stime(15), starttime(22)
    # Note: The fields are 1-indexed in documentation but 0-indexed in split
    my @fields = split /\s+/, $stat_line;

    # Get clock ticks per second (usually 100)
    my $ticks_per_sec = get_clock_ticks();
    return undef unless $ticks_per_sec;

    # Get system boot time for calculating absolute start time
    my $boot_time = get_boot_time();
    return undef unless defined $boot_time;

    return {
        utime     => ($fields[13] || 0) / $ticks_per_sec,  # User CPU time in seconds
        stime     => ($fields[14] || 0) / $ticks_per_sec,  # System CPU time in seconds  
        starttime => $boot_time + (($fields[21] || 0) / $ticks_per_sec), # Process start time (absolute)
    };
}

# Read and parse /proc/self/statm
sub read_proc_statm {
    return undef unless -r "/proc/self/statm";

    open my $fh, '<', "/proc/self/statm" or return undef;
    my $statm_line = <$fh>;
    close $fh;

    return undef unless $statm_line;

    # Parse /proc/self/statm format: size resident shared text lib data dt
    my @fields = split /\s+/, $statm_line;

    # Get page size (usually 4096 bytes)
    my $page_size = get_page_size();
    return undef unless $page_size;

    return {
        vsize => ($fields[0] || 0) * $page_size, # Virtual memory size in bytes
        rss   => ($fields[1] || 0) * $page_size, # Resident memory size in bytes
    };
}

# Count open file descriptors
sub count_open_fds {
    my $open_fds = 0;
    my $max_fds = undef;

    # Count open file descriptors by reading /proc/self/fd
    if (opendir my $fd_dir, "/proc/self/fd") {
        $open_fds = grep { /^\d+$/ } readdir($fd_dir);
        closedir $fd_dir;
    }

    # Get max file descriptors from /proc/self/limits
    if (open my $fh, '<', "/proc/self/limits") {
        while (my $line = <$fh>) {
            if ($line =~ /^Max open files\s+\S+\s+(\S+)/) {
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

# Get system clock ticks per second
sub get_clock_ticks {
    # Try to get from sysconf, fallback to common value
    my $ticks = eval { require POSIX; POSIX::sysconf(POSIX::_SC_CLK_TCK()) };
    return $ticks || 100;
}

# Get system page size
sub get_page_size {
    # Try to get from sysconf, fallback to common value  
    my $page_size = eval { require POSIX; POSIX::sysconf(POSIX::_SC_PAGESIZE()) };
    return $page_size || 4096;
}

# Get system boot time from /proc/stat
sub get_boot_time {
    return undef unless -r "/proc/stat";

    open my $fh, '<', "/proc/stat" or return undef;
    while (my $line = <$fh>) {
        if ($line =~ /^btime (\d+)/) {
            close $fh;
            return int($1);
        }
    }
    close $fh;
    return undef;
}

1;
