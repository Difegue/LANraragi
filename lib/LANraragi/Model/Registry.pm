package LANraragi::Model::Registry;

use strict;
use warnings;
use utf8;

use Mojo::JSON qw(decode_json);

use LANraragi::Utils::Logging  qw(get_logger);
use LANraragi::Utils::Registry qw(
    fetch_registry_resource
    validate_registry_index
);

# Max registry index size for slurp (files will/should never reach this size anyways but stops OOM)
use constant MAX_REGISTRY_INDEX_SIZE => 100 * 1024 * 1024;      # 100 MB

# Fields valid per registry provider.
my %PROVIDER_FIELDS = (
    github  => [qw(name provider url ref)],
    gitlab  => [qw(name provider url ref)],
    gitea   => [qw(name provider url ref)],
    cdn     => [qw(name provider url)],
    local   => [qw(name provider path)],
);

# Fields that must be removed when switching providers.
# Computed as: source fields minus the target provider's valid fields.
my %STALE_FIELDS = do {
    my @source_fields = qw(provider url ref path);
    map {
        my $provider  = $_;
        my %valid_set = map { $_ => 1 } @{ $PROVIDER_FIELDS{$provider} };
        $provider => [ grep { !$valid_set{$_} } @source_fields ];
    } keys %PROVIDER_FIELDS;
};

# Create a registry entry with a generated REG_{timestamp} ID.
# Returns ( $registry_id, undef ) or ( undef, $error_message ).
sub create_registry {
    my ( $config, $redis ) = @_;
    my $name     = $config->{name};
    my $provider = $config->{provider};

    my $logger = get_logger( "Registry", "lanraragi" );
    $logger->debug("Creating registry (provider: $provider)");

    # Atomically claim an unused ID and populate registry hash in one go.
    my $script = <<~'LUA';
        if redis.call("EXISTS", KEYS[1]) == 1 then
            return 0
        end
        redis.call("HSET", KEYS[1], unpack(ARGV))
        return 1
        LUA

    # Prepare fields
    my @field_args;
    my @valid_fields = @{ $PROVIDER_FIELDS{$provider} };
    foreach my $field (@valid_fields) {
        push @field_args, $field, $config->{$field};
    }
    my $now = time;
    push @field_args, "created", $now, "updated", $now;

    # Start running script until a registry is created
    my $registry_id;
    my $offset = 0;
    until ( $registry_id ) {
        my $candidate   = "REG_" . ( time() + $offset );
        my $claimed     = eval { $redis->eval(
            $script, 1, $candidate,
            @field_args
        ) };
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
    $logger->info("Created registry '$registry_id' (name: $name, provider: $provider)");
    return ( $registry_id, undef );
}

# Returns ( \%config, $status, $message )
sub get_registry {
    my ( $registry_id, $redis ) = @_;

    unless ( defined $registry_id && $registry_id =~ /^REG_\d{10}$/ ) {
        return ( undef, 400, "Registry ID is malformed." );
    }
    my %config = $redis->hgetall($registry_id);
    return ( undef, 404, "This registry doesn't exist." ) unless %config;
    $config{id} = $registry_id;
    return ( \%config, 200, undef );
}

sub get_registry_list {
    my ($redis) = @_;

    # Sort by timestamp for deterministic order across multiple registries.
    my @result;
    my @reg_ids = $redis->keys("REG_??????????");
    foreach my $key ( sort @reg_ids ) {
        my ( $config ) = get_registry( $key, $redis );
        push @result, $config if $config; # skip if deleted between keys() and hgetall
    }

    return @result;
}

# Update mutable fields on an existing registry.
# Partial updates through updated_registry are accepted.
sub update_registry {
    my ( $registry_id, $redis, %updated_registry ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );
    $logger->debug("Updating registry '$registry_id'");

    # Argument validation
    if ( !%updated_registry ) {
        return ( 400, "No fields provided to update.");
    }

    # Target registry existence validation
    my ( $registry, $lookup_status, $lookup_error ) = get_registry( $registry_id, $redis );
    return ( $lookup_status, $lookup_error ) unless $registry;
    my ($suffix)                    = $registry_id =~ /^REG_(\d{10})$/;
    my $registry_index_key          = "REG_INDEX_$suffix";

    # Source registry field validation
    my %current_registry            = %$registry;
    my $updated_registry_provider   = $updated_registry{provider};
    my $current_registry_provider   = $current_registry{provider};
    my $target_registry_provider    = defined $updated_registry_provider ? $updated_registry_provider : $current_registry_provider;
    my %valid_set                   = map { $_ => 1 } @{ $PROVIDER_FIELDS{$target_registry_provider} };
    my @invalid_fields              = sort grep { !$valid_set{$_} } keys %updated_registry;
    if (@invalid_fields) {
        return ( 400, "Fields not valid for provider '$target_registry_provider': " . join( ", ", @invalid_fields ) );
    }

    # Partial updates may omit fields already stored; merge before validating.
    my %merged = ( %current_registry, %updated_registry );
    if ( $target_registry_provider eq "github" || $target_registry_provider eq "gitlab" || $target_registry_provider eq "gitea" ) {
        return ( 400, "Git registry needs a URL." )      unless $merged{url};
        return ( 400, "Git registry needs a ref." )      unless $merged{ref};
    } elsif ( $target_registry_provider eq "cdn" ) {
        return ( 400, "CDN registry needs a URL." )      unless $merged{url};
    } elsif ( $target_registry_provider eq "local" ) {
        return ( 400, "Local registry needs a path." )   unless $merged{path};
    }

    # Prepare fields to remove/set.
    my @fields_to_remove;   # remove stale fields whenever provider changes
    my @fields_to_set;      # apply only changes from updated_registry
    if ( exists $updated_registry{provider} && $updated_registry_provider ne $current_registry_provider ) {
        $logger->info("Provider change on '$registry_id': '$current_registry_provider' -> '$target_registry_provider'; removing stale fields.");
        @fields_to_remove = @{ $STALE_FIELDS{$target_registry_provider} };
    }
    foreach my $field ( keys %updated_registry ) {
        my $updated_value = $updated_registry{$field};
        my $current_value = $current_registry{$field};
        if ( defined $current_value && $current_value eq $updated_value ) {
            $logger->debug("Skipping unchanged field '$field' on '$registry_id'");
            next;
        }
        $logger->debug("Setting field '$field' on '$registry_id'");
        push @fields_to_set, $field, $updated_value;
    }
    if ( !@fields_to_set && !@fields_to_remove ) {
        $logger->debug("No fields to update.");
        return ( 200, undef );
    }
    push @fields_to_set, "updated", time;

    # Remove from fields_to_remove,
    # set from fields_to_set,
    # remove index.
    my $script = <<~'LUA';
        local remove_count  = tonumber(ARGV[1])
        local idx           = 2
        for _ = 1, remove_count do
            redis.call("HDEL", KEYS[1], ARGV[idx])
            idx = idx + 1
        end
        while idx + 1 <= #ARGV do
            redis.call("HSET", KEYS[1], ARGV[idx], ARGV[idx + 1])
            idx = idx + 2
        end
        redis.call("DEL", KEYS[2])
        LUA
    eval {
        $redis->eval(
            $script, 2, $registry_id, $registry_index_key,
            scalar @fields_to_remove,
            @fields_to_remove,
            @fields_to_set
        );
    };
    if ( my $err = $@ ) {
        $logger->error("Redis error during registry update for '$registry_id': $err");
        return ( 500, "Redis error while updating registry." );
    }

    return ( 200, undef );
}

# Delete a registry and its cached index.
sub delete_registry {
    my ( $registry_id, $redis ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );

    my ( $registry, $lookup_status, $lookup_error ) = get_registry( $registry_id, $redis );
    return ( $lookup_status, $lookup_error ) unless $registry;

    my ($suffix) = $registry_id =~ /^REG_(\d{10})$/;
    my $registry_index_key      = "REG_INDEX_$suffix";

    # Delete registry + index key
    my $script = <<~'LUA';
        redis.call("DEL", KEYS[1])
        redis.call("DEL", KEYS[2])
        LUA

    eval { $redis->eval( $script, 2, $registry_id, $registry_index_key ) };
    if ($@) {
        $logger->error("Redis error during registry delete for '$registry_id': $@");
        return ( 500, "Redis error while deleting registry." );
    }

    if ( ( $redis->hget( 'LRR_CONFIG', 'default_registry' ) || "" ) eq $registry_id ) {
        $redis->hdel( 'LRR_CONFIG', 'default_registry' );
        $logger->info("Cleared default-registry pointer that referenced deleted '$registry_id'.");
    }

    $logger->info("Deleted registry '$registry_id'.");

    return ( 200, undef );
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
    my ( $registry, $lookup_status, $lookup_error ) = get_registry( $registry_id, $redis );
    return ( $lookup_status, $registry_id, $lookup_error ) unless $registry;
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

sub refresh_registry {
    my ( $registry_id, $redis ) = @_;

    my $logger  = get_logger( "Registry", "lanraragi" );

    my ( $registry, $lookup_status, $lookup_error ) = get_registry( $registry_id, $redis );
    return ( $lookup_status, undef, $lookup_error ) unless $registry;
    my ($suffix)            = $registry_id =~ /^REG_(\d{10})$/;
    my $registry_index_key  = "REG_INDEX_$suffix";

    # Fetch and validate registry index
    my ( $status, $registry_content, $message ) = fetch_registry_index(%$registry);
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

    # Update registry index
    eval { $redis->set( $registry_index_key, $registry_content ) };
    if ($@) {
        $logger->error("Redis error during registry refresh for '$registry_id': $@");
        return ( 500, undef, "Redis error while refreshing registry." );
    }

    return ( 200, $registry_index, undef );
}

# Fetch registry.json from a configured registry source.
sub fetch_registry_index {
    my %registry_config = @_;
    return fetch_registry_resource( \%registry_config, "registry.json", MAX_REGISTRY_INDEX_SIZE );
}

1;
