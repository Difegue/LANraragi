package LANraragi::Model::Registry;

use strict;
use warnings;
use utf8;

use Mojo::JSON qw(decode_json);

use LANraragi::Utils::Logging  qw(get_logger);
use LANraragi::Utils::Registry qw(
    fetch_registry_resource
    validate_registry_index
    is_valid_registry
);

# Max registry index size for slurp (files will/should never reach this size anyways but stops OOM)
use constant MAX_REGISTRY_INDEX_SIZE => 100 * 1024 * 1024;      # 100 MB

# Source fields that, when changed, invalidate the cached index.
my @SOURCE_FIELDS = qw(type url ref path);

# Fields valid per registry type.
my %TYPE_FIELDS = (
    github  => [qw(name type url ref)],
    gitlab  => [qw(name type url ref)],
    gitea   => [qw(name type url ref)],
    cdn     => [qw(name type url)],
    local   => [qw(name type path)],
);

# Fields that must be removed when switching kinds.
my %STALE_FIELDS = (
    github  => [qw(path)],
    gitlab  => [qw(path)],
    gitea   => [qw(path)],
    cdn     => [qw(ref path)],
    local   => [qw(url ref)],
);

# Create a registry entry with a generated REG_{timestamp} ID.
# Returns ( $registry_id, undef ) or ( undef, $error_message ).
sub create_registry {
    my ( $config, $redis ) = @_;
    my %config = %{$config};

    my $logger = get_logger( "Registry", "lanraragi" );
    $logger->info("Creating registry (type: $config{type})");

    # Sanitize local registry path
    if ( $config{type} eq "local" && defined $config{path} ) {
        if ( index( $config{path}, "\0" ) >= 0 || $config{path} =~ /\.\./ ) {
            return ( undef, "Invalid registry path." );
        }
    }

    # Atomically claim an unused REG_<ts> hash key and populate registry hash in one go.
    my $claim_script = <<'LUA';
    if redis.call("EXISTS", KEYS[1]) == 1 then
        return 0
    end
    redis.call("HSET", KEYS[1], unpack(ARGV))
    return 1
LUA

    my $registry_type = $config{type};
    my @valid_fields  = @{ $TYPE_FIELDS{$registry_type} };
    my @field_args;
    foreach my $field (@valid_fields) {
        next unless defined $config{$field};
        push @field_args, $field, $config{$field};
    }

    my $now = time;
    push @field_args, "created", $now, "updated", $now;

    my $registry_id;
    my $offset = 0;
    until ($registry_id) {
        my $candidate = "REG_" . ( time() + $offset );
        my $claimed   = eval { $redis->eval( $claim_script, 1, $candidate, @field_args ) };
        if ($@) {
            $logger->error("Redis error during registry id claim: $@");
            return ( undef, "Redis error while creating registry." );
        }
        if ($claimed) {
            $registry_id = $candidate;
        } else {
            $offset++;
        }
    }

    $logger->info("Created registry '$registry_id' (name: $config{name}, type: $registry_type)");

    return ( $registry_id, undef );
}

# Get a registry's config by ID.
sub get_registry {
    my ( $registry_id, $redis ) = @_;

    unless ( is_valid_registry( $registry_id, $redis ) ) {
        get_logger( "Registry", "lanraragi" )->warn("Registry lookup failed for invalid or missing registry id '$registry_id'.");
        return ();
    }

    my %config = $redis->hgetall($registry_id);
    $config{id} = $registry_id;

    return %config;
}

# List all registries.
sub get_registry_list {
    my ($redis) = @_;

    my @reg_ids = $redis->keys("REG_??????????");

    my @result;

    # Sort by timestamp for deterministic order across multiple registries.
    foreach my $key ( sort @reg_ids ) {
        my %config = get_registry( $key, $redis );
        push @result, \%config if %config;    # skip if deleted between keys() and hgetall
    }

    return @result;
}

# Update mutable fields on an existing registry.
sub update_registry {
    my ( $registry_id, $redis, %updated_registry ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );
    $logger->info("Updating registry '$registry_id'");

    unless ( is_valid_registry( $registry_id, $redis ) ) {
        return ( 404, undef, "This registry doesn't exist." );
    }

    # Sanitize local registry path if provided
    if ( defined $updated_registry{path} ) {
        if ( index( $updated_registry{path}, "\0" ) >= 0 || $updated_registry{path} =~ /\.\./ ) {
            return ( 400, undef, "Invalid registry path." );
        }
    }

    my %current_registry = $redis->hgetall($registry_id);

    # type enum is validated by OpenAPI (enum: [github, gitlab, gitea, cdn, local]) on the request body.
    my $updated_registry_type = $updated_registry{type};
    my $current_registry_type = $current_registry{type};
    my $target_registry_type  = defined $updated_registry_type ? $updated_registry_type : $current_registry_type;

    my %valid_set = map { $_ => 1 } @{ $TYPE_FIELDS{$target_registry_type} };
    my @invalid_fields = sort grep { !$valid_set{$_} } keys %updated_registry;
    if (@invalid_fields) {
        return ( 400, undef, "Fields not valid for type '$target_registry_type': " . join( ", ", @invalid_fields ) );
    }

    # Determine if source fields are changing
    my $indexcleared = 0;
    foreach my $field (@SOURCE_FIELDS) {
        next unless exists $updated_registry{$field};
        if ( !defined $current_registry{$field} || $current_registry{$field} ne $updated_registry{$field} ) {
            $logger->info("Source field '$field' changed on '$registry_id'; will clear cached index.");
            $indexcleared = 1;
            last;
        }
    }

    # Partial updates may omit fields already stored; merge before validating.
    my %merged = ( %current_registry, %updated_registry );

    if ( $target_registry_type eq "github" || $target_registry_type eq "gitlab" || $target_registry_type eq "gitea" ) {
        return ( 400, undef, "Git registry needs a URL." ) unless $merged{url};
        return ( 400, undef, "Git registry needs a ref." ) unless $merged{ref};
    } elsif ( $target_registry_type eq "cdn" ) {
        return ( 400, undef, "CDN registry needs a URL." ) unless $merged{url};
    } elsif ( $target_registry_type eq "local" ) {
        return ( 400, undef, "Local registry needs a path." ) unless $merged{path};
    }

    # If a type change is made, then registry may be left with stale or mixed type states, which we'll need to clean up.
    my @fields_to_remove;
    # type is always set on a valid registry (stored at creation)
    if ( exists $updated_registry{type} && $updated_registry_type ne $current_registry_type ) {
        $logger->info("Type change on '$registry_id': '$current_registry_type' -> '$target_registry_type'; removing stale fields.");
        @fields_to_remove = @{ $STALE_FIELDS{$target_registry_type} };
    }

    my @fields_to_set;
    foreach my $field ( keys %updated_registry ) {
        $logger->debug("Setting field '$field' on '$registry_id'");
        push @fields_to_set, $field, $updated_registry{$field};
    }

    if ( !@fields_to_set && !@fields_to_remove ) {
        return ( 400, undef, "No valid fields to update for this registry type." );
    }

    my $now = time;
    push @fields_to_set, "updated", $now;

    my $indexkey = "";
    if ( $indexcleared ) {
        my ($suffix) = $registry_id =~ /^REG_(\d{10})$/;
        $indexkey = "REG_INDEX_$suffix";
    }

    my $script = <<'LUA';
    local ndel = tonumber(ARGV[1])
    local idx = 2
    for _ = 1, ndel do
        redis.call("HDEL", KEYS[1], ARGV[idx])
        idx = idx + 1
    end
    while idx + 1 <= #ARGV do
        redis.call("HSET", KEYS[1], ARGV[idx], ARGV[idx + 1])
        idx = idx + 2
    end
    if KEYS[2] ~= "" then
        redis.call("DEL", KEYS[2])
    end
    return 1
LUA

    eval {
        $redis->eval( $script, 2, $registry_id, $indexkey,
            scalar @fields_to_remove, @fields_to_remove, @fields_to_set );
    };
    if ( my $err = $@ ) {
        $logger->error("Redis error during registry update for '$registry_id': $err");
        return ( 500, undef, "Redis error while updating registry." );
    }

    if ( $indexcleared ) {
        $logger->info("Cleared cached index for '$registry_id' due to source field change.");
    }

    return ( 200, $indexcleared, undef );
}

# Delete a registry and its cached index.
sub delete_registry {
    my ( $registry_id, $redis ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );

    unless ( is_valid_registry( $registry_id, $redis ) ) {
        return ( 404, undef, "This registry doesn't exist." );
    }

    my ($suffix) = $registry_id =~ /^REG_(\d{10})$/;
    my $registry_index_key      = "REG_INDEX_$suffix";

    # Delete registry + index key
    my $script = <<'LUA';
    redis.call("DEL", KEYS[1])
    redis.call("DEL", KEYS[2])
    return 1
LUA

    eval { $redis->eval( $script, 2, $registry_id, $registry_index_key ) };
    if ($@) {
        $logger->error("Redis error during registry delete for '$registry_id': $@");
        return ( 500, undef, "Redis error while deleting registry." );
    }

    if ( ( $redis->hget( 'LRR_CONFIG', 'default_registry' ) || "" ) eq $registry_id ) {
        $redis->hdel( 'LRR_CONFIG', 'default_registry' );
        $logger->info("Cleared default-registry pointer that referenced deleted '$registry_id'.");
    }

    $logger->info("Deleted registry '$registry_id'.");

    return ( 200, 1, undef );
}

# Get the configured default registry id, or empty string if unset.
sub get_default_registry {
    my ($redis) = @_;
    return $redis->hget( 'LRR_CONFIG', 'default_registry' ) || "";
}

# Set the configured default registry to $registry_id.
# Returns ( $status_code, $registry_id, $message ).
sub update_default_registry {
    my ( $registry_id, $redis ) = @_;
    unless ( defined $registry_id && $registry_id =~ /^REG_\d{10}$/ ) {
        return ( 400, $registry_id, "Input registry ID is invalid." );
    }
    unless ( $redis->exists($registry_id) ) {
        return ( 404, $registry_id, "Registry does not exist!" );
    }
    $redis->hset( 'LRR_CONFIG', 'default_registry', $registry_id );
    return ( 200, $registry_id, "success" );
}

# Clear the configured default registry. Returns the previously-set id (empty string if unset).
sub remove_default_registry {
    my ($redis) = @_;
    my $registry_id = $redis->hget( 'LRR_CONFIG', 'default_registry' ) || "";
    $redis->hdel( 'LRR_CONFIG', 'default_registry' );
    return $registry_id;
}

# Fetch registry.json from a configured registry source.
sub fetch_registry_index {
    my %registry_config = @_;
    return fetch_registry_resource( \%registry_config, "registry.json", MAX_REGISTRY_INDEX_SIZE );
}

sub refresh_registry {
    my ( $registry_id, $redis ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );
    my %config = get_registry( $registry_id, $redis );

    unless (%config) {
        return ( 404, undef, "This registry doesn't exist." );
    }

    my ( $status, $registry_content, $message ) = fetch_registry_index(%config);
    unless ( $status == 200 ) {
        return ( $status, undef, $message );
    }

    my $registry_index = eval { decode_json($registry_content) };
    if ($@) {
        my $error = "Invalid registry.json: $@";
        $logger->warn("Registry '$registry_id': failed to decode registry index: $@");
        return ( 400, undef, $error );
    }

    my $validation_error = validate_registry_index($registry_index);
    if ($validation_error) {
        $logger->warn("Registry '$registry_id': registry index failed validation: $validation_error");
        return ( 400, undef, $validation_error );
    }

    my ($suffix) = $registry_id =~ /^REG_(\d{10})$/;
    my $registry_index_key = "REG_INDEX_$suffix";

    # Spec-contract checks against the previously cached index, if any.
    # Removed versions and cross-refresh type changes are publisher-contract
    # violations the spec asks LRR to surface where practical.
    my $previous_registry_content = $redis->get($registry_index_key);
    if ( defined $previous_registry_content && $previous_registry_content ne "" ) {
        my $previous_registry_index = eval { decode_json($previous_registry_content) };
        if ($@) {
            $logger->warn("Registry '$registry_id': cached previous registry index could not be decoded: $@");
        }
        if ( ref $previous_registry_index eq "HASH" && ref $previous_registry_index->{plugins} eq "HASH" ) {
            my $previous_plugin_map = $previous_registry_index->{plugins};
            my $current_plugin_map  = $registry_index->{plugins};
            foreach my $ns ( sort keys %{$previous_plugin_map} ) {
                unless ( exists $current_plugin_map->{$ns} ) {
                    $logger->warn("Registry $registry_id: plugin '$ns' removed from registry");
                    next;
                }
                if (   defined $previous_plugin_map->{$ns}{type}
                    && defined $current_plugin_map->{$ns}{type}
                    && $previous_plugin_map->{$ns}{type} ne $current_plugin_map->{$ns}{type} )
                {
                    $logger->warn(
                        "Registry $registry_id: plugin '$ns' type changed from '$previous_plugin_map->{$ns}{type}' to '$current_plugin_map->{$ns}{type}' (spec invariant violation)"
                    );
                }
                my $previous_plugin_versions = $previous_plugin_map->{$ns}{versions} || {};
                my $current_plugin_versions  = $current_plugin_map->{$ns}{versions} || {};
                foreach my $ver ( sort keys %{$previous_plugin_versions} ) {
                    unless ( exists $current_plugin_versions->{$ver} ) {
                        $logger->warn("Registry $registry_id: plugin '$ns' version '$ver' removed from registry");
                    }
                }
            }
        }
    }

    eval { $redis->set( $registry_index_key, $registry_content ) };
    if ($@) {
        $logger->error("Redis error during registry refresh for '$registry_id': $@");
        return ( 500, undef, "Redis error while refreshing registry." );
    }

    return ( 200, $registry_index, undef );
}

1;
