package LANraragi::Model::Metrics;

use strict;
use warnings;
use utf8;
use Time::HiRes                 qw(gettimeofday tv_interval);
use Mojo::JSON                  qw(encode_json decode_json);

use LANraragi::Model::Config;
use LANraragi::Model::Stats;
use LANraragi::Utils::Logging   qw(get_logger);
use LANraragi::Utils::Metrics;

# Get all metrics in Prometheus exposition format.
sub get_prometheus_metrics {
    my $controller          = shift;
    my @api_metrics         = get_prometheus_api_metrics();
    my @process_metrics     = get_prometheus_process_metrics();
    my @stats_metrics       = get_prometheus_stats_metrics($controller);
    my @output              = (@api_metrics, @process_metrics, @stats_metrics);
    push @output, "# EOF";
    return join("\n", @output) . "\n";
}

# Get API request metrics
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

            my $escaped_endpoint = LANraragi::Utils::Metrics::escape_label_value($endpoint);
            my $escaped_method = LANraragi::Utils::Metrics::escape_label_value($method);
            my $labels = qq{endpoint="$escaped_endpoint",method="$escaped_method"};

            # Aggregate metrics
            $aggregated_api_metrics{"lanraragi_api_requests_total"}{$labels} += $metric_data{count} || 0;
            $aggregated_api_metrics{"lanraragi_api_duration_seconds_total"}{$labels} += $metric_data{duration_sum} || 0;
            $aggregated_api_metrics{"lanraragi_http_request_size_bytes_total"}{$labels} += $metric_data{request_size_sum} || 0;
            $aggregated_api_metrics{"lanraragi_http_response_size_bytes_total"}{$labels} += $metric_data{response_size_sum} || 0;
        }
    }

    push @output, "# TYPE lanraragi_api_requests_total counter";
    push @output, "# HELP lanraragi_api_requests_total Total number of API requests";
    foreach my $labels ( sort keys %{ $aggregated_api_metrics{"lanraragi_api_requests_total"} || {} } ) {
        my $value = $aggregated_api_metrics{"lanraragi_api_requests_total"}{$labels};
        push @output, "lanraragi_api_requests_total{$labels} $value";
    }

    push @output, "# TYPE lanraragi_api_duration_seconds_total counter";
    push @output, "# UNIT lanraragi_api_duration_seconds_total seconds";
    push @output, "# HELP lanraragi_api_duration_seconds_total Total time spent processing API requests";
    foreach my $labels ( sort keys %{ $aggregated_api_metrics{"lanraragi_api_duration_seconds_total"} || {} } ) {
        my $value = $aggregated_api_metrics{"lanraragi_api_duration_seconds_total"}{$labels};
        push @output, "lanraragi_api_duration_seconds_total{$labels} $value";
    }

    push @output, "# TYPE lanraragi_http_request_size_bytes_total counter";
    push @output, "# UNIT lanraragi_http_request_size_bytes_total bytes";
    push @output, "# HELP lanraragi_http_request_size_bytes_total Total bytes received in HTTP requests";
    foreach my $labels ( sort keys %{ $aggregated_api_metrics{"lanraragi_http_request_size_bytes_total"} || {} } ) {
        my $value = $aggregated_api_metrics{"lanraragi_http_request_size_bytes_total"}{$labels};
        push @output, "lanraragi_http_request_size_bytes_total{$labels} $value";
    }

    push @output, "# TYPE lanraragi_http_response_size_bytes_total counter";
    push @output, "# UNIT lanraragi_http_response_size_bytes_total bytes";
    push @output, "# HELP lanraragi_http_response_size_bytes_total Total bytes sent in HTTP responses";
    foreach my $labels ( sort keys %{ $aggregated_api_metrics{"lanraragi_http_response_size_bytes_total"} || {} } ) {
        my $value = $aggregated_api_metrics{"lanraragi_http_response_size_bytes_total"}{$labels};
        push @output, "lanraragi_http_response_size_bytes_total{$labels} $value";
    }

    # API worker count metric
    my $worker_count = scalar keys %active_workers;
    push @output, "# TYPE lanraragi_active_workers gauge";
    push @output, "# HELP lanraragi_active_workers Number of active LANraragi workers";
    push @output, "lanraragi_active_workers $worker_count";

    $metrics_redis->quit();
    return @output;
}

# Get process metrics
sub get_prometheus_process_metrics {
    my $metrics_redis = LANraragi::Model::Config->get_redis_metrics;
    return () unless $metrics_redis;

    my @output;
    
    # Group all metrics by metric name, collecting from both process types
    my %all_metrics_by_name;
    foreach my $process_type (qw(minion shinobu)) {
        my @keys = $metrics_redis->keys("metrics:$process_type:*");
        
        foreach my $key (@keys) {
            if ( $key =~ /^metrics:$process_type:(\d+)$/ ) {
                my $worker_pid = $1;
                my %process_data = $metrics_redis->hgetall($key);
                next unless %process_data;

                my $labels = qq{worker_pid="$worker_pid",process_type="$process_type"};
                foreach my $metric_name ( qw(
                    cpu_user_seconds_total cpu_system_seconds_total cpu_seconds_total 
                    virtual_memory_bytes resident_memory_bytes 
                    open_fds max_fds start_time_seconds
                    read_bytes_total write_bytes_total) ) {
                    if ( defined $process_data{$metric_name} ) {
                        $all_metrics_by_name{$metric_name}{$labels} = $process_data{$metric_name};
                    }
                }
            }
        }
    }

    # Output CPU and I/O metrics (counters)
    foreach my $metric_name ( qw(cpu_user_seconds_total cpu_system_seconds_total cpu_seconds_total read_bytes_total write_bytes_total) ) {
        next unless $all_metrics_by_name{$metric_name};

        my $help_text = {
            cpu_user_seconds_total   => "Total user CPU time spent by process in seconds",
            cpu_system_seconds_total => "Total system CPU time spent by process in seconds", 
            cpu_seconds_total        => "Total user and system CPU time spent by process in seconds",
            read_bytes_total         => "Total bytes read from storage by process",
            write_bytes_total        => "Total bytes written to storage by process",
        }->{$metric_name};

        push @output, "# TYPE lanraragi_process_$metric_name counter";
        
        if ( $metric_name =~ /_bytes_total$/ ) {
            push @output, "# UNIT lanraragi_process_$metric_name bytes";
        } elsif ( $metric_name =~ /_seconds_total$/ ) {
            push @output, "# UNIT lanraragi_process_$metric_name seconds";
        }
        
        push @output, "# HELP lanraragi_process_$metric_name $help_text";
        foreach my $labels ( sort keys %{$all_metrics_by_name{$metric_name}} ) {
            my $value = $all_metrics_by_name{$metric_name}{$labels};
            push @output, "lanraragi_process_$metric_name\{$labels\} $value";
        }
    }

    # Output memory and FD metrics (gauges)
    foreach my $metric_name ( qw(virtual_memory_bytes resident_memory_bytes open_fds max_fds start_time_seconds) ) {
        next unless $all_metrics_by_name{$metric_name};

        my $help_text = {
            virtual_memory_bytes => "Virtual memory size of process in bytes",
            resident_memory_bytes => "Resident memory size of process in bytes",
            open_fds => "Number of open file handles in process",
            max_fds => "Maximum number of file handles allowed for process",
            start_time_seconds => "Unix epoch time when process started",
        }->{$metric_name};

        push @output, "# TYPE lanraragi_process_$metric_name gauge";

        if ( $metric_name =~ /_bytes$/ ) {
            push @output, "# UNIT lanraragi_process_$metric_name bytes";
        } elsif ( $metric_name =~ /_seconds$/ ) {
            push @output, "# UNIT lanraragi_process_$metric_name seconds";
        }

        push @output, "# HELP lanraragi_process_$metric_name $help_text";
        foreach my $labels ( sort keys %{$all_metrics_by_name{$metric_name}} ) {
            my $value = $all_metrics_by_name{$metric_name}{$labels};
            push @output, "lanraragi_process_$metric_name\{$labels\} $value";
        }
    }

    $metrics_redis->quit();
    return @output;
}

# Get server/configuration metrics
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
        LANraragi::Utils::Metrics::escape_label_value($name), 
        LANraragi::Utils::Metrics::escape_label_value($motd), 
        LANraragi::Utils::Metrics::escape_label_value($version), 
        LANraragi::Utils::Metrics::escape_label_value($version_name), 
        LANraragi::Utils::Metrics::escape_label_value($version_desc)
    );

    # "info" metadata type is OpenMetrics 1.0 format, currently not supported by Prometheus.
    # push @output, "# TYPE lanraragi_server_info info";
    push @output, "# TYPE lanraragi_server_info gauge";
    push @output, "# HELP lanraragi_server_info Server information with version and configuration details";
    push @output, "lanraragi_server_info{$server_labels} 1";

    # Configuration metrics
    push @output, "# TYPE lanraragi_has_password gauge";
    push @output, "# HELP lanraragi_has_password Whether the server has password protection enabled";
    push @output, "lanraragi_has_password " . (LANraragi::Model::Config->enable_pass ? 1 : 0);

    push @output, "# TYPE lanraragi_debug_mode gauge";
    push @output, "# HELP lanraragi_debug_mode Whether the server is running in debug mode";
    push @output, "lanraragi_debug_mode " . (LANraragi::Model::Config->enable_devmode ? 1 : 0);

    push @output, "# TYPE lanraragi_nofun_mode gauge";
    push @output, "# HELP lanraragi_nofun_mode Whether the server is running in no-fun mode";
    push @output, "lanraragi_nofun_mode " . (LANraragi::Model::Config->enable_nofun ? 1 : 0);

    push @output, "# TYPE lanraragi_server_resizes_images gauge";
    push @output, "# HELP lanraragi_server_resizes_images Whether the server resizes images for bandwidth optimization";
    push @output, "lanraragi_server_resizes_images " . (LANraragi::Model::Config->enable_resize ? 1 : 0);

    push @output, "# TYPE lanraragi_archives_per_page gauge";
    push @output, "# HELP lanraragi_archives_per_page Number of archives displayed per page";
    push @output, "lanraragi_archives_per_page " . LANraragi::Model::Config->get_pagesize;

    # Archive and page statistics
    push @output, "# TYPE lanraragi_archives_total gauge";
    push @output, "# HELP lanraragi_archives_total Current number of archives in the library";
    push @output, "lanraragi_archives_total $arc_stat";

    push @output, "# TYPE lanraragi_pages_read_total counter";
    push @output, "# HELP lanraragi_pages_read_total Total number of pages read across all archives";
    push @output, "lanraragi_pages_read_total $page_stat";

    push @output, "# TYPE lanraragi_cache_last_cleared_timestamp_seconds gauge";
    push @output, "# UNIT lanraragi_cache_last_cleared_timestamp_seconds seconds";
    push @output, "# HELP lanraragi_cache_last_cleared_timestamp_seconds Unix timestamp when the search cache was last cleared";
    push @output, "lanraragi_cache_last_cleared_timestamp_seconds $last_clear";

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

        my $endpoint = LANraragi::Utils::Metrics::extract_endpoint($path);

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
        $redis->quit();
    };

    if ( $@ ) {
        warn "Metrics collection error: $@";
    }
}

# Record process-level metrics to Redis with the specified key prefix
# Accepted key prefixes are "minion" or "shinobu"
sub collect_process_metrics {
    my $key_prefix = shift;
    
    eval {
        if ($^O eq 'linux') {
            my $metrics_redis = LANraragi::Model::Config->get_redis_metrics;

            # Read process information from /proc/self/stat, /proc/self/statm, and /proc/self/io
            my $proc_stat = LANraragi::Utils::Metrics::read_proc_stat();
            my $proc_statm = LANraragi::Utils::Metrics::read_proc_statm();
            my $proc_fds = LANraragi::Utils::Metrics::read_fd_stats();
            my $proc_io = LANraragi::Utils::Metrics::read_proc_io_bytes();

            return unless $proc_stat && $proc_statm; # Skip if couldn't read proc files

            my $worker_pid = $$;
            my $process_key = "metrics:$key_prefix:$worker_pid";

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

            # I/O metrics (counters)
            $metrics_redis->hset($process_key, "read_bytes_total", $proc_io->{read_bytes});
            $metrics_redis->hset($process_key, "write_bytes_total", $proc_io->{write_bytes});

            # No TTL - process metrics persist until server restart

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
        warn "Process metrics collection error ($key_prefix): $@";
    }
}

# Clean up all existing metrics data on startup
sub cleanup_metrics {
    eval {
        my $metrics_redis = LANraragi::Model::Config->get_redis_metrics;
        return unless $metrics_redis;
        my $logger = get_logger( "Metrics", "lanraragi" );

        # Get all metrics keys
        my @api_keys = $metrics_redis->keys("metrics:worker:*");
        my @minion_keys = $metrics_redis->keys("metrics:minion:*");
        my @shinobu_keys = $metrics_redis->keys("metrics:shinobu:*");
        my @all_keys = (@api_keys, @minion_keys, @shinobu_keys);

        if (@all_keys) {
            # Delete all metrics keys in a single operation
            $metrics_redis->del(@all_keys);
            my $count = scalar(@all_keys);
            $logger->info("Cleaned up $count metrics keys from previous session");
        }

        $metrics_redis->quit();
    };

    if ( $@ ) {
        warn "Metrics cleanup error: $@";
    }
}

1;
