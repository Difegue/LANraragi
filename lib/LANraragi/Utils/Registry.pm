package LANraragi::Utils::Registry;

use strict;
use warnings;
use utf8;

use Cwd qw(abs_path getcwd);
use File::Find;
use Mojo::Util qw(url_escape);

use Mojo::File;
use Mojo::UserAgent;
use SemVer;

use LANraragi::Utils::Logging qw(get_logger);

use Exporter 'import';
our @EXPORT_OK = qw(
    resolve_git_raw_url
    resolve_cdn_artifact_url
    fetch_registry_resource
    find_package_conflict
    find_namespace_conflict
    validate_registry_index
    validate_registry_artifact_path
    resolve_local_registry_artifact_path
    is_valid_registry
    is_valid_registry_timestamp
    resolve_max_version
    MANAGED_TYPE_DIRS
);

# Returns true if $registry_id is well-formed and currently exists in Redis.
sub is_valid_registry {
    my ( $registry_id, $redis ) = @_;
    return defined $registry_id
        && $registry_id =~ /^REG_\d{10}$/
        && $redis->exists($registry_id);
}

# Maps plugin_info type values to directory names under Plugin/Managed/.
use constant MANAGED_TYPE_DIRS => {
    metadata => "Metadata",
    download => "Download",
    login    => "Login",
    script   => "Scripts",
};

# Allowed-field whitelists for registry.json schema.
my @ALLOWED_ROOT_FIELDS     = qw(version generated_at plugins);
my @ALLOWED_PLUGIN_FIELDS   = qw(namespace type versions);
my @ALLOWED_VERSION_FIELDS  = qw(version name author description artifact sha256 published_at);
my @REQUIRED_VERSION_FIELDS = qw(name author description artifact sha256 published_at);

# Resolve a git URL to a raw file URL for a given type
# (Should) support github, gitlab, and gitea/codeberg types but who knows
sub resolve_git_raw_url {
    my ( $type, $url, $ref, $path ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );

    # TODO: this just needs to be tested more (maybe with a Gitlab + Gitea repo)
    my ( $host, $owner, $repo );
    if ( $url =~ m{^https?://([^/]+)/(.+)/([^/]+?)(?:\.git)?$} ) {
        ( $host, $owner, $repo ) = ( $1, $2, $3 );
    } else {
        $logger->error("Cannot parse git URL: $url");
        return;
    }

    my $epath = join( "/", map { url_escape($_) } split( m{/}, $path ) );
    my $eref  = url_escape($ref);

    if ( $type eq "github" ) {
        return "https://raw.githubusercontent.com/$owner/$repo/$eref/$epath";
    } elsif ( $type eq "gitlab" ) {
        return "https://$host/$owner/$repo/-/raw/$eref/$epath";
    } elsif ( $type eq "gitea" ) {
        return "https://$host/api/v1/repos/$owner/$repo/raw/$epath?ref=$eref";
    }

    $logger->error("Unknown registry type '$type' for URL: $url");
    return;
}

# Resolve a CDN registry base URL plus a registry-relative path into a fetchable URL.
# Accepts http:// or https://. Trailing slashes on the base are tolerated.
sub resolve_cdn_artifact_url {
    my ( $base_url, $path ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );

    unless ( defined $base_url && $base_url =~ m{^https?://}i ) {
        $logger->error( "CDN base URL must use http or https scheme: " . ( $base_url // "" ) );
        return;
    }

    ( my $base = $base_url ) =~ s{/+\z}{};
    my $epath = join( "/", map { url_escape($_) } grep { length $_ } split( m{/}, $path ) );
    return "$base/$epath";
}

# Transport adapter: fetch a registry-relative resource from any registry type.
# Returns ( $status, $body, $error ) — $status 200 on success.
sub fetch_registry_resource {
    my ( $registry_config, $relpath, $max_size ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );
    my $type   = $registry_config->{type};

    if ( $type eq "local" ) {
        my ( undef, $file_canon, $resolve_error ) =
            resolve_local_registry_artifact_path( $registry_config->{path}, $relpath );
        if ($resolve_error) {
            $logger->warn("Local registry resolution failed for '$relpath': $resolve_error");
            return ( 400, undef, $resolve_error );
        }
        unless ( -f $file_canon ) {
            return ( 400, undef, "Resource is not a regular file: $file_canon" );
        }
        my $filesize = -s $file_canon;
        if ( $filesize == 0 ) {
            return ( 400, undef, "Resource is empty: $file_canon" );
        }
        if ( defined $max_size && $filesize > $max_size ) {
            return ( 400, undef, "Resource too large: $file_canon ($filesize bytes, max $max_size)" );
        }
        my $content = eval { Mojo::File->new($file_canon)->slurp };
        unless ( defined $content ) {
            return ( 500, undef, "Cannot read resource: $@" );
        }
        return ( 200, $content, undef );
    }

    if ( $type eq "github" || $type eq "gitlab" || $type eq "gitea" ) {
        my $url = resolve_git_raw_url(
            $type, $registry_config->{url},
            $registry_config->{ref}, $relpath
        );
        unless ($url) {
            return ( 400, undef, "Cannot resolve git URL for $relpath" );
        }

        $logger->info("Fetching registry resource from $url");
        my $ua = Mojo::UserAgent->new;
        $ua->max_response_size($max_size) if defined $max_size;
        my $res = eval { $ua->get($url)->result };
        unless ( defined $res ) {
            return ( 502, undef, "Cannot reach registry: $@" );
        }
        unless ( $res->is_success ) {
            return ( 502, undef, "Failed to fetch resource: HTTP " . $res->code );
        }
        return ( 200, $res->body, undef );
    }

    if ( $type eq "cdn" ) {
        my $url = resolve_cdn_artifact_url( $registry_config->{url}, $relpath );
        unless ($url) {
            return ( 400, undef, "Cannot resolve CDN URL for $relpath" );
        }

        $logger->info("Fetching registry resource from $url");
        my $ua = Mojo::UserAgent->new;
        $ua->max_response_size($max_size) if defined $max_size;
        my $res = eval { $ua->get($url)->result };
        unless ( defined $res ) {
            return ( 502, undef, "Cannot reach registry: $@" );
        }
        unless ( $res->is_success ) {
            return ( 502, undef, "Failed to fetch resource: HTTP " . $res->code );
        }
        return ( 200, $res->body, undef );
    }

    return ( 400, undef, "Unknown registry type: $type" );
}

# Scan Plugin/ for a .pm file declaring the given package name
sub find_package_conflict {
    my ( $package_name, $skip_path ) = @_;

    return _find_conflict(
        $skip_path,
        sub {
            my ($filepath) = @_;
            my $content = eval { Mojo::File->new($filepath)->slurp } or return;
            return $content =~ /^package\s+\Q$package_name\E\s*;/m;
        }
    );
}

# Scan Plugin/ for a .pm file declaring the given namespace
sub find_namespace_conflict {
    my ( $namespace, $skip_path ) = @_;

    return _find_conflict(
        $skip_path,
        sub {
            my ($filepath) = @_;
            my $content = eval { Mojo::File->new($filepath)->slurp } or return;
            return $content =~ /namespace\s*=>\s*['"]\Q$namespace\E['"]/i;
        }
    );
}

# strictly check registry index satisfies a bunch of registry spec-related conditions...
sub validate_registry_index {
    my ($index) = @_;

    unless ( ref $index eq "HASH" ) {
        return "Invalid registry.json: root must be an object.";
    }

    my %allowed_root = map { $_ => 1 } @ALLOWED_ROOT_FIELDS;
    foreach my $field ( keys %{$index} ) {
        unless ( $allowed_root{$field} ) {
            return "Invalid registry.json: unknown root field '$field'.";
        }
    }

    unless ( defined $index->{version} && $index->{version} == 1 ) {
        return "Invalid registry.json: registry version must be 1.";
    }
    unless ( defined $index->{generated_at} && $index->{generated_at} ne "" ) {
        return "Invalid registry.json: 'generated_at' is required.";
    }
    unless ( is_valid_registry_timestamp( $index->{generated_at} ) ) {
        return "Invalid registry.json: 'generated_at' must be a UTC RFC3339 timestamp.";
    }
    unless ( ref $index->{plugins} eq "HASH" ) {
        return "Invalid registry.json: 'plugins' must be an object.";
    }

    foreach my $namespace ( sort keys %{ $index->{plugins} } ) {
        my $plugin = $index->{plugins}{$namespace};
        unless ( ref $plugin eq "HASH" ) {
            return "Invalid registry.json: plugin '$namespace' must be an object.";
        }

        my %allowed_plugin = map { $_ => 1 } @ALLOWED_PLUGIN_FIELDS;
        foreach my $field ( keys %{$plugin} ) {
            unless ( $allowed_plugin{$field} ) {
                return "Invalid registry.json: plugin '$namespace' has unknown field '$field'.";
            }
        }

        unless ( defined $plugin->{namespace} && $plugin->{namespace} eq $namespace ) {
            return "Invalid registry.json: plugin key '$namespace' must match inner namespace.";
        }
        unless ( $namespace =~ /\A[a-z0-9_-]+\z/ ) {
            return "Invalid registry.json: plugin namespace '$namespace' must match ^[a-z0-9_-]+\$ (lowercase only).";
        }
        unless ( defined $plugin->{type} && MANAGED_TYPE_DIRS->{ $plugin->{type} } ) {
            return "Invalid registry.json: plugin '$namespace' has invalid type '$plugin->{type}'.";
        }
        unless ( ref $plugin->{versions} eq "HASH" && keys %{ $plugin->{versions} } ) {
            return "Invalid registry.json: plugin '$namespace' 'versions' must be a non-empty object.";
        }

        foreach my $version_key ( sort keys %{ $plugin->{versions} } ) {
            # SemVer 2.0.0 forbids a leading "v" prefix. The SemVer module accepts it; reject explicitly.
            if ( $version_key =~ /^v/i ) {
                return "Invalid registry.json: plugin '$namespace' version key '$version_key' is not a valid SemVer 2.0.0 string.";
            }
            my $semver_ok = eval { SemVer->new($version_key); 1 };
            unless ($semver_ok) {
                return "Invalid registry.json: plugin '$namespace' version key '$version_key' is not a valid SemVer 2.0.0 string.";
            }
            my $version = $plugin->{versions}{$version_key};
            unless ( ref $version eq "HASH" ) {
                return "Invalid registry.json: plugin '$namespace' version '$version_key' must be an object.";
            }

            my %allowed_version = map { $_ => 1 } @ALLOWED_VERSION_FIELDS;
            foreach my $field ( keys %{$version} ) {
                unless ( $allowed_version{$field} ) {
                    return "Invalid registry.json: plugin '$namespace' version '$version_key' has unknown field '$field'.";
                }
            }

            unless ( defined $version->{version} && $version->{version} eq $version_key ) {
                return "Invalid registry.json: plugin '$namespace' version key '$version_key' must match inner version.";
            }
            foreach my $required (@REQUIRED_VERSION_FIELDS) {
                unless ( defined $version->{$required} && $version->{$required} ne "" ) {
                    return "Invalid registry.json: plugin '$namespace' version '$version_key' is missing '$required'.";
                }
            }

            my ( $artifact_valid, $artifact_error ) = validate_registry_artifact_path( $version->{artifact} );
            unless ($artifact_valid) {
                return $artifact_error;
            }

            unless ( $version->{sha256} =~ /\A[a-f0-9]{64}\z/ ) {
                return "Invalid registry.json: plugin '$namespace' version '$version_key' sha256 must be 64 lowercase hexadecimal characters.";
            }
            unless ( is_valid_registry_timestamp( $version->{published_at} ) ) {
                return "Invalid registry.json: plugin '$namespace' version '$version_key' published_at must be a UTC RFC3339 timestamp.";
            }
        }
    }

    return;
}

sub validate_registry_artifact_path {
    my ($plugpath) = @_;

    unless ( defined $plugpath && $plugpath ne "" ) {
        return ( undef, "Invalid registry.json: version artifact is required." );
    }
    if ( index( $plugpath, "\0" ) >= 0 ) {
        return ( undef, "Invalid registry.json: artifact path contains a null byte." );
    }
    if ( Mojo::File->new($plugpath)->is_abs ) {
        return ( undef, "Invalid registry.json: artifact path must be relative." );
    }
    if ( grep { $_ eq "." || $_ eq ".." } @{ Mojo::File->new($plugpath)->to_array } ) {
        return ( undef, "Invalid registry.json: artifact path must not contain '.' or '..' segments." );
    }

    return ( 1, undef );
}

sub resolve_local_registry_artifact_path {
    my ( $registry_root, $plugpath ) = @_;

    my $root_canon = abs_path($registry_root);
    unless ( $root_canon && -d $root_canon ) {
        return ( undef, undef, "Invalid local registry path: $registry_root" );
    }

    my $candidate = Mojo::File->new($root_canon)->child( @{ Mojo::File->new($plugpath)->to_array } )->to_string;
    unless ( -e $candidate ) {
        return ( $root_canon, undef, "Plugin file not found: $candidate" );
    }

    my $file_canon = abs_path($candidate);
    unless ($file_canon) {
        return ( $root_canon, undef, "Invalid plugin artifact path: $plugpath" );
    }

    my $root_prefix = $root_canon =~ m{/\z} ? $root_canon : "$root_canon/";
    unless ( index( $file_canon, $root_prefix ) == 0 ) {
        return ( $root_canon, undef, "Invalid plugin artifact path: $plugpath" );
    }

    return ( $root_canon, $file_canon, undef );
}

# Check timestamp is (stylistically) of the form "9999-99-99T99:99:99Z".
sub is_valid_registry_timestamp {
    my ($timestamp) = @_;
    return $timestamp =~ /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/;
}

# Return the SemVer-greatest version key from a plugin record's versions map.
# $plugin_root: the plugin record hashref (must have a non-empty 'versions' map).
# Pure function, no Redis.
sub resolve_max_version {
    my ($plugin_root) = @_;

    my @keys = keys %{ $plugin_root->{versions} };
    my ($max) = sort { SemVer->new($b) <=> SemVer->new($a) } @keys;
    return $max;
}


# Scan Plugin/ directory for a .pm file matching the given criteria.
# $skip_path: optional absolute filepath to exclude
# $match_fn: coderef($filepath, $fh) -> bool; return true if filepath conflicts.
sub _find_conflict {
    my ( $skip_path, $match_fn ) = @_;

    my $plugin_dir = getcwd() . "/lib/LANraragi/Plugin";
    my $conflict;

    return unless -d $plugin_dir;

    find(
        {   wanted => sub {
                return if $conflict;
                return unless /\.pm$/;
                return if $skip_path && $_ eq $skip_path;

                if ( $match_fn->($_) ) {
                    $conflict = $_;
                }
            },
            no_chdir    => 1,
            follow_fast => 1,
        },
        $plugin_dir
    );

    return $conflict;
}

1;
