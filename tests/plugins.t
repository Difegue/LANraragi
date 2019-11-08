use strict;
use warnings;
use utf8;
use Cwd;

use Mojo::Base 'Mojolicious';

use Test::More tests => 13;
use Test::Mojo;
use Test::MockObject;

use LANraragi::Plugin::EHentai;
use LANraragi::Plugin::nHentai;
use LANraragi::Plugin::Chaika;

# Mock Redis
my $cwd = getcwd;
require $cwd."/tests/mocks.pl";
setup_redis_mock();

# E-Hentai Tests
my ( $ua, $domain ) = LANraragi::Plugin::EHentai::get_user_agent("","","");
my $eH_gID    = "618395";
my $eH_gToken = "0439fa3666";

my ( $test_eH_gID, $test_eH_gToken ) =
  LANraragi::Plugin::EHentai::lookup_gallery( "TOUHOU GUNMANIA", "", "", "", $ua, $domain, 0 );

is( $test_eH_gID,    $eH_gID,    'eHentai search test 1/2' );
is( $test_eH_gToken, $eH_gToken, 'eHentai search test 2/2' );

my $eH_tags =
"parody:touhou project, character:hong meiling, character:marisa kirisame, character:reimu hakurei, character:sanae kochiya, character:youmu konpaku, group:handful happiness, artist:nanahara fuyuki, artbook, full color, category:non-h";
my ($test_eH_tags, $test_eH_title) =
  LANraragi::Plugin::EHentai::get_tags_from_EH( $eH_gID, $eH_gToken );

is( $test_eH_tags, $eH_tags, 'eHentai API Tag retrieval test' );
is( $test_eH_title, "(Kouroumu 8) [Handful☆Happiness! (Fuyuki Nanahara)] TOUHOU GUNMANIA A2 (Touhou Project)", "eHentai title test");

# nHentai Tests
my $nH_gID = "52249";
my $test_nH_gID =
  LANraragi::Plugin::nHentai::get_gallery_id_from_title("\"Pieces 1\" shirow");

is( $test_nH_gID, $nH_gID, 'nHentai search test' );

my $nH_tags =
"language:japanese, artist:masamune shirow, full color, non-h, artbook, category:manga";
my ($test_nH_tags, $test_nH_title) = LANraragi::Plugin::nHentai::get_tags_from_NH($nH_gID);

is( $test_nH_tags, $nH_tags, 'nHentai API Tag retrieval test' );
is( $test_nH_title, "Pieces 1", 'nHentai title test');

# Chaika Tests
my $mwee_ID = "27240";
my $mwee_title = '[Kemuri Haku] Zettai Seikou Keikaku | Absolute Intercourse Plan (COMIC Shitsurakuten 2016-03) [English] [Redlantern]';
my $mwee_tags = "language:english, language:translated, female:big breasts, female:nakadashi, female:defloration, male:shotacon, full censorship, artist:kemuri haku, male:sole male, female:sole female";

my ($tags_jsearch, $title_jsearch) = LANraragi::Plugin::Chaika::search_for_archive( "Zettai Seikou Keikaku", "artist:kemuri haku" );
is( $tags_jsearch, $mwee_tags, 'chaika.moe search test' );
is( $title_jsearch, $mwee_title, 'chaika.moe title test' );

my ($tags_id, $title_id) = LANraragi::Plugin::Chaika::tags_from_chaika_id( "archive", $mwee_ID );
is( $tags_id, $mwee_tags, 'chaika.moe API Tag retrieval test' );
is( $title_id, $mwee_title, 'chaika.moe ID title test ');

my $mwee_tags_sha1 = "language:english, uncensored, artist:ao banana, hentai, oppai, ahegao, tanlines, swimsuit, muscles, subscription, eyebrows, creampie, blowjob, publisher:fakku, magazine:comic shitsurakuten 2016-04";
my $mwee_title_sha1 = "Naughty Bath Matsuri-chan";
my ($tags_sha1, $title_sha1) = LANraragi::Plugin::Chaika::tags_from_sha1("276601a0e5dae9427940ed17ac470c9945b47073");
is( $tags_sha1, $mwee_tags_sha1, 'chaika.moe SHA-1 reverse search test' );
is( $title_sha1, $mwee_title_sha1, 'chaika.moe SHA-1 title test' );

done_testing();
