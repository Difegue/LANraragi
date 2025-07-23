package LANraragi::Utils::Metrics;

use strict;
use warnings;
use utf8;

use Time::HiRes qw(gettimeofday tv_interval);
use Mojo::JSON qw(encode_json decode_json);
use LANraragi::Model::Config;
use LANraragi::Model::Stats;

use Exporter 'import';
our @EXPORT_OK = qw(record_api_metrics get_prometheus_metrics record_process_metrics);

# Record API request metrics to Redis
sub record_api_metrics {
    my ($controller) = @_;

    eval {
        my $start_time = $controller->stash('metrics.start_time');
        return unless $start_time; # Skip if no start time recorded

        my $duration = tv_interval($start_time);
        my $method = $controller->req->method;
        my $path = $controller->req->url->path->to_string;
        my $status_code = $controller->res->code || 0;

        my $request_size = $controller->req->content->body_size || 0;
        my $response_size = $controller->res->content->body_size || 0;

        my $endpoint = extract_endpoint($path);

        my $redis = get_redis_metrics();
        return unless $redis;

        # Store per-worker metrics using atomic operations to prevent race conditions
        # Structure: metrics:worker:{PID}:{endpoint}_{method}:count, :duration_sum, etc.
        # Encode endpoint to avoid Redis key issues with slashes
        my $endpoint_encoded = $endpoint;
        $endpoint_encoded =~ s/\//_/g;  # Replace / with _
        my $metric_base = "metrics:worker:$$:${endpoint_encoded}_${method}";
        $redis->hincrby($metric_base, "count", 1);
        $redis->hincrbyfloat($metric_base, "duration_sum", $duration);
        $redis->hincrby($metric_base, "request_size_sum", $request_size);
        $redis->hincrby($metric_base, "response_size_sum", $response_size);
        $redis->hset($metric_base, "last_status", $status_code);

        # Set TTL for cleanup
        $redis->expire($metric_base, 300);

        $redis->quit();
    };

    # Silently fail
    if ($@) {
        warn "Metrics collection error: $@";
    }
}

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

    $path =~ s{/api/archives/[a-f0-9]{40}(/|$)}{/api/archives/:id$1}g;
    $path =~ s{/api/categories/[^/]+(/|$)}{/api/categories/:id$1}g;
    $path =~ s{/api/tankoubons/[^/]+(/|$)}{/api/tankoubons/:id$1}g;
    $path =~ s{/api/archives/:id/progress/\d+}{/api/archives/:id/progress/:page};
    $path =~ s{/api/minion/[^/]+(/|$)}{/api/minion/:jobid$1}g;
    $path =~ s{/api/plugins/[^/]+$}{/api/plugins/:type};
    $path =~ s{/api/opds/[^/]+(/|$)}{/api/opds/:id$1}g;

    return $path;
}

# Get all metrics in Prometheus format
sub get_prometheus_metrics {
    my ($controller) = @_;
    my $metrics_redis = get_redis_metrics();

    # Return basic metrics if Redis is unavailable
    unless ($metrics_redis) {
        return "# HELP lanraragi_metrics_error Metrics collection error\n" .
               "# TYPE lanraragi_metrics_error gauge\n" .
               "lanraragi_metrics_error 1\n";
    }

    my @metric_keys = $metrics_redis->keys("metrics:worker:*");
    my %aggregated_metrics;
    my %active_workers;
    
    foreach my $key (@metric_keys) {
        # Skip the active_workers set
        next if $key eq "metrics:active_workers";
        
        # Parse key: metrics:worker:{PID}:{endpoint_encoded}_{method}
        if ($key =~ /^metrics:worker:(\d+):(.+)_([A-Z]+)$/) {
            my ($worker_pid, $endpoint_encoded, $method) = ($1, $2, $3);
            $active_workers{$worker_pid} = 1;

            next unless $endpoint_encoded && $method;

            # Decode endpoint back to original path
            my $endpoint = $endpoint_encoded;
            $endpoint =~ s/_/\//g;

            my %metric_data = $metrics_redis->hgetall($key);
            next unless %metric_data;

            my $labels = qq{endpoint="$endpoint",method="$method"};

            # Aggregate count
            $aggregated_metrics{"lanraragi_api_requests_total"}{$labels} += $metric_data{count} || 0;

            # Aggregate duration sum and squared sum for calculating mean and stddev
            $aggregated_metrics{"lanraragi_api_duration_seconds_sum"}{$labels} += $metric_data{duration_sum} || 0;
            $aggregated_metrics{"lanraragi_api_duration_seconds_squared_sum"}{$labels} += $metric_data{duration_squared_sum} || 0;

            # Aggregate request and response size sums
            $aggregated_metrics{"lanraragi_http_request_size_bytes_sum"}{$labels} += $metric_data{request_size_sum} || 0;
            $aggregated_metrics{"lanraragi_http_response_size_bytes_sum"}{$labels} += $metric_data{response_size_sum} || 0;
        }
    }

    $metrics_redis->quit();

    # Collect stats metrics
    my %stats_metrics;
    eval {
        # Get Redis connection for cache info
        my $config_redis = LANraragi::Model::Config->get_redis_config;
        my $last_clear = $config_redis->hget("LRR_SEARCHCACHE", "created") || time;
        $config_redis->quit();

        # Get archive and page stats
        my $arc_stat = LANraragi::Model::Stats::get_archive_count;
        my $page_stat = LANraragi::Model::Stats::get_page_stat;

        # Server info metrics (as labels on a gauge set to 1)
        # Use controller helpers if available, otherwise fall back to direct config access
        my ($name, $motd, $version, $version_name, $version_desc);
        if ($controller) {
            $name = $controller->LRR_CONF->get_htmltitle || "";
            $motd = $controller->LRR_CONF->get_motd || "";
            $version = $controller->LRR_VERSION || "";
            $version_name = $controller->LRR_VERNAME || "";
            $version_desc = $controller->LRR_DESC || "";
        } else {
            $name = LANraragi::Model::Config->get_htmltitle || "";
            $motd = LANraragi::Model::Config->get_motd || "";
            $version = "";
            $version_name = "";
            $version_desc = "";
        }

        my $server_labels = sprintf('name="%s",motd="%s",version="%s",version_name="%s",version_desc="%s"',
            $name, $motd, $version, $version_name, $version_desc
        );
        $stats_metrics{"lanraragi_server_info"}{$server_labels} = 1;

        # Individual configuration metrics
        $stats_metrics{"lanraragi_has_password"}{""} = LANraragi::Model::Config->enable_pass ? 1 : 0;
        $stats_metrics{"lanraragi_debug_mode"}{""} = LANraragi::Model::Config->enable_devmode ? 1 : 0;
        $stats_metrics{"lanraragi_nofun_mode"}{""} = LANraragi::Model::Config->enable_nofun ? 1 : 0;
        $stats_metrics{"lanraragi_archives_per_page"}{""} = LANraragi::Model::Config->get_pagesize;
        $stats_metrics{"lanraragi_server_resizes_images"}{""} = LANraragi::Model::Config->enable_resize ? 1 : 0;

        # Archive and page statistics
        $stats_metrics{"lanraragi_archives_total"}{""} = $arc_stat;
        $stats_metrics{"lanraragi_pages_read_total"}{""} = $page_stat;
        $stats_metrics{"lanraragi_cache_last_cleared_timestamp"}{""} = $last_clear;
    };

    if ($@) {
        warn "Stats metrics collection error: $@";
    }

    # Format as Prometheus exposition format
    my @output;

    # Request counter
    push @output, "# HELP lanraragi_api_requests_total Total number of API requests";
    push @output, "# TYPE lanraragi_api_requests_total counter";
    foreach my $labels (sort keys %{$aggregated_metrics{"lanraragi_api_requests_total"} || {}}) {
        my $value = $aggregated_metrics{"lanraragi_api_requests_total"}{$labels};
        push @output, "lanraragi_api_requests_total{$labels} $value";
    }

    # Duration sum
    push @output, "# HELP lanraragi_api_duration_seconds_sum Total time spent processing API requests";
    push @output, "# TYPE lanraragi_api_duration_seconds_sum counter";
    foreach my $labels (sort keys %{$aggregated_metrics{"lanraragi_api_duration_seconds_sum"} || {}}) {
        my $value = $aggregated_metrics{"lanraragi_api_duration_seconds_sum"}{$labels};
        push @output, "lanraragi_api_duration_seconds_sum{$labels} $value";
    }

    # Request size sum
    push @output, "# HELP lanraragi_http_request_size_bytes_sum Total bytes received in HTTP requests";
    push @output, "# TYPE lanraragi_http_request_size_bytes_sum counter";
    foreach my $labels (sort keys %{$aggregated_metrics{"lanraragi_http_request_size_bytes_sum"} || {}}) {
        my $value = $aggregated_metrics{"lanraragi_http_request_size_bytes_sum"}{$labels};
        push @output, "lanraragi_http_request_size_bytes_sum{$labels} $value";
    }

    # Response size sum  
    push @output, "# HELP lanraragi_http_response_size_bytes_sum Total bytes sent in HTTP responses";
    push @output, "# TYPE lanraragi_http_response_size_bytes_sum counter";
    foreach my $labels (sort keys %{$aggregated_metrics{"lanraragi_http_response_size_bytes_sum"} || {}}) {
        my $value = $aggregated_metrics{"lanraragi_http_response_size_bytes_sum"}{$labels};
        push @output, "lanraragi_http_response_size_bytes_sum{$labels} $value";
    }

    # Add worker count metric
    my $worker_count = scalar keys %active_workers;
    push @output, "# HELP lanraragi_active_workers Number of active LANraragi workers";
    push @output, "# TYPE lanraragi_active_workers gauge";
    push @output, "lanraragi_active_workers $worker_count";

    # Get process metrics for all workers
    my @process_keys = $metrics_redis->keys("metrics:process:*");
    my %process_metrics;

    foreach my $key (@process_keys) {
        # Parse key: metrics:process:{PID}
        if ($key =~ /^metrics:process:(\d+)$/) {
            my $worker_pid = $1;
            my %process_data = $metrics_redis->hgetall($key);
            next unless %process_data;

                    # Store by metric type
        foreach my $metric_name (qw(cpu_user_seconds_total cpu_system_seconds_total cpu_seconds_total 
                                   virtual_memory_bytes resident_memory_bytes 
                                   open_fds max_fds start_time_seconds)) {
                if (defined $process_data{$metric_name}) {
                    my $labels = qq{worker_pid="$worker_pid"};
                    $process_metrics{$metric_name}{$labels} = $process_data{$metric_name};
                }
            }
        }
    }

    # Output process metrics
    if (%process_metrics) {
        # CPU metrics (counters)
        foreach my $metric_name (qw(cpu_user_seconds_total cpu_system_seconds_total cpu_seconds_total)) {
            next unless $process_metrics{$metric_name};

            my $help_text = {
                cpu_user_seconds_total   => "Total user CPU time spent by worker process in seconds",
                cpu_system_seconds_total => "Total system CPU time spent by worker process in seconds", 
                cpu_seconds_total        => "Total user and system CPU time spent by worker process in seconds",
            }->{$metric_name};

            push @output, "# HELP lanraragi_process_$metric_name $help_text";
            push @output, "# TYPE lanraragi_process_$metric_name counter";
            foreach my $labels (sort keys %{$process_metrics{$metric_name}}) {
                my $value = $process_metrics{$metric_name}{$labels};
                push @output, "lanraragi_process_$metric_name\{$labels\} $value";
            }
        }

        # Memory and FD metrics (gauges)
        foreach my $metric_name (qw(virtual_memory_bytes resident_memory_bytes open_fds max_fds start_time_seconds)) {
            next unless $process_metrics{$metric_name};

            my $help_text = {
                virtual_memory_bytes => "Virtual memory size of worker process in bytes",
                resident_memory_bytes => "Resident memory size of worker process in bytes",
                open_fds => "Number of open file handles in worker process",
                max_fds => "Maximum number of file handles allowed for worker process",
                start_time_seconds => "Unix epoch time when worker process started",
            }->{$metric_name};

            push @output, "# HELP lanraragi_process_$metric_name $help_text";
            push @output, "# TYPE lanraragi_process_$metric_name gauge";
            foreach my $labels (sort keys %{$process_metrics{$metric_name}}) {
                my $value = $process_metrics{$metric_name}{$labels};
                push @output, "lanraragi_process_$metric_name\{$labels\} $value";
            }
        }
    }

    # Output stats metrics
    if (%stats_metrics) {
        # Server info gauge (with labels)
        if ($stats_metrics{"lanraragi_server_info"}) {
            push @output, "# HELP lanraragi_server_info Server information with version and configuration details";
            push @output, "# TYPE lanraragi_server_info gauge";
            foreach my $labels (sort keys %{$stats_metrics{"lanraragi_server_info"}}) {
                my $value = $stats_metrics{"lanraragi_server_info"}{$labels};
                push @output, "lanraragi_server_info{$labels} $value";
            }
        }

        # Configuration gauges
        foreach my $metric_name (qw(has_password debug_mode nofun_mode server_resizes_images)) {
            next unless defined $stats_metrics{"lanraragi_$metric_name"};

            my $help_text = {
                has_password => "Whether the server has password protection enabled",
                debug_mode => "Whether the server is running in debug mode",
                nofun_mode => "Whether the server is running in no-fun mode",
                server_resizes_images => "Whether the server resizes images for bandwidth optimization"
            }->{$metric_name};

            push @output, "# HELP lanraragi_$metric_name $help_text";
            push @output, "# TYPE lanraragi_$metric_name gauge";
            my $value = $stats_metrics{"lanraragi_$metric_name"}{""};
            push @output, "lanraragi_$metric_name $value";
        }

        # Archives per page gauge
        if (defined $stats_metrics{"lanraragi_archives_per_page"}) {
            push @output, "# HELP lanraragi_archives_per_page Number of archives displayed per page";
            push @output, "# TYPE lanraragi_archives_per_page gauge";
            my $value = $stats_metrics{"lanraragi_archives_per_page"}{""};
            push @output, "lanraragi_archives_per_page $value";
        }

        # Archive and page statistics
        if (defined $stats_metrics{"lanraragi_archives_total"}) {
            push @output, "# HELP lanraragi_archives_total Current number of archives in the library";
            push @output, "# TYPE lanraragi_archives_total gauge";
            my $value = $stats_metrics{"lanraragi_archives_total"}{""};
            push @output, "lanraragi_archives_total $value";
        }

        if (defined $stats_metrics{"lanraragi_pages_read_total"}) {
            push @output, "# HELP lanraragi_pages_read_total Total number of pages read across all archives";
            push @output, "# TYPE lanraragi_pages_read_total counter";
            my $value = $stats_metrics{"lanraragi_pages_read_total"}{""};
            push @output, "lanraragi_pages_read_total $value";
        }

        if (defined $stats_metrics{"lanraragi_cache_last_cleared_timestamp"}) {
            push @output, "# HELP lanraragi_cache_last_cleared_timestamp Unix timestamp when the search cache was last cleared";
            push @output, "# TYPE lanraragi_cache_last_cleared_timestamp gauge";
            my $value = $stats_metrics{"lanraragi_cache_last_cleared_timestamp"}{""};
            push @output, "lanraragi_cache_last_cleared_timestamp $value";
        }
    }

    return join("\n", @output) . "\n";
}

# Get Redis connection for metrics database
sub get_redis_metrics {
    my $redis;
    eval {
        $redis = LANraragi::Model::Config->get_redis_metrics;
    };
    return $redis;
}

# Record process-level metrics for the current worker to Redis
sub record_process_metrics {
    eval {

        if ($^O eq 'linux') {
            my $metrics_redis = get_redis_metrics();
            return unless $metrics_redis; # Skip if Redis connection failed

            # Read process information from /proc/self/stat and /proc/self/statm
            my $proc_stat = read_proc_stat();
            my $proc_statm = read_proc_statm();
            my $proc_fds = count_open_fds();

            return unless $proc_stat && $proc_statm; # Skip if couldn't read proc files

            my $worker_pid = $$;
            my $timestamp = time();

            my $process_key = "metrics:process:$worker_pid";

            # CPU metrics (counters)
            $metrics_redis->hset($process_key, "cpu_user_seconds_total", $proc_stat->{utime});
            $metrics_redis->hset($process_key, "cpu_system_seconds_total", $proc_stat->{stime});
            $metrics_redis->hset($process_key, "cpu_seconds_total", $proc_stat->{utime} + $proc_stat->{stime});

            # Memory metrics (gauges)
            $metrics_redis->hset($process_key, "virtual_memory_bytes", $proc_statm->{vsize});
            $metrics_redis->hset($process_key, "resident_memory_bytes", $proc_statm->{rss});

            # File descriptor metrics (gauges)
            $metrics_redis->hset($process_key, "open_fds", $proc_fds->{open}) if defined $proc_fds->{open};
            $metrics_redis->hset($process_key, "max_fds", $proc_fds->{max}) if defined $proc_fds->{max};

            # Process start time (gauge)
            $metrics_redis->hset($process_key, "start_time_seconds", $proc_stat->{starttime});

            # Timestamp for cleanup
            $metrics_redis->hset($process_key, "last_update", $timestamp);

            # Set TTL for cleanup
            $metrics_redis->expire($process_key, 300); # 5 minute TTL for worker cleanup

            $metrics_redis->quit();
        } elsif ($^O eq 'darwin') {
            # TODO: macos
        } elsif ($^O eq 'MSWin32') {
            # TODO: windows
        } else {
            warn "Unsupported OS: $^O";
        }
    };
    # Silently ignore any process metrics collection errors
    if ($@) {
        warn "Process metrics collection error: $@";
    }
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
