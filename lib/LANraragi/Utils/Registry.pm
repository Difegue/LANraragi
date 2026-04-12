package LANraragi::Utils::Registry;

use strict;
use warnings;
use utf8;

use Cwd qw(getcwd);
use File::Find;
use Mojo::Util qw(url_escape);

use Mojo::File;

use LANraragi::Utils::Path    qw(find_path);
use LANraragi::Utils::Logging qw(get_logger);

use Exporter 'import';
our @EXPORT_OK = qw(resolve_git_raw_url find_package_conflict find_namespace_conflict MANAGED_TYPE_DIRS);

# Maps plugin_info type values to directory names under Plugin/Managed/.
use constant MANAGED_TYPE_DIRS => {
    metadata => "Metadata",
    download => "Download",
    login    => "Login",
    script   => "Scripts",
};

# Resolve a git URL to a raw file URL for a given provider
# Supports github, gitlab, and gitea/codeberg providers.
sub resolve_git_raw_url {
    my ( $provider, $url, $ref, $path ) = @_;

    my $logger = get_logger( "Registry", "lanraragi" );

    my ( $host, $owner, $repo );
    if ( $url =~ m{^https?://([^/]+)/([^/]+)/([^/]+?)(?:\.git)?$} ) {
        ( $host, $owner, $repo ) = ( $1, $2, $3 );
    } else {
        $logger->error("Cannot parse git URL: $url");
        return;
    }

    if ( $provider eq "github" ) {
        return "https://raw.githubusercontent.com/$owner/$repo/$ref/$path";
    } elsif ( $provider eq "gitlab" ) {
        return "https://$host/$owner/$repo/-/raw/$ref/$path";
    } elsif ( $provider eq "gitea" ) {
        return "https://$host/api/v1/repos/$owner/$repo/raw/$path?ref=" . url_escape($ref);
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
            return $content =~ /namespace\s*=>\s*['"]\Q$namespace\E['"]/;
        }
    );
}


# Scan Plugin/ directory for a .pm file matching the given criteria.
# $skip_path: optional absolute filepath to exclude
# $match_fn: coderef($filepath, $fh) -> bool; return true if filepath conflicts.
sub _find_conflict {
    my ( $skip_path, $match_fn ) = @_;

    my $plugin_dir = getcwd() . "/lib/LANraragi/Plugin";
    my $conflict;

    return unless -d $plugin_dir;

    find_path(
        sub {
            return if $conflict;
            return unless /\.pm$/;

            my $filepath = $File::Find::name;
            return if $skip_path && $filepath eq $skip_path;

            if ( $match_fn->($filepath) ) {
                $conflict = $filepath;
            }
        },
        $plugin_dir
    );

    return $conflict;
}

1;
