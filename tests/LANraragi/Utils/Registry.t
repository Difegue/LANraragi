use strict;
use warnings;
use utf8;

use Cwd qw(getcwd);
use Test::More;

my $cwd = getcwd();
require "$cwd/tests/mocks.pl";
setup_redis_mock();

BEGIN { use_ok('LANraragi::Utils::Registry'); }

note('testing resolve_git_raw_url for github...');

{
    my $result = LANraragi::Utils::Registry::resolve_git_raw_url(
        "github", "https://github.com/owner/repo.git", "main", "registry.json"
    );
    is( $result, "https://raw.githubusercontent.com/owner/repo/main/registry.json", "github registry.json" );
}

{
    my $result = LANraragi::Utils::Registry::resolve_git_raw_url(
        "github", "https://github.com/owner/repo.git", "v2.0", "Plugin/Download/Foo.pm"
    );
    is( $result, "https://raw.githubusercontent.com/owner/repo/v2.0/Plugin/Download/Foo.pm", "github plugin path with tag ref" );
}

{
    my $result = LANraragi::Utils::Registry::resolve_git_raw_url(
        "github", "https://github.com/owner/repo", "main", "registry.json"
    );
    is( $result, "https://raw.githubusercontent.com/owner/repo/main/registry.json", "github without .git suffix" );
}

note('testing resolve_git_raw_url for gitlab...');

{
    my $result = LANraragi::Utils::Registry::resolve_git_raw_url(
        "gitlab", "https://gitlab.com/owner/repo.git", "main", "registry.json"
    );
    is( $result, "https://gitlab.com/owner/repo/-/raw/main/registry.json", "gitlab.com registry.json" );
}

{
    my $result = LANraragi::Utils::Registry::resolve_git_raw_url(
        "gitlab", "https://my-company.com/owner/repo.git", "dev", "Plugin/Meta/Bar.pm"
    );
    is( $result, "https://my-company.com/owner/repo/-/raw/dev/Plugin/Meta/Bar.pm", "gitlab self-hosted plugin path" );
}

note('testing resolve_git_raw_url for gitea...');

{
    my $result = LANraragi::Utils::Registry::resolve_git_raw_url(
        "gitea", "https://codeberg.org/owner/repo.git", "main", "registry.json"
    );
    is( $result, "https://codeberg.org/api/v1/repos/owner/repo/raw/registry.json?ref=main", "gitea codeberg registry.json" );
}

{
    my $result = LANraragi::Utils::Registry::resolve_git_raw_url(
        "gitea", "https://git.local/owner/repo", "v1.0", "Plugin/Scripts/Baz.pm"
    );
    is( $result, "https://git.local/api/v1/repos/owner/repo/raw/Plugin/Scripts/Baz.pm?ref=v1.0", "gitea self-hosted plugin path" );
}

note('testing resolve_git_raw_url enforces HTTPS for gitlab/gitea...');

{
    my $result = LANraragi::Utils::Registry::resolve_git_raw_url(
        "gitlab", "http://internal.host/owner/repo.git", "main", "registry.json"
    );
    is( $result, "https://internal.host/owner/repo/-/raw/main/registry.json", "gitlab http url upgraded to https" );
}

{
    my $result = LANraragi::Utils::Registry::resolve_git_raw_url(
        "gitea", "http://git.local/owner/repo", "main", "registry.json"
    );
    is( $result, "https://git.local/api/v1/repos/owner/repo/raw/registry.json?ref=main", "gitea http url upgraded to https" );
}

note('testing resolve_git_raw_url with all arguments...');

{
    my $result = LANraragi::Utils::Registry::resolve_git_raw_url( "github", "https://github.com/owner/repo.git", "main", "registry.json" );
    is( $result, "https://raw.githubusercontent.com/owner/repo/main/registry.json", "github with explicit ref and path" );
}

note('testing resolve_git_raw_url with invalid input...');

{
    my $result = LANraragi::Utils::Registry::resolve_git_raw_url( "github", "not-a-url", "main", "registry.json" );
    is( $result, undef, "malformed url returns undef" );
}

{
    my $result = LANraragi::Utils::Registry::resolve_git_raw_url( "unknown", "https://example.com/owner/repo.git", "main", "registry.json" );
    is( $result, undef, "unknown provider returns undef" );
}

done_testing();
