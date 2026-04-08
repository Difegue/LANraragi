package LANraragi::Utils::Registry;

use strict;
use warnings;
use utf8;

use Exporter 'import';
our @EXPORT_OK = qw(resolve_git_raw_url MANAGED_TYPE_DIRS);

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
        return "https://$host/api/v1/repos/$owner/$repo/raw/$path?ref=$ref";
    }

    return;
}

1;
