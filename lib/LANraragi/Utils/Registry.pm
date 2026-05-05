package LANraragi::Utils::Registry;

use strict;
use warnings;
use utf8;

use Cwd qw(abs_path getcwd);
use File::Spec; # TODO(REVIEW): why use this over Path? Check dev for consistency.
use Mojo::Util qw(url_escape);

use Mojo::File;
use SemVer;

use LANraragi::Utils::Path    qw(find_path);
use LANraragi::Utils::Logging qw(get_logger);

use Exporter 'import';
our @EXPORT_OK = qw(
    resolve_git_raw_url
    find_package_conflict
    find_namespace_conflict
    validate_registry_index
    validate_registry_artifact_path
    resolve_local_registry_artifact_path
    is_valid_registry_timestamp
    resolve_max_version
    MANAGED_TYPE_DIRS
);

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

# Resolve a git URL to a raw file URL for a given provider
# (Should) support github, gitlab, and gitea/codeberg providers but who knows
sub resolve_git_raw_url {
    my ( $provider, $url, $ref, $path ) = @_;

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

    if ( $provider eq "github" ) {
        return "https://raw.githubusercontent.com/$owner/$repo/$ref/$epath";
    } elsif ( $provider eq "gitlab" ) {
        return "https://$host/$owner/$repo/-/raw/$ref/$epath";
    } elsif ( $provider eq "gitea" ) {
        return "https://$host/api/v1/repos/$owner/$repo/raw/$epath?ref=" . url_escape($ref);
    }

    $logger->error("Unknown provider '$provider' for URL: $url");
    return;
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


# Scan Plugin/ directory for a .pm file matching the given criteria.
# $skip_path: optional absolute filepath to exclude
# $match_fn: coderef($filepath, $fh) -> bool; return true if filepath conflicts.
# TODO(REVIEW): move to bottom.
sub _find_conflict {
    my ( $skip_path, $match_fn ) = @_;

    my $plugin_dir = getcwd() . "/lib/LANraragi/Plugin";
    my $conflict;

    return unless -d $plugin_dir;

    find_path(
        sub {
            return if $conflict;
            return unless /\.pm$/; # TODO(REVIEW): why here? "for a .pm file"
            return if $skip_path && $_ eq $skip_path;

            if ( $match_fn->($_) ) {
                $conflict = $_;
            }
        },
        $plugin_dir
    );

    return $conflict;
}

# strictly check registry index satisfies a bunch of registry spec-related conditions...
# TODO(REVIEW): group things together more logically
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

            unless ( $version->{sha256} =~ /\A[a-fA-F0-9]{64}\z/ ) {
                return "Invalid registry.json: plugin '$namespace' version '$version_key' sha256 must be 64 hexadecimal characters.";
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
    if ( File::Spec->file_name_is_absolute($plugpath) ) {
        return ( undef, "Invalid registry.json: artifact path must be relative." );
    }
    if ( grep { $_ eq "." || $_ eq ".." } File::Spec->splitdir($plugpath) ) {
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

    my $candidate = File::Spec->catfile( $root_canon, File::Spec->splitdir($plugpath) );
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

1;
