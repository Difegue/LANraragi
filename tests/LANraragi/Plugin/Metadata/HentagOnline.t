# LANraragi::Plugin::Metadata::HentagOnline
use strict;
use warnings;
use utf8;
use feature qw(signatures);

use Cwd qw( getcwd );

use Test::Trap;
use Test::More;
use Test::Deep;

my $cwd = getcwd();
my $SAMPLES = "$cwd/tests/samples";
require "$cwd/tests/mocks.pl";

use_ok('LANraragi::Plugin::Metadata::HentagOnline');

note("00 - api response");
{
    my $archive_title = "Boin Tantei vs Kaitou Sanmensou";
    my $received_title;
    my $mock_json = Mojo::File->new("$SAMPLES/hentag/02_search_response.json")->slurp;

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::HentagOnline::get_plugin_logger = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::HentagOnline::get_json_by_title = sub {
        my ( $ua, $our_archive_title ) = @_;
        $received_title = $our_archive_title;
        return $mock_json;
    };

    my %get_tags_params = ( archive_title => $archive_title);

    my %response = LANraragi::Plugin::Metadata::HentagOnline::get_tags( "", \%get_tags_params, 1 );

    my $expected_title = "[Doi Sakazaki] Boin Tantei vs Kaitou Sanmensou [ENG]";
    my $expected_tags =
      "artist:doi sakazaki, female:big breasts, female:maid, female:paizuri, language:english, source:https://hentag.com/vault/QNWPNY5lxYtqOxDN7OgqsyqW0pZDNwf3REXoLyb4iWpkR8n5qrfm3Bw";
    is( $received_title, $archive_title, "sent correct title to get_json_from_api");
    is( $response{title}, $expected_title, "correct title" );
    is( $response{tags},  $expected_tags, "correct tags" );
}

note("01 - vault url parsing");
{
    my $url_nowww = "https://hentag.com/vault/QNWPNY5lxYtqOxDN7OgqsyqW0pZDNwf3REXoLyb4iWpkR8n5qrfm3Bw";
    my $url_www = "https://www.hentag.com/vault/QNWPNY5lxYtqOxDN7OgqsyqW0pZDNwf3REXoLyb4iWpkR8n5qrfm3Bw";
    my $expected_id = "QNWPNY5lxYtqOxDN7OgqsyqW0pZDNwf3REXoLyb4iWpkR8n5qrfm3Bw";

    is(LANraragi::Plugin::Metadata::HentagOnline::parse_vault_url($url_nowww), $expected_id, "got correct id, without www");
    is(LANraragi::Plugin::Metadata::HentagOnline::parse_vault_url($url_www), $expected_id, "got correct id, with www");
    is(LANraragi::Plugin::Metadata::HentagOnline::parse_vault_url(''), undef, "empty URL returns nothing");
}

note("02 - multilaguage hit");
{
    my $archive_title = "Whatever";
    my $received_title;
    my $mock_json = Mojo::File->new("$SAMPLES/hentag/03_search_response_multiple.json")->slurp;

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::HentagOnline::get_plugin_logger = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::HentagOnline::get_json_by_title = sub {
        my ( $ua, $our_archive_title ) = @_;
        $received_title = $our_archive_title;
        return $mock_json;
    };

    my %get_tags_params = ( archive_title => $archive_title);

    my %response = LANraragi::Plugin::Metadata::HentagOnline::get_tags( "", \%get_tags_params, 1 );

    my $expected_title = "Do match this title";
    my $expected_tags =
        "artist:the artist, female:penis, language:english, source:https://hentag.com/vault/QNWPNY5lxYtqOxDN7OgqsyqW0pZDNwf3REXoLyb4iWpkR8n5qrfm3Bw";
    is( $received_title, $archive_title, "sent correct title to get_json_from_api");
    is( $response{title}, $expected_title, "correct title" );
    is( $response{tags},  $expected_tags, "correct tags" );
}

note("03 - source tag parsing");
{
    my $expected_source = "https://hentag.com/vault/QNWPNY5lxYtqOxDN7OgqsyqW0pZDNwf3REXoLyb4iWpkR8n5qrfm3Bw";
    my @split_tags = split(",", "artist:the artist, female:penis, language:english, source:$expected_source");
    my $received_source = LANraragi::Plugin::Metadata::HentagOnline::get_existing_hentag_source_url( @split_tags );
    is( $received_source, $expected_source, "got correct url");
}

note("04 - other source tag parsing");
{
    my $wrong = "https://example.com/vault/QNWPNY5lxYtqOxDN7OgqsyqW0pZDNwf3REXoLyb4iWpkR8n5qrfm3Bw";
    my @split_tags = split(",", "artist:the artist, female:penis, language:english, source:$wrong");
    my $received_source = LANraragi::Plugin::Metadata::HentagOnline::get_existing_hentag_source_url( @split_tags );
    is( $received_source, undef, "don't detect false positive");
}

note("05 - hentag source tag usage");
{
    my $archive_title = "The adventures of irrelevant title";
    my $expected_id = "QNWPNY5lxYtqOxDN7OgqsyqW0pZDNwf3REXoLyb4iWpkR8n5qrfm3Bw";
    my $mock_json = Mojo::File->new("$SAMPLES/hentag/02_search_response.json")->slurp;
    my $received_id;

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::HentagOnline::get_plugin_logger = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::HentagOnline::get_json_by_title = sub {
        fail("get_json_by_title should not have been called");
        return;
    };
    local *LANraragi::Plugin::Metadata::HentagOnline::get_json_by_vault_id = sub($ua, $vault_id, $logger) {
        $received_id = $vault_id;
        return $mock_json;
    };

    my %get_tags_params = ( archive_title => $archive_title, existing_tags => "sometag, source:https://hentag.com/vault/$expected_id");

    my %response = LANraragi::Plugin::Metadata::HentagOnline::get_tags( "", \%get_tags_params, 1 );

    my $expected_title = "[Doi Sakazaki] Boin Tantei vs Kaitou Sanmensou [ENG]";
    my $expected_tags =
        "artist:doi sakazaki, female:big breasts, female:maid, female:paizuri, language:english, source:https://hentag.com/vault/$expected_id";
    is( $received_id, $expected_id, "sent correct id to get_json_by_vault_id");
    is( $response{title}, $expected_title, "correct title" );
    is( $response{tags},  $expected_tags, "correct tags" );
}


done_testing();
