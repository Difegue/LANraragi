package LANraragi::Utils::Registry;

use strict;
use warnings;
use utf8;

use Cwd qw(getcwd);
use File::Find;
use Mojo::Util qw(url_escape);

use Exporter 'import';
our @EXPORT_OK = qw(resolve_git_raw_url find_package_conflict find_namespace_conflict MANAGED_TYPE_DIRS);

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

    $ref  //= "main";
    $path //= "registry.json";

    # Extract host, owner, repo from HTTPS URL
    my ( $host, $owner, $repo );
    if ( $url =~ m{^https?://([^/]+)/([^/]+)/([^/]+?)(?:\.git)?$} ) {
        ( $host, $owner, $repo ) = ( $1, $2, $3 );
    } else {
        return;
    }

    if ( $provider eq "github" ) {
        return "https://raw.githubusercontent.com/$owner/$repo/$ref/$path";
    } elsif ( $provider eq "gitlab" ) {
        return "https://$host/$owner/$repo/-/raw/$ref/$path";
    } elsif ( $provider eq "gitea" ) {
        return "https://$host/api/v1/repos/$owner/$repo/raw/$path?ref=" . url_escape($ref);
    }

    return;
}

# Scan Plugin/ directory for a .pm file declaring the given package name.
# Returns the conflicting filepath, or undef if no conflict.
# $skip_path: optional filepath to exclude (used for upgrades).
sub find_package_conflict {
    my ( $package_name, $skip_path ) = @_;

    my $plugin_dir = getcwd() . "/lib/LANraragi/Plugin";
    my $conflict;

    return unless -d $plugin_dir;

    find(
        {
            no_chdir => 1,
            wanted   => sub {
                return if $conflict;
                return unless /\.pm$/;

                my $filepath = $File::Find::name;
                return if $skip_path && $filepath eq $skip_path;

                open( my $fh, '<', $filepath ) or return;
                while ( my $line = <$fh> ) {
                    if ( $line =~ /^package\s+\Q$package_name\E\s*;/ ) {
                        $conflict = $filepath;
                        last;
                    }
                }
                close $fh;
            },
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

    my $plugin_dir = getcwd() . "/lib/LANraragi/Plugin";
    my $conflict;

    return unless -d $plugin_dir;

    find(
        {
            no_chdir => 1,
            wanted   => sub {
                return if $conflict;
                return unless /\.pm$/;

                my $filepath = $File::Find::name;
                return if $skip_path && $filepath eq $skip_path;

                open( my $fh, '<', $filepath ) or return;
                my $content = do { local $/; <$fh> };
                close $fh;

                if ( $content =~ /namespace\s*=>\s*['"]\Q$namespace\E['"]/ ) {
                    $conflict = $filepath;
                }
            },
        },
        $plugin_dir
    );

    return $conflict;
}

1;
