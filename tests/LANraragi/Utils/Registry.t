use strict;
use warnings;
use utf8;

use Cwd qw(abs_path getcwd);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use Test::More;

my $cwd = getcwd();
require "$cwd/tests/mocks.pl";
setup_redis_mock();

BEGIN { use_ok('LANraragi::Utils::Registry'); }

sub make_valid_index {
    return {
        version      => 1,
        generated_at => "2026-03-23T00:00:00Z",
        plugins      => {
            "sample-downloader" => {
                namespace => "sample-downloader",
                type      => "download",
                versions  => {
                    "1.0.0" => {
                        version      => "1.0.0",
                        name         => "Sample Downloader",
                        author       => "koyomi",
                        description  => "Downloads a sample archive.",
                        artifact     => "artifacts/sample-downloader/1.0.0/SampleDownload.pm",
                        sha256       => "a" x 64,
                        published_at => "2026-03-20T00:00:00Z",
                    },
                },
            },
        },
    };
}

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

{
    my $result = LANraragi::Utils::Registry::resolve_git_raw_url(
        "github", "http://github.com/owner/repo.git", "main", "registry.json"
    );
    is( $result, "https://raw.githubusercontent.com/owner/repo/main/registry.json", "github http url produces https raw url" );
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

{
    my $result = LANraragi::Utils::Registry::resolve_git_raw_url(
        "gitlab", "https://gitlab.com/group/subgroup/repo.git", "main", "registry.json"
    );
    is( $result, "https://gitlab.com/group/subgroup/repo/-/raw/main/registry.json", "gitlab nested subgroup" );
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

note('testing resolve_git_raw_url escapes path segments...');

{
    my $result = LANraragi::Utils::Registry::resolve_git_raw_url(
        "github", "https://github.com/owner/repo.git", "main", "Plugin/Foo Bar.pm"
    );
    is( $result, "https://raw.githubusercontent.com/owner/repo/main/Plugin/Foo%20Bar.pm", "github path with space is percent-encoded per segment" );
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

note('testing is_valid_registry_timestamp accepts spec format...');

{
    my $result = LANraragi::Utils::Registry::is_valid_registry_timestamp("2026-03-23T00:00:00Z");
    is( $result, 1, "spec example timestamp accepted" );
}

{
    my $result = LANraragi::Utils::Registry::is_valid_registry_timestamp("2026-12-31T23:59:59Z");
    is( $result, 1, "end-of-year timestamp accepted" );
}

note('testing is_valid_registry_timestamp rejects non-spec formats...');

{
    my $result = LANraragi::Utils::Registry::is_valid_registry_timestamp("2026-03-23T00:00:00");
    is( $result, "", "missing trailing Z is rejected" );
}

{
    my $result = LANraragi::Utils::Registry::is_valid_registry_timestamp("2026-03-23T00:00:00z");
    is( $result, "", "lowercase z is rejected" );
}

{
    my $result = LANraragi::Utils::Registry::is_valid_registry_timestamp("2026-03-23T00:00:00+00:00");
    is( $result, "", "explicit zero offset is rejected" );
}

{
    my $result = LANraragi::Utils::Registry::is_valid_registry_timestamp("2026-03-23T00:00:00.000Z");
    is( $result, "", "fractional seconds are rejected" );
}

{
    my $result = LANraragi::Utils::Registry::is_valid_registry_timestamp("2026-03-23 00:00:00Z");
    is( $result, "", "space separator is rejected" );
}

{
    my $result = LANraragi::Utils::Registry::is_valid_registry_timestamp("");
    is( $result, "", "empty string is rejected" );
}

note('testing validate_registry_artifact_path accepts valid relative paths...');

{
    my ( $ok, $err ) = LANraragi::Utils::Registry::validate_registry_artifact_path("artifacts/foo/1.0.0/Foo.pm");
    is( $ok,  1,     "nested relative path accepted (ok)" );
    is( $err, undef, "nested relative path accepted (no error)" );
}

{
    my ( $ok, $err ) = LANraragi::Utils::Registry::validate_registry_artifact_path("Foo.pm");
    is( $ok,  1,     "single-segment relative path accepted (ok)" );
    is( $err, undef, "single-segment relative path accepted (no error)" );
}

note('testing validate_registry_artifact_path rejects each violation...');

{
    my ( $ok, $err ) = LANraragi::Utils::Registry::validate_registry_artifact_path(undef);
    is( $ok,  undef, "undef rejected (ok)" );
    is( $err, "Invalid registry.json: version artifact is required.", "undef rejected (error)" );
}

{
    my ( $ok, $err ) = LANraragi::Utils::Registry::validate_registry_artifact_path("");
    is( $ok,  undef, "empty string rejected (ok)" );
    is( $err, "Invalid registry.json: version artifact is required.", "empty string rejected (error)" );
}

{
    my ( $ok, $err ) = LANraragi::Utils::Registry::validate_registry_artifact_path("foo\0bar.pm");
    is( $ok,  undef, "embedded null byte rejected (ok)" );
    is( $err, "Invalid registry.json: artifact path contains a null byte.", "embedded null byte rejected (error)" );
}

{
    my ( $ok, $err ) = LANraragi::Utils::Registry::validate_registry_artifact_path("/etc/passwd");
    is( $ok,  undef, "absolute path rejected (ok)" );
    is( $err, "Invalid registry.json: artifact path must be relative.", "absolute path rejected (error)" );
}

{
    my ( $ok, $err ) = LANraragi::Utils::Registry::validate_registry_artifact_path("artifacts/../etc/passwd");
    is( $ok,  undef, ".. segment rejected (ok)" );
    is( $err, "Invalid registry.json: artifact path must not contain '.' or '..' segments.", ".. segment rejected (error)" );
}

{
    my ( $ok, $err ) = LANraragi::Utils::Registry::validate_registry_artifact_path("./Foo.pm");
    is( $ok,  undef, ". segment rejected (ok)" );
    is( $err, "Invalid registry.json: artifact path must not contain '.' or '..' segments.", ". segment rejected (error)" );
}

note('testing resolve_local_registry_artifact_path accepts valid containment...');

{
    my $root = tempdir( CLEANUP => 1 );
    make_path("$root/artifacts/foo");
    open( my $fh, '>', "$root/artifacts/foo/Foo.pm" ) or die $!;
    close $fh;

    my ( $root_canon, $file_canon, $err ) =
        LANraragi::Utils::Registry::resolve_local_registry_artifact_path( $root, "artifacts/foo/Foo.pm" );
    is( $err,        undef,                                       "valid containment (no error)" );
    is( $file_canon, abs_path("$root/artifacts/foo/Foo.pm"),      "valid containment (file_canon matches)" );
    is( $root_canon, abs_path($root),                             "valid containment (root_canon matches)" );
}

note('testing resolve_local_registry_artifact_path rejects each violation...');

{
    my ( $root_canon, $file_canon, $err ) =
        LANraragi::Utils::Registry::resolve_local_registry_artifact_path( "/nonexistent/path/that/does/not/exist", "Foo.pm" );
    is( $root_canon, undef, "non-existent root (root_canon undef)" );
    is( $file_canon, undef, "non-existent root (file_canon undef)" );
    is( $err, "Invalid local registry path: /nonexistent/path/that/does/not/exist", "non-existent root (error)" );
}

{
    my $root = tempdir( CLEANUP => 1 );
    my ( $root_canon, $file_canon, $err ) =
        LANraragi::Utils::Registry::resolve_local_registry_artifact_path( $root, "missing.pm" );
    is( $file_canon, undef, "missing artifact (file_canon undef)" );
    is( $err, "Plugin file not found: " . abs_path($root) . "/missing.pm", "missing artifact (error)" );
}

SKIP: {
    skip "symlink not supported on this platform", 4 unless eval { symlink( "", "" ); 1 };

    {
        my $root   = tempdir( CLEANUP => 1 );
        my $escape = tempdir( CLEANUP => 1 );
        open( my $fh, '>', "$escape/Outside.pm" ) or die $!;
        close $fh;
        symlink( "$escape/Outside.pm", "$root/Escape.pm" ) or die $!;

        my ( $root_canon, $file_canon, $err ) =
            LANraragi::Utils::Registry::resolve_local_registry_artifact_path( $root, "Escape.pm" );
        is( $file_canon, undef, "symlink escaping root (file_canon undef)" );
        is( $err, "Invalid plugin artifact path: Escape.pm", "symlink escaping root (error)" );
    }

    {
        my $root = tempdir( CLEANUP => 1 );
        make_path("$root/artifacts/foo");
        open( my $fh, '>', "$root/artifacts/foo/Foo.pm" ) or die $!;
        close $fh;
        symlink( "$root/artifacts/foo/Foo.pm", "$root/Inside.pm" ) or die $!;

        my ( $root_canon, $file_canon, $err ) =
            LANraragi::Utils::Registry::resolve_local_registry_artifact_path( $root, "Inside.pm" );
        is( $err,        undef,                                       "symlink staying inside root (no error)" );
        is( $file_canon, abs_path("$root/artifacts/foo/Foo.pm"),      "symlink staying inside root (file_canon resolves to target)" );
    }
}

note('testing validate_registry_index accepts a valid index...');

{
    my $err = LANraragi::Utils::Registry::validate_registry_index( make_valid_index() );
    is( $err, undef, "valid index returns undef" );
}

{
    my $idx = make_valid_index();
    $idx->{plugins} = {};
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is( $err, undef, "empty plugins hash accepted" );
}

note('testing validate_registry_index rejects root-level violations...');

{
    my $err = LANraragi::Utils::Registry::validate_registry_index("not a hash");
    is( $err, "Invalid registry.json: root must be an object.", "non-hash root rejected" );
}

{
    my $idx = make_valid_index();
    $idx->{unknown_field} = 1;
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is( $err, "Invalid registry.json: unknown root field 'unknown_field'.", "unknown root field rejected" );
}

{
    my $idx = make_valid_index();
    $idx->{version} = 2;
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is( $err, "Invalid registry.json: registry version must be 1.", "version != 1 rejected" );
}

{
    my $idx = make_valid_index();
    delete $idx->{version};
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is( $err, "Invalid registry.json: registry version must be 1.", "missing version rejected" );
}

{
    my $idx = make_valid_index();
    $idx->{generated_at} = "";
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is( $err, "Invalid registry.json: 'generated_at' is required.", "empty generated_at rejected" );
}

{
    my $idx = make_valid_index();
    $idx->{generated_at} = "2026-03-23";
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is( $err, "Invalid registry.json: 'generated_at' must be a UTC RFC3339 timestamp.", "malformed generated_at rejected" );
}

{
    my $idx = make_valid_index();
    $idx->{plugins} = [];
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is( $err, "Invalid registry.json: 'plugins' must be an object.", "non-hash plugins rejected" );
}

note('testing validate_registry_index rejects plugin-level violations...');

{
    my $idx = make_valid_index();
    $idx->{plugins}{"sample-downloader"} = "not a hash";
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is( $err, "Invalid registry.json: plugin 'sample-downloader' must be an object.", "non-hash plugin rejected" );
}

{
    my $idx = make_valid_index();
    $idx->{plugins}{"sample-downloader"}{unknown_field} = 1;
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is( $err, "Invalid registry.json: plugin 'sample-downloader' has unknown field 'unknown_field'.", "unknown plugin field rejected" );
}

{
    my $idx = make_valid_index();
    $idx->{plugins}{"sample-downloader"}{channels} = { latest => "1.0.0" };
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is( $err, "Invalid registry.json: plugin 'sample-downloader' has unknown field 'channels'.", "channels field rejected as unknown" );
}

{
    my $idx = make_valid_index();
    $idx->{plugins}{"sample-downloader"}{namespace} = "different-name";
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is( $err, "Invalid registry.json: plugin key 'sample-downloader' must match inner namespace.", "key/inner namespace mismatch rejected" );
}

{
    my $idx = make_valid_index();
    $idx->{plugins}{"SampleDownloader"} = delete $idx->{plugins}{"sample-downloader"};
    $idx->{plugins}{"SampleDownloader"}{namespace} = "SampleDownloader";
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is( $err, "Invalid registry.json: plugin namespace 'SampleDownloader' must match ^[a-z0-9_-]+\$ (lowercase only).", "mixed-case namespace rejected" );
}

{
    my $idx = make_valid_index();
    $idx->{plugins}{"SAMPLE-DOWNLOADER"} = delete $idx->{plugins}{"sample-downloader"};
    $idx->{plugins}{"SAMPLE-DOWNLOADER"}{namespace} = "SAMPLE-DOWNLOADER";
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is( $err, "Invalid registry.json: plugin namespace 'SAMPLE-DOWNLOADER' must match ^[a-z0-9_-]+\$ (lowercase only).", "uppercase namespace rejected" );
}

{
    my $idx = make_valid_index();
    $idx->{plugins}{"sample-downloader"}{type} = "spreadsheet";
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is( $err, "Invalid registry.json: plugin 'sample-downloader' has invalid type 'spreadsheet'.", "invalid type rejected" );
}

{
    my $idx = make_valid_index();
    $idx->{plugins}{"sample-downloader"}{versions} = {};
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is( $err, "Invalid registry.json: plugin 'sample-downloader' 'versions' must be a non-empty object.", "empty versions rejected" );
}

note('testing validate_registry_index rejects non-SemVer version keys...');

{
    my $idx = make_valid_index();
    $idx->{plugins}{"sample-downloader"}{versions}{"1.0"} = {
        version      => "1.0",
        name         => "Sample Downloader",
        author       => "koyomi",
        description  => "Downloads a sample archive.",
        artifact     => "artifacts/sample-downloader/1.0/SampleDownload.pm",
        sha256       => "a" x 64,
        published_at => "2026-03-20T00:00:00Z",
    };
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is(
        $err,
        "Invalid registry.json: plugin 'sample-downloader' version key '1.0' is not a valid SemVer 2.0.0 string.",
        "short dotted version key rejected"
    );
}

{
    my $idx = make_valid_index();
    $idx->{plugins}{"sample-downloader"}{versions}{"not-a-version"} = {
        version      => "not-a-version",
        name         => "Sample Downloader",
        author       => "koyomi",
        description  => "Downloads a sample archive.",
        artifact     => "artifacts/sample-downloader/not-a-version/SampleDownload.pm",
        sha256       => "a" x 64,
        published_at => "2026-03-20T00:00:00Z",
    };
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is(
        $err,
        "Invalid registry.json: plugin 'sample-downloader' version key 'not-a-version' is not a valid SemVer 2.0.0 string.",
        "non-semver string version key rejected"
    );
}

{
    my $idx = make_valid_index();
    $idx->{plugins}{"sample-downloader"}{versions}{"v1.0.0"} = {
        version      => "v1.0.0",
        name         => "Sample Downloader",
        author       => "koyomi",
        description  => "Downloads a sample archive.",
        artifact     => "artifacts/sample-downloader/v1.0.0/SampleDownload.pm",
        sha256       => "a" x 64,
        published_at => "2026-03-20T00:00:00Z",
    };
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is(
        $err,
        "Invalid registry.json: plugin 'sample-downloader' version key 'v1.0.0' is not a valid SemVer 2.0.0 string.",
        "v-prefixed version key rejected"
    );
}

note('testing validate_registry_index accepts valid SemVer version keys...');

{
    my $idx = make_valid_index();
    $idx->{plugins}{"sample-downloader"}{versions}{"2.0.0"} = {
        version      => "2.0.0",
        name         => "Sample Downloader",
        author       => "koyomi",
        description  => "Downloads a sample archive.",
        artifact     => "artifacts/sample-downloader/2.0.0/SampleDownload.pm",
        sha256       => "b" x 64,
        published_at => "2026-03-23T00:00:00Z",
    };
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is( $err, undef, "multiple valid SemVer version keys accepted" );
}

{
    my $idx = make_valid_index();
    $idx->{plugins}{"sample-downloader"}{versions}{"1.0.0-alpha.1"} = {
        version      => "1.0.0-alpha.1",
        name         => "Sample Downloader",
        author       => "koyomi",
        description  => "Downloads a sample archive.",
        artifact     => "artifacts/sample-downloader/1.0.0-alpha.1/SampleDownload.pm",
        sha256       => "c" x 64,
        published_at => "2026-03-19T00:00:00Z",
    };
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is( $err, undef, "SemVer prerelease version key accepted" );
}

note('testing validate_registry_index rejects version-level violations...');

{
    my $idx = make_valid_index();
    $idx->{plugins}{"sample-downloader"}{versions}{"1.0.0"} = "not a hash";
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is( $err, "Invalid registry.json: plugin 'sample-downloader' version '1.0.0' must be an object.", "non-hash version rejected" );
}

{
    my $idx = make_valid_index();
    $idx->{plugins}{"sample-downloader"}{versions}{"1.0.0"}{unknown_field} = 1;
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is( $err, "Invalid registry.json: plugin 'sample-downloader' version '1.0.0' has unknown field 'unknown_field'.", "unknown version field rejected" );
}

{
    my $idx = make_valid_index();
    $idx->{plugins}{"sample-downloader"}{versions}{"1.0.0"}{version} = "9.9.9";
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is( $err, "Invalid registry.json: plugin 'sample-downloader' version key '1.0.0' must match inner version.", "key/inner version mismatch rejected" );
}

foreach my $field (qw(name author description artifact sha256 published_at)) {
    my $idx = make_valid_index();
    $idx->{plugins}{"sample-downloader"}{versions}{"1.0.0"}{$field} = "";
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is(
        $err,
        "Invalid registry.json: plugin 'sample-downloader' version '1.0.0' is missing '$field'.",
        "empty required field '$field' rejected"
    );
}

{
    my $idx = make_valid_index();
    $idx->{plugins}{"sample-downloader"}{versions}{"1.0.0"}{artifact} = "/etc/passwd";
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is( $err, "Invalid registry.json: artifact path must be relative.", "non-empty invalid artifact delegates to validate_registry_artifact_path" );
}

{
    my $idx = make_valid_index();
    $idx->{plugins}{"sample-downloader"}{versions}{"1.0.0"}{sha256} = "z" x 64;
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is( $err, "Invalid registry.json: plugin 'sample-downloader' version '1.0.0' sha256 must be 64 lowercase hexadecimal characters.", "non-hex sha256 rejected" );
}

{
    my $idx = make_valid_index();
    $idx->{plugins}{"sample-downloader"}{versions}{"1.0.0"}{sha256} = "a" x 63;
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is( $err, "Invalid registry.json: plugin 'sample-downloader' version '1.0.0' sha256 must be 64 lowercase hexadecimal characters.", "63-char sha256 rejected" );
}

{
    my $idx = make_valid_index();
    $idx->{plugins}{"sample-downloader"}{versions}{"1.0.0"}{published_at} = "yesterday";
    my $err = LANraragi::Utils::Registry::validate_registry_index($idx);
    is( $err, "Invalid registry.json: plugin 'sample-downloader' version '1.0.0' published_at must be a UTC RFC3339 timestamp.", "malformed published_at rejected" );
}

note('testing resolve_max_version returns SemVer-greatest key...');

{
    my $plugin_root = {
        versions => {
            "1.0.0" => {},
            "1.1.0" => {},
            "2.0.0" => {},
        },
    };
    my $max = LANraragi::Utils::Registry::resolve_max_version($plugin_root);
    is( $max, "2.0.0", "greatest version among three is selected" );
}

{
    my $plugin_root = {
        versions => {
            "1.0.0" => {},
        },
    };
    my $max = LANraragi::Utils::Registry::resolve_max_version($plugin_root);
    is( $max, "1.0.0", "single version is returned as max" );
}

{
    my $plugin_root = {
        versions => {
            "1.0.0"       => {},
            "1.0.0-alpha" => {},
        },
    };
    my $max = LANraragi::Utils::Registry::resolve_max_version($plugin_root);
    is( $max, "1.0.0", "release version is greater than prerelease by SemVer" );
}

{
    my $plugin_root = {
        versions => {
            "1.9.0"  => {},
            "1.10.0" => {},
        },
    };
    my $max = LANraragi::Utils::Registry::resolve_max_version($plugin_root);
    is( $max, "1.10.0", "SemVer comparator correctly orders 1.10.0 > 1.9.0" );
}

note('testing find_package_conflict...');

{
    my $result = LANraragi::Utils::Registry::find_package_conflict("LANraragi::Plugin::Metadata::Chaika");
    is( $result, "$cwd/lib/LANraragi/Plugin/Metadata/Chaika.pm", "existing package detected" );
}

{
    my $skip   = "$cwd/lib/LANraragi/Plugin/Metadata/Chaika.pm";
    my $result = LANraragi::Utils::Registry::find_package_conflict( "LANraragi::Plugin::Metadata::Chaika", $skip );
    is( $result, undef, "skip_path excludes own file" );
}

{
    my $result = LANraragi::Utils::Registry::find_package_conflict("LANraragi::Plugin::Nonexistent::Synthetic");
    is( $result, undef, "non-existent package returns undef" );
}

note('testing find_namespace_conflict...');

{
    my $result = LANraragi::Utils::Registry::find_namespace_conflict("trabant");
    is( $result, "$cwd/lib/LANraragi/Plugin/Metadata/Chaika.pm", "existing namespace detected" );
}

{
    my $result = LANraragi::Utils::Registry::find_namespace_conflict("TRABANT");
    is( $result, "$cwd/lib/LANraragi/Plugin/Metadata/Chaika.pm", "namespace match is case-insensitive" );
}

{
    my $skip   = "$cwd/lib/LANraragi/Plugin/Metadata/Chaika.pm";
    my $result = LANraragi::Utils::Registry::find_namespace_conflict( "trabant", $skip );
    is( $result, undef, "skip_path excludes own file" );
}

{
    my $result = LANraragi::Utils::Registry::find_namespace_conflict("definitely-not-a-real-namespace");
    is( $result, undef, "non-existent namespace returns undef" );
}

done_testing();
