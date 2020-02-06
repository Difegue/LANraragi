use strict;
use warnings;
use utf8;
use Cwd;

use Mojo::Base 'Mojolicious';

use Test::More tests => 15;
use Test::Mojo;
use Test::MockObject;

use Data::Dumper;

use LANraragi::Plugin::Metadata::EHentai;
use LANraragi::Plugin::Metadata::nHentai;
use LANraragi::Plugin::Metadata::Chaika;
use LANraragi::Plugin::Metadata::Eze;

# Mock Redis
my $cwd = getcwd;
require $cwd."/tests/mocks.pl";
setup_redis_mock();

# Mock Utils::Archive
setup_eze_mock();

# eze Tests
my %ezetags = LANraragi::Plugin::Metadata::Eze::get_tags("test", "test", "test", "test", "test", "test", 1);

my $ezetags = "artist:mitarashi kousei, character:akiko minase, character:yuuichi aizawa, female:aunt, female:lingerie, female:sole female, group:mitarashi club, language:english, language:translated, male:sole male, misc:multi-work series, parody:kanon, source: website.org/g/1179590/7c5815c77b";
is( $ezetags{title}, "Akiko-san to Issho", "eze parsing test 1/2");
is( $ezetags{tags}, $ezetags, "eze parsing test 2/2");

# E-Hentai Tests
my ( $ua, $domain ) = LANraragi::Plugin::Metadata::EHentai::get_user_agent("","","");
my $eH_gID    = "618395";
my $eH_gToken = "0439fa3666";

my ( $test_eH_gID, $test_eH_gToken ) =
  LANraragi::Plugin::Metadata::EHentai::lookup_gallery( "TOUHOU GUNMANIA", "", "", "", $ua, $domain, 0 );

is( $test_eH_gID,    $eH_gID,    'eHentai search test 1/2' );
is( $test_eH_gToken, $eH_gToken, 'eHentai search test 2/2' );

my $eH_tags =
"parody:touhou project, character:hong meiling, character:marisa kirisame, character:reimu hakurei, character:sanae kochiya, character:youmu konpaku, group:handful happiness, artist:nanahara fuyuki, artbook, full color, category:non-h";
my ($test_eH_tags, $test_eH_title) =
  LANraragi::Plugin::Metadata::EHentai::get_tags_from_EH( $eH_gID, $eH_gToken );

is( $test_eH_tags, $eH_tags, 'eHentai API Tag retrieval test' );
is( $test_eH_title, "(Kouroumu 8) [Handful☆Happiness! (Fuyuki Nanahara)] TOUHOU GUNMANIA A2 (Touhou Project)", "eHentai title test");

# nHentai Tests
my $nH_gID = "52249";
my $test_nH_gID =
  LANraragi::Plugin::Metadata::nHentai::get_gallery_id_from_title("\"Pieces 1\" shirow");

is( $test_nH_gID, $nH_gID, 'nHentai search test' );

my $nH_tags =
"language:japanese, artist:masamune shirow, full color, non-h, artbook, category:manga";
my ($test_nH_tags, $test_nH_title) = LANraragi::Plugin::Metadata::nHentai::get_tags_from_NH($nH_gID);

is( $test_nH_tags, $nH_tags, 'nHentai API Tag retrieval test' );
is( $test_nH_title, "Pieces 1", 'nHentai title test');

# Chaika Tests
my $mwee_ID = "27240";
my $mwee_title = '[Kemuri Haku] Zettai Seikou Keikaku | Absolute Intercourse Plan (COMIC Shitsurakuten 2016-03) [English] [Redlantern]';
my $mwee_tags = "female:sole female, male:sole male, artist:kemuri haku, full censorship, male:shotacon, female:defloration, female:nakadashi, female:big breasts, language:translated, language:english";

my ($tags_jsearch, $title_jsearch) = LANraragi::Plugin::Metadata::Chaika::search_for_archive( "Zettai Seikou Keikaku", "artist:kemuri haku" );
is( $tags_jsearch, $mwee_tags, 'chaika.moe search test' );
is( $title_jsearch, $mwee_title, 'chaika.moe title test' );

my ($tags_id, $title_id) = LANraragi::Plugin::Metadata::Chaika::tags_from_chaika_id( "archive", $mwee_ID );
is( $tags_id, $mwee_tags, 'chaika.moe API Tag retrieval test' );
is( $title_id, $mwee_title, 'chaika.moe ID title test ');

my $mwee_tags_sha1 = "magazine:comic shitsurakuten 2016-04, publisher:fakku, blowjob, creampie, eyebrows, subscription, muscles, swimsuit, tanlines, ahegao, oppai, hentai, artist:ao banana, uncensored, language:english";
my $mwee_title_sha1 = "Naughty Bath Matsuri-chan";
my ($tags_sha1, $title_sha1) = LANraragi::Plugin::Metadata::Chaika::tags_from_sha1("276601a0e5dae9427940ed17ac470c9945b47073");
is( $tags_sha1, $mwee_tags_sha1, 'chaika.moe SHA-1 reverse search test' );
is( $title_sha1, $mwee_title_sha1, 'chaika.moe SHA-1 title test' );

done_testing();
