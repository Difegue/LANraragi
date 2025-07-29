package LANraragi::Model::Metrics;

use strict;
use warnings;
use utf8;
use Time::HiRes qw(gettimeofday tv_interval);
use Mojo::JSON qw(encode_json decode_json);

use LANraragi::Model::Config;
use LANraragi::Model::Stats;
use LANraragi::Utils::Metrics qw(extract_endpoint read_proc_stat read_proc_statm read_fd_stats);

use Exporter 'import';
our @EXPORT_OK = qw(collect_api_metrics get_prometheus_metrics collect_process_metrics);

# Get all metrics in Prometheus format
sub get_prometheus_metrics {
    my $controller          = shift;
    my @api_metrics         = get_prometheus_api_metrics();
    my @process_metrics     = get_prometheus_process_metrics();
    my @stats_metrics       = get_prometheus_stats_metrics($controller);
    my @output              = (@api_metrics, @process_metrics, @stats_metrics);
    return join("\n", @output) . "\n";
}

# Get API request metrics in Prometheus format
sub get_prometheus_api_metrics {
    my $metrics_redis = LANraragi::Model::Config->get_redis_metrics;
    return () unless $metrics_redis;

    my @output;
    my @metric_keys = $metrics_redis->keys("metrics:worker:*");
    my %aggregated_api_metrics;
    my %active_workers;
    
    foreach my $key ( @metric_keys ) {
        
        # Parse key: metrics:worker:{PID}:{endpoint_encoded}_{method}
        if ( $key =~ /^metrics:worker:(\d+):(.+)_([A-Z]+)$/ ) {
            my ($worker_pid, $endpoint_encoded, $method) = ($1, $2, $3);
            $active_workers{$worker_pid} = 1;

            next unless $endpoint_encoded && $method;

            # Decode endpoint back to original path
            my $endpoint = $endpoint_encoded;
            $endpoint =~ s/_/\//g;

            my %metric_data = $metrics_redis->hgetall($key);
            next unless %metric_data;

            my $labels = qq{endpoint="$endpoint",method="$method"};

            # Aggregate metrics
            $aggregated_api_metrics{"lanraragi_api_requests_total"}{$labels} += $metric_data{count} || 0;
            $aggregated_api_metrics{"lanraragi_api_duration_seconds_sum"}{$labels} += $metric_data{duration_sum} || 0;
            $aggregated_api_metrics{"lanraragi_http_request_size_bytes_sum"}{$labels} += $metric_data{request_size_sum} || 0;
            $aggregated_api_metrics{"lanraragi_http_response_size_bytes_sum"}{$labels} += $metric_data{response_size_sum} || 0;
        }
    }

    # Output API request metrics
    push @output, "# HELP lanraragi_api_requests_total Total number of API requests";
    push @output, "# TYPE lanraragi_api_requests_total counter";
    foreach my $labels ( sort keys %{ $aggregated_api_metrics{"lanraragi_api_requests_total"} || {} } ) {
        my $value = $aggregated_api_metrics{"lanraragi_api_requests_total"}{$labels};
        push @output, "lanraragi_api_requests_total{$labels} $value";
    }

    push @output, "# HELP lanraragi_api_duration_seconds_sum Total time spent processing API requests";
    push @output, "# TYPE lanraragi_api_duration_seconds_sum counter";
    foreach my $labels ( sort keys %{ $aggregated_api_metrics{"lanraragi_api_duration_seconds_sum"} || {} } ) {
        my $value = $aggregated_api_metrics{"lanraragi_api_duration_seconds_sum"}{$labels};
        push @output, "lanraragi_api_duration_seconds_sum{$labels} $value";
    }

    push @output, "# HELP lanraragi_http_request_size_bytes_sum Total bytes received in HTTP requests";
    push @output, "# TYPE lanraragi_http_request_size_bytes_sum counter";
    foreach my $labels ( sort keys %{ $aggregated_api_metrics{"lanraragi_http_request_size_bytes_sum"} || {} } ) {
        my $value = $aggregated_api_metrics{"lanraragi_http_request_size_bytes_sum"}{$labels};
        push @output, "lanraragi_http_request_size_bytes_sum{$labels} $value";
    }

    push @output, "# HELP lanraragi_http_response_size_bytes_sum Total bytes sent in HTTP responses";
    push @output, "# TYPE lanraragi_http_response_size_bytes_sum counter";
    foreach my $labels ( sort keys %{ $aggregated_api_metrics{"lanraragi_http_response_size_bytes_sum"} || {} } ) {
        my $value = $aggregated_api_metrics{"lanraragi_http_response_size_bytes_sum"}{$labels};
        push @output, "lanraragi_http_response_size_bytes_sum{$labels} $value";
    }

    # Worker count metric
    my $worker_count = scalar keys %active_workers;
    push @output, "# HELP lanraragi_active_workers Number of active LANraragi workers";
    push @output, "# TYPE lanraragi_active_workers gauge";
    push @output, "lanraragi_active_workers $worker_count";

    $metrics_redis->quit();
    return @output;
}

# Get process metrics in Prometheus format
sub get_prometheus_process_metrics {
    my $metrics_redis = LANraragi::Model::Config->get_redis_metrics;
    return () unless $metrics_redis;

    my @output;
    my @process_keys = $metrics_redis->keys("metrics:process:*");
    
    # Group process metrics by type
    my %process_metrics_by_type;
    foreach my $key ( @process_keys ) {
        if ( $key =~ /^metrics:process:(\d+)$/ ) {
            my $worker_pid = $1;
            my %process_data = $metrics_redis->hgetall($key);
            next unless %process_data;

            my $labels = qq{worker_pid="$worker_pid"};
            foreach my $metric_name ( qw(
                cpu_user_seconds_total cpu_system_seconds_total cpu_seconds_total 
                virtual_memory_bytes resident_memory_bytes 
                open_fds max_fds start_time_seconds) ) {
                if ( defined $process_data{$metric_name} ) {
                    $process_metrics_by_type{$metric_name}{$labels} = $process_data{$metric_name};
                }
            }
        }
    }

    # Output CPU metrics (counters)
    foreach my $metric_name ( qw(cpu_user_seconds_total cpu_system_seconds_total cpu_seconds_total) ) {
        next unless $process_metrics_by_type{$metric_name};

        my $help_text = {
            cpu_user_seconds_total   => "Total user CPU time spent by worker process in seconds",
            cpu_system_seconds_total => "Total system CPU time spent by worker process in seconds", 
            cpu_seconds_total        => "Total user and system CPU time spent by worker process in seconds",
        }->{$metric_name};

        push @output, "# HELP lanraragi_process_$metric_name $help_text";
        push @output, "# TYPE lanraragi_process_$metric_name counter";
        foreach my $labels ( sort keys %{$process_metrics_by_type{$metric_name}} ) {
            my $value = $process_metrics_by_type{$metric_name}{$labels};
            push @output, "lanraragi_process_$metric_name\{$labels\} $value";
        }
    }

    # Output memory and FD metrics (gauges)
    foreach my $metric_name ( qw(virtual_memory_bytes resident_memory_bytes open_fds max_fds start_time_seconds) ) {
        next unless $process_metrics_by_type{$metric_name};

        my $help_text = {
            virtual_memory_bytes => "Virtual memory size of worker process in bytes",
            resident_memory_bytes => "Resident memory size of worker process in bytes",
            open_fds => "Number of open file handles in worker process",
            max_fds => "Maximum number of file handles allowed for worker process",
            start_time_seconds => "Unix epoch time when worker process started",
        }->{$metric_name};

        push @output, "# HELP lanraragi_process_$metric_name $help_text";
        push @output, "# TYPE lanraragi_process_$metric_name gauge";
        foreach my $labels ( sort keys %{$process_metrics_by_type{$metric_name}} ) {
            my $value = $process_metrics_by_type{$metric_name}{$labels};
            push @output, "lanraragi_process_$metric_name\{$labels\} $value";
        }
    }

    $metrics_redis->quit();
    return @output;
}

# Get server/configuration metrics in Prometheus format
sub get_prometheus_stats_metrics {
    my $controller = shift;
    my @output;

    # Get Redis connection for cache info
    my $config_redis = LANraragi::Model::Config->get_redis_config;
    my $last_clear = $config_redis->hget("LRR_SEARCHCACHE", "created") || time;
    $config_redis->quit();

    # Get archive and page stats
    my $arc_stat = LANraragi::Model::Stats::get_archive_count;
    my $page_stat = LANraragi::Model::Stats::get_page_stat;

    # Server info metric (with labels)
    my $name = $controller->LRR_CONF->get_htmltitle || "";
    my $motd = $controller->LRR_CONF->get_motd || "";
    my $version = $controller->LRR_VERSION || "";
    my $version_name = $controller->LRR_VERNAME || "";
    my $version_desc = $controller->LRR_DESC || "";

    my $server_labels = sprintf(
        'name="%s",motd="%s",version="%s",version_name="%s",version_desc="%s"',
        $name, $motd, $version, $version_name, $version_desc
    );

    push @output, "# HELP lanraragi_server_info Server information with version and configuration details";
    push @output, "# TYPE lanraragi_server_info gauge";
    push @output, "lanraragi_server_info{$server_labels} 1";

    # Configuration metrics
    push @output, "# HELP lanraragi_has_password Whether the server has password protection enabled";
    push @output, "# TYPE lanraragi_has_password gauge";
    push @output, "lanraragi_has_password " . (LANraragi::Model::Config->enable_pass ? 1 : 0);

    push @output, "# HELP lanraragi_debug_mode Whether the server is running in debug mode";
    push @output, "# TYPE lanraragi_debug_mode gauge";
    push @output, "lanraragi_debug_mode " . (LANraragi::Model::Config->enable_devmode ? 1 : 0);

    push @output, "# HELP lanraragi_nofun_mode Whether the server is running in no-fun mode";
    push @output, "# TYPE lanraragi_nofun_mode gauge";
    push @output, "lanraragi_nofun_mode " . (LANraragi::Model::Config->enable_nofun ? 1 : 0);

    push @output, "# HELP lanraragi_server_resizes_images Whether the server resizes images for bandwidth optimization";
    push @output, "# TYPE lanraragi_server_resizes_images gauge";
    push @output, "lanraragi_server_resizes_images " . (LANraragi::Model::Config->enable_resize ? 1 : 0);

    push @output, "# HELP lanraragi_archives_per_page Number of archives displayed per page";
    push @output, "# TYPE lanraragi_archives_per_page gauge";
    push @output, "lanraragi_archives_per_page " . LANraragi::Model::Config->get_pagesize;

    # Archive and page statistics
    push @output, "# HELP lanraragi_archives_total Current number of archives in the library";
    push @output, "# TYPE lanraragi_archives_total gauge";
    push @output, "lanraragi_archives_total $arc_stat";

    push @output, "# HELP lanraragi_pages_read_total Total number of pages read across all archives";
    push @output, "# TYPE lanraragi_pages_read_total counter";
    push @output, "lanraragi_pages_read_total $page_stat";

    push @output, "# HELP lanraragi_cache_last_cleared_timestamp Unix timestamp when the search cache was last cleared";
    push @output, "# TYPE lanraragi_cache_last_cleared_timestamp gauge";
    push @output, "lanraragi_cache_last_cleared_timestamp $last_clear";

    return @output;
}

# Record API request metrics to Redis
# takes a Mojo controller corresponding to the API request being handled.
sub collect_api_metrics {
    my $controller          = shift;

    eval {
        my $start_time = $controller->stash('metrics.start_time');
        return unless $start_time;

        my $duration        = tv_interval($start_time);
        my $method          = $controller->req->method;
        my $path            = $controller->req->url->path->to_string;
        my $status_code     = $controller->res->code || 0;

        my $request_size    = $controller->req->content->body_size || 0;
        my $response_size   = $controller->res->content->body_size || 0;

        my $endpoint = extract_endpoint($path);

        my $redis = LANraragi::Model::Config->get_redis_metrics;

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

        # Set TTL for cleanup
        $redis->expire($metric_base, 300);

        $redis->quit();
    };

    if ( $@ ) {
        warn "Metrics collection error: $@";
    }
}

# Record process-level metrics for the current worker to Redis
sub collect_process_metrics {
    eval {

        if ($^O eq 'linux') {
            my $metrics_redis = LANraragi::Model::Config->get_redis_metrics;

            # Read process information from /proc/self/stat and /proc/self/statm
            my $proc_stat = read_proc_stat();
            my $proc_statm = read_proc_statm();
            my $proc_fds = read_fd_stats();

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

    if ( $@ ) {
        warn "Process metrics collection error: $@";
    }
}

1;
