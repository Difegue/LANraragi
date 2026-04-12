package LANraragi::Utils::Registry;

use strict;
use warnings;
use utf8;

use Cwd qw(getcwd);
use File::Find;
use File::Spec;
use Mojo::Util qw(url_escape);

use LANraragi::Utils::Path qw(open_path find_path);

use Exporter 'import';
our @EXPORT_OK = qw(resolve_git_raw_url find_package_conflict find_namespace_conflict MANAGED_TYPE_DIRS);

# TODO(REVIEW) Utils/Model-level subs should not have fallbacks. Move fallbacks to Controller.

# TODO(REVIEW) this also applies to builtin plugins?
# Maps plugin_info type values to directory names under Plugin/Managed/.
use constant MANAGED_TYPE_DIRS => {
    metadata => "Metadata",
    download => "Download",
    login    => "Login",
    script   => "Scripts",
};

# Resolve a git URL to a raw file URL for a given provider.
sub resolve_git_raw_url {
    my ( $provider, $url, $ref, $path ) = @_;

    # TODO(REVIEW) is ref/path not guaranteed?
    $ref  //= "main";
    $path //= "registry.json";

    # Extract host, owner, repo from HTTPS URL
    my ( $host, $owner, $repo );
    if ( $url =~ m{^https?://([^/]+)/([^/]+)/([^/]+?)(?:\.git)?$} ) {
        ( $host, $owner, $repo ) = ( $1, $2, $3 );
    } else {
        # TODO(REVIEW) log error
        return;
    }

    if ( $provider eq "github" ) {
        return "https://raw.githubusercontent.com/$owner/$repo/$ref/$path";
    } elsif ( $provider eq "gitlab" ) {
        return "https://$host/$owner/$repo/-/raw/$ref/$path";
    } elsif ( $provider eq "gitea" ) {
        return "https://$host/api/v1/repos/$owner/$repo/raw/$path?ref=" . url_escape($ref);
    }

    # TODO(REVIEW) log error
    return;
}

# TODO(REVIEW) is skip_path shape guaranteed (abs/relative) if not undef?
# Scan Plugin/ directory for a .pm file declaring the given package name.
# Returns the conflicting filepath, or undef if no conflict.
# $skip_path: optional filepath to exclude (used for upgrades).
sub find_package_conflict {
    my ( $package_name, $skip_path ) = @_;

    my $plugin_dir = File::Spec->catdir( getcwd(), "lib", "LANraragi", "Plugin" );
    my $conflict;

    return unless -d $plugin_dir; # TODO(REVIEW) is this line necessary?

    # TODO(REVIEW) find_path argument is too large.
    find_path(
        sub {
            return if $conflict; # TODO(REVIEW) is this line necessary?
            return unless /\.pm$/; # TODO(REVIEW) readability

            my $filepath = $File::Find::name; # TODO(REVIEW) readability
            return if $skip_path && $filepath eq $skip_path;

            open_path( my $fh, '<', $filepath ) or return;
            while ( my $line = <$fh> ) {
                if ( $line =~ /^package\s+\Q$package_name\E\s*;/ ) {
                    $conflict = $filepath;
                    last;
                }
            }
            close $fh;
        },
        $plugin_dir
    );

    return $conflict;
}

# Scan Plugin/ directory for a .pm file declaring the given namespace.
# Returns the conflicting filepath, or undef if no conflict.
# $skip_path: optional filepath to exclude (used for upgrades).
sub find_namespace_conflict {
    my ( $namespace, $skip_path ) = @_;

    my $plugin_dir = File::Spec->catdir( getcwd(), "lib", "LANraragi", "Plugin" );
    my $conflict;

    return unless -d $plugin_dir;

    # TODO(REVIEW) find_path argument is too large.
    # TODO(REVIEW) should be refactored, has inner duplicates.
    # Or find_package_conflict/namespace_conflict merged and namespace/package flags.
    find_path(
        sub {
            return if $conflict;
            return unless /\.pm$/;

            my $filepath = $File::Find::name;
            return if $skip_path && $filepath eq $skip_path;

            open_path( my $fh, '<', $filepath ) or return;
            my $content = do { local $/; <$fh> };
            close $fh;

            if ( $content =~ /namespace\s*=>\s*['"]\Q$namespace\E['"]/ ) {
                $conflict = $filepath;
            }
        },
        $plugin_dir
    );

    return $conflict;
}

1;
