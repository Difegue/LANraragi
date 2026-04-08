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
# If $path is provided, resolves to that file; otherwise resolves to registry.json.
sub resolve_git_raw_url {
    my ( $provider, $url, $ref, $path ) = @_;

    $ref  //= "main";
    $path //= "registry.json";

    # Extract scheme, host, owner, repo from HTTPS URL
    my ( $scheme, $host, $owner, $repo );
    if ( $url =~ m{^(https?)://([^/]+)/([^/]+)/([^/]+?)(?:\.git)?$} ) {
        ( $scheme, $host, $owner, $repo ) = ( $1, $2, $3, $4 );
    } else {
        return;
    }

    if ( $provider eq "github" ) {
        return "https://raw.githubusercontent.com/$owner/$repo/$ref/$path";
    }

    if ( $provider eq "gitlab" ) {
        return "https://$host/$owner/$repo/-/raw/$ref/$path";
    }

    if ( $provider eq "gitea" ) {
        return "https://$host/api/v1/repos/$owner/$repo/raw/$path?ref=$ref";
    }

    return;
}

1;
