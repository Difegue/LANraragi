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
    fetch_registry_resource
    find_namespace_conflict
    find_package_conflict
    resolve_max_version
    validate_registry_artifact_path
    validate_registry_index
    MANAGED_TYPE_DIRS
);

# Maps plugin_info type values to directory names under Plugin/Managed/.
use constant MANAGED_TYPE_DIRS => {
    metadata    => "Metadata",
    download    => "Download",
    login       => "Login",
    script      => "Scripts",
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
    # TODO(REVIEW): audit
    if ( $url =~ m{^https?://([^/]+)/(.+)/([^/]+?)(?:\.git)?$} ) {
        ( $host, $owner, $repo ) = ( $1, $2, $3 );
    } else {
        $logger->error("Cannot parse git URL: $url");
        return;
    }

    my $escaped_path    = join( "/", map { url_escape($_) } split( m{/}, $path ) ); # TODO(REVIEW): audit
    my $escaped_ref     = url_escape($ref);
    return "https://raw.githubusercontent.com/$owner/$repo/$escaped_ref/$escaped_path"      if ( $provider eq "github" );
    return "https://$host/$owner/$repo/-/raw/$escaped_ref/$escaped_path"                    if ( $provider eq "gitlab" );
    return "https://$host/api/v1/repos/$owner/$repo/raw/$escaped_path?ref=$escaped_ref"     if ( $provider eq "gitea" );

    $logger->error("Unknown registry provider '$provider' for URL: $url");
    return;
}

# Resolve a CDN registry base URL plus a registry-relative path into a fetchable URL.
# Accepts http:// or https://. Trailing slashes on the base are tolerated.
sub resolve_cdn_artifact_url {
    my ( $base_url, $path ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );

    # TODO(REVIEW): audit
    unless ( defined $base_url && $base_url =~ m{^https?://}i ) {
        $logger->error( "CDN base URL must use http or https scheme: " . ( $base_url // "" ) );
        return;
    }

    $base_url =~ s{/+\z}{}; # strip the URL of its trailing slashes
    my $escaped_path = join( "/", map { url_escape($_) } grep { length $_ } split( m{/}, $path ) );
    return "$base_url/$escaped_path";
}

# Transport adapter: fetch a registry-relative resource from any registry provider.
# Returns ( $status, $body, $error ) + $status 200 on success.
sub fetch_registry_resource {
    my ( $registry_config, $relpath, $max_size ) = @_;

    my $logger      = get_logger( "Registry", "lanraragi" );
    my $provider    = $registry_config->{provider};

    if ( $provider eq "local" ) {
        my ( $file_canon, $resolve_error ) =
            resolve_local_registry_artifact_path( $registry_config->{path}, $relpath );
        if ($resolve_error) {
            $logger->warn("Local registry resolution failed for '$relpath': $resolve_error");
            return ( 400, undef, $resolve_error );
        }
        return ( 400, undef, "Resource is not a regular file: $file_canon" )                        unless ( -f $file_canon );
        my $filesize = -s $file_canon;

        return ( 400, undef, "Resource is empty: $file_canon" )                                     if ( $filesize == 0 );
        return ( 400, undef, "Resource too large: $file_canon ($filesize bytes, max $max_size)" )   if ( defined $max_size && $filesize > $max_size );

        my $content = eval { Mojo::File->new($file_canon)->slurp };
        return ( 500, undef, "Cannot read resource: $@" )                                           unless ( defined $content );
        return ( 200, $content, undef );
    }

    if ( $provider eq "github" || $provider eq "gitlab" || $provider eq "gitea" ) {
        my $url = resolve_git_raw_url(
            $provider, $registry_config->{url},
            $registry_config->{ref}, $relpath
        );
        return ( 400, undef, "Cannot resolve git URL for $relpath" )                                unless ($url);

        $logger->info("Fetching registry resource from $url");
        my $ua = Mojo::UserAgent->new;
        $ua->max_response_size($max_size) if defined $max_size;
        my $res = eval { $ua->get($url)->result };
        return ( 502, undef, "Cannot reach registry: $@" )                                          unless ( defined $res );
        return ( 502, undef, "Failed to fetch resource: HTTP " . $res->code )                       unless ( $res->is_success );
        return ( 200, $res->body, undef );
    }

    if ( $provider eq "cdn" ) {
        my $url = resolve_cdn_artifact_url( $registry_config->{url}, $relpath );
        return ( 400, undef, "Cannot resolve CDN URL for $relpath" )                                unless ($url);

        $logger->info("Fetching registry resource from $url");
        my $ua = Mojo::UserAgent->new;
        $ua->max_response_size($max_size) if defined $max_size;
        my $res = eval { $ua->get($url)->result };
        return ( 502, undef, "Cannot reach registry: $@" )                                          unless ( defined $res );
        return ( 502, undef, "Failed to fetch resource: HTTP " . $res->code )                       unless ( $res->is_success );
        return ( 200, $res->body, undef );
    }

    return ( 400, undef, "Unknown registry provider: $provider" );
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
    my ( $index ) = @_;

    return "Invalid registry.json: root must be an object."                                         unless ( ref $index eq "HASH" );

    my %allowed_root = map { $_ => 1 } @ALLOWED_ROOT_FIELDS;
    foreach my $field ( keys %{$index} ) {
        return "Invalid registry.json: unknown root field '$field'."                                unless ( $allowed_root{$field} );
    }

    return "Invalid registry.json: registry version must be 1."                                     unless ( defined $index->{version} && $index->{version} == 1 );
    return "Invalid registry.json: 'generated_at' is required."                                     unless ( defined $index->{generated_at} && $index->{generated_at} ne "" );
    return "Invalid registry.json: 'generated_at' must be a UTC RFC3339 timestamp."                 unless ( is_valid_registry_timestamp( $index->{generated_at} ) );
    return "Invalid registry.json: 'plugins' must be an object."                                    unless ( ref $index->{plugins} eq "HASH" );

    foreach my $namespace ( sort keys %{ $index->{plugins} } ) {
        my $plugin = $index->{plugins}{$namespace};
        return "Invalid registry.json: plugin '$namespace' must be an object."                      unless ( ref $plugin eq "HASH" );

        my %allowed_plugin = map { $_ => 1 } @ALLOWED_PLUGIN_FIELDS;
        foreach my $field ( keys %{$plugin} ) {
            return "Invalid registry.json: plugin '$namespace' has unknown field '$field'."         unless ( $allowed_plugin{$field} );
        }

        return "Invalid registry.json: plugin key '$namespace' must match inner namespace."         unless ( defined $plugin->{namespace} && $plugin->{namespace} eq $namespace );
        return "Invalid registry.json: plugin namespace '$namespace'" .
            " must match ^[a-z0-9_-]+\$ (lowercase only)."                                          unless ( $namespace =~ /\A[a-z0-9_-]+\z/ );
        return "Invalid registry.json: plugin '$namespace' has invalid type '$plugin->{type}'."     unless ( defined $plugin->{type} && MANAGED_TYPE_DIRS->{ $plugin->{type} } );
        return "Invalid registry.json: plugin '$namespace' 'versions' must be a non-empty object."  unless ( ref $plugin->{versions} eq "HASH" && keys %{ $plugin->{versions} } );

        foreach my $version_key ( sort keys %{ $plugin->{versions} } ) {

            # Explicitly enforce SemVer 2.0.0 syntax.
            return "Invalid registry.json: plugin '$namespace'" .
                " version key '$version_key' is not a valid SemVer 2.0.0 string."                   if ( $version_key =~ /^v/i );
            my $semver_ok = eval { SemVer->new($version_key); 1 };
            return "Invalid registry.json: plugin '$namespace'" .
                " version key '$version_key' is not a valid SemVer 2.0.0 string."                   unless ($semver_ok);
            my $version = $plugin->{versions}{$version_key};
            return "Invalid registry.json: plugin '$namespace'" .
                " version '$version_key' must be an object."                                        unless ( ref $version eq "HASH" );

            my %allowed_version = map { $_ => 1 } @ALLOWED_VERSION_FIELDS;
            foreach my $field ( keys %{$version} ) {
                return "Invalid registry.json: plugin '$namespace'" .
                    " version '$version_key' has unknown field '$field'."                           unless ( $allowed_version{$field} );
            }

            return "Invalid registry.json: plugin '$namespace'" .
                " version key '$version_key' must match inner version."                             unless ( defined $version->{version} && $version->{version} eq $version_key );
            foreach my $required (@REQUIRED_VERSION_FIELDS) {
                return "Invalid registry.json: plugin '$namespace'" .
                    " version '$version_key' is missing '$required'."                               unless ( defined $version->{$required} && $version->{$required} ne "" );
            }

            my ( $artifact_valid, $artifact_error ) = validate_registry_artifact_path( $version->{artifact} );
            return $artifact_error                                                                  unless ($artifact_valid);
            return "Invalid registry.json: plugin '$namespace'" .
                " version '$version_key' sha256 must be 64 lowercase hexadecimal characters."       unless ( $version->{sha256} =~ /\A[a-f0-9]{64}\z/ );
            return "Invalid registry.json: plugin '$namespace'" .
                " version '$version_key' published_at must be a UTC RFC3339 timestamp."             unless ( is_valid_registry_timestamp( $version->{published_at} ) );
        }
    }

    return;
}

sub validate_registry_artifact_path {
    my ($plugpath) = @_;

    return ( undef, "Invalid registry.json: version artifact is required." )            unless ( defined $plugpath && $plugpath ne "" );
    return ( undef, "Invalid registry.json: artifact path contains a null byte." )      if ( index( $plugpath, "\0" ) >= 0 );
    return ( undef, "Invalid registry.json: artifact path must be relative." )          if ( Mojo::File->new($plugpath)->is_abs );
    return ( undef, "Invalid registry.json: artifact path" .
        " must not contain '.' or '..' segments." )                                     if ( grep { $_ eq "." || $_ eq ".." } @{ Mojo::File->new($plugpath)->to_array } );

    return ( 1, undef );
}

# Resolve local registry root (the directory), including through any symlinks.
# abs_path is used for symlink canonicalization.
sub resolve_local_registry_artifact_path {
    my ( $registry_root, $plugpath ) = @_;

    my $resolved_registry_root = abs_path($registry_root);
    return ( undef, "Invalid local registry path: $registry_root" )                     unless ( $resolved_registry_root && -d $resolved_registry_root );

    my $candidate = Mojo::File->new($resolved_registry_root)->child( @{ Mojo::File->new($plugpath)->to_array } )->to_string;
    return ( undef, "Plugin file not found: $candidate" )                               unless ( -e $candidate );

    my $resolved_artifact = abs_path($candidate);
    return ( undef, "Failed to resolve plugin artifact path: $plugpath" )               unless ( $resolved_artifact );

    my $root_prefix = $resolved_registry_root =~ m{/\z} ? $resolved_registry_root : "$resolved_registry_root/";
    return ( undef, "Plugin artifact path escapes registry root: $plugpath" )           unless ( index( $resolved_artifact, $root_prefix ) == 0 );

    return ( $resolved_artifact, undef );
}

# Check timestamp is (stylistically) of the form "9999-99-99T99:99:99Z".
sub is_valid_registry_timestamp {
    my ($timestamp) = @_;
    return $timestamp =~ /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/;
}

# Return the SemVer-greatest version key from a plugin record's versions map.
# $plugin_record: the plugin record hashref (must have a non-empty 'versions' map).
# Pure function, no Redis.
sub resolve_max_version {
    my ($plugin_record) = @_;

    my @keys = keys %{ $plugin_record->{versions} };
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
