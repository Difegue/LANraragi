use strict;
use warnings;
use utf8;
use Cwd;

use Mojo::Base 'Mojolicious';

use Test::More;
use Test::MockObject;

# Mock Redis
my $cwd = getcwd;
require $cwd . "/tests/mocks.pl";
setup_redis_mock();

use LANraragi::Utils::String  qw(trim_url canonicalize_url);
use LANraragi::Utils::Plugins qw(get_downloader_for_url);
use LANraragi::Model::Config;
use LANraragi::Plugin::Scripts::SourceFinder;
use LANraragi::Plugin::Download::EHentai;

my $gid     = "12345678";
my $token   = "d3adb33f";
my $eh_g    = "https://e-hentai.org/g/$gid/$token/";
my $eh_mpv  = "https://e-hentai.org/mpv/$gid/$token/";
my $ex_g    = "https://exhentai.org/g/$gid/$token/";
my $ex_mpv  = "https://exhentai.org/mpv/$gid/$token/";
my $map_key = "e-hentai.org/g/$gid/$token";

note("canonicalize_url tests");

is( canonicalize_url($eh_mpv), "https://e-hentai.org/g/$gid/$token", 'e-hentai /mpv/ URL canonicalized' );
is( canonicalize_url($ex_mpv), "https://exhentai.org/g/$gid/$token", 'exhentai /mpv/ URL canonicalized' );

is( canonicalize_url($eh_g), $eh_g, 'e-hentai /g/ URL untouched' );
is( canonicalize_url($ex_g), $ex_g, 'exhentai /g/ URL untouched' );

is( canonicalize_url("https://e-hentai.org/mpv/$gid/$token/?p=1"),   "https://e-hentai.org/g/$gid/$token", 'query dropped' );
is( canonicalize_url("https://e-hentai.org/mpv/$gid/$token/#page1"), "https://e-hentai.org/g/$gid/$token", 'fragment dropped' );

is( canonicalize_url("e-hentai.org/mpv/$gid/$token"), "e-hentai.org/g/$gid/$token", 'scheme-less URL canonicalized' );

is( canonicalize_url("https://example.com/pathname?query=value#hash"),
    "https://example.com/pathname?query=value#hash",
    'non e-hentai URL untouched'
);

note("source tag / URL map key tests");

# Test each URL the download job could be sent for the same gallery
foreach my $url ( $eh_g, $eh_mpv, $ex_g, $ex_mpv ) {
    my $og_url = trim_url($url);
    $og_url = canonicalize_url($og_url);

    # Submissions from either domain end up on their own domain's map key
    like( $og_url, qr/^(e-hentai|exhentai)\.org\/g\/$gid\/$token$/, "source: tag is a canonical /g/ URL for $url" );
}

# Same-domain submissions all collapse to the exact same map key
my $eh_og = canonicalize_url( trim_url($eh_mpv) );
is( $eh_og, canonicalize_url( trim_url($eh_g) ), 'e-hentai /mpv/ and /g/ submissions share one source: tag' );

note("downloader plugin matching tests");

my $redis = LANraragi::Model::Config->get_redis;
$redis->hset( "LRR_PLUGIN_EHDL", "installed_path", "LANraragi/Plugin/Download/EHentai.pm" );

foreach my $url ( $eh_g, $eh_mpv, $ex_g, $ex_mpv ) {
    my $downloader = get_downloader_for_url($url);
    ok( defined $downloader, "downloader found for $url" );
    if ( defined $downloader ) {
        is( $downloader->{namespace}, "ehdl", "downloader is the EHentai plugin for $url" );
    }
}

note("source finder (urlfinder) tests");

# Simulate an archive whose source: tag is the canonical /g/ URL
my $archive_id = "0" x 40;
$redis->hset( "LRR_URLMAP", $map_key, $archive_id );

my %queries = (
    $eh_g   => 'e-hentai gallery page',
    $eh_mpv => 'e-hentai mpv page',
    $ex_g   => 'exhentai gallery page',
    $ex_mpv => 'exhentai mpv page'
);

foreach my $url ( sort keys %queries ) {
    my %res = LANraragi::Plugin::Scripts::SourceFinder::run_script( "", { oneshot_param => $url } );
    is( $res{id}, $archive_id, "urlfinder finds the archive from the $queries{$url}" );
}

done_testing();
