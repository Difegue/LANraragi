use strict;
use warnings;
use utf8;
use Cwd;

use Mojo::Base 'Mojolicious';
use Test::More;
use Test::Trap;
use Test::Mojo;
use Test::MockObject;

use Data::Dumper;

use LANraragi::Model::Config;
use LANraragi::Plugin::Login::EHentai;
use LANraragi::Plugin::Metadata::EHentai;
use LANraragi::Plugin::Metadata::nHentai;
use LANraragi::Plugin::Metadata::Chaika;
use LANraragi::Plugin::Metadata::Eze;
use LANraragi::Plugin::Metadata::Fakku;
use LANraragi::Plugin::Metadata::Hitomi;

# Mock Redis
my $cwd = getcwd;
require $cwd . "/tests/mocks.pl";
setup_redis_mock();

note("E-Hentai Tests");

{
    my $ua        = trap { LANraragi::Plugin::Login::EHentai::do_login( "", "", "" ); };
    my $domain    = "e-hentai.org";
    my $eH_gID    = "618395";
    my $eH_gToken = "0439fa3666";

    my ( $test_eH_gID, $test_eH_gToken ) =
      trap { LANraragi::Plugin::Metadata::EHentai::lookup_gallery( "TOUHOU GUNMANIA", "", "", $ua, $domain, "", 0, 0 ); };

    is( $test_eH_gID,    $eH_gID,    'eHentai search test 1/2' );
    is( $test_eH_gToken, $eH_gToken, 'eHentai search test 2/2' );

    my $test_eH_json = trap { LANraragi::Plugin::Metadata::EHentai::get_json_from_EH( $ua, $eH_gID, $eH_gToken ); };

    ok( exists $test_eH_json->{gmetadata}, 'gmetadata exists' );
    isa_ok( $test_eH_json->{gmetadata}, 'ARRAY', 'type of gmetadata' );
    ok( length( $test_eH_json->{gmetadata}[0]{title} ) > 0, "eHentai title test 1" );
    isa_ok( $test_eH_json->{gmetadata}[0]{tags}, 'ARRAY', 'type of tags' );
}

note("nHentai Tests : Disabled due to cloudflare being used on nH");

# {
#     my $nH_gID      = "52249";
#     my $test_nH_gID = LANraragi::Plugin::Metadata::nHentai::get_gallery_id_from_title("\"Pieces 1\" shirow");
#
#     is( $test_nH_gID, $nH_gID, 'nHentai search test' );

#     my %nH_hashdata = trap { LANraragi::Plugin::Metadata::nHentai::get_tags_from_NH( $nH_gID, 1 ) };

#     ok( length $nH_hashdata{tags} > 0,  'nHentai API Tag retrieval test' );
#     ok( length $nH_hashdata{title} > 0, 'nHentai title test' );
# }

note("Chaika Tests");

{
    my ( $tags_jsearch, $title_jsearch ) =
      trap { LANraragi::Plugin::Metadata::Chaika::search_for_archive( "Zettai Seikou Keikaku", "artist:kemuri haku" ); };
    ok( length $tags_jsearch > 0,  'chaika.moe search test' );
    ok( length $title_jsearch > 0, 'chaika.moe title test' );

    my ( $tags_by_id, $title_by_id ) = trap { LANraragi::Plugin::Metadata::Chaika::tags_from_chaika_id( "archive", "27240" ); };
    ok( length $tags_by_id > 0,  'chaika.moe API Tag retrieval test' );
    ok( length $title_by_id > 0, 'chaika.moe ID title test ' );

    my ( $tags_by_sha1, $title_by_sha1 ) =
      trap { LANraragi::Plugin::Metadata::Chaika::tags_from_sha1("276601a0e5dae9427940ed17ac470c9945b47073"); };
    ok( length $tags_jsearch > 0, 'chaika.moe SHA-1 reverse search test' );
    ok( length $title_by_id > 0,  'chaika.moe SHA-1 title test' );
}

note("FAKKU Tests : Disabled due to cloudflare being used");

# {
#     my $f_title = "Kairakuten Cover Girl's Episode 009: Hamao";
#     my $f_url   = "https://www.fakku.net/hentai/kairakuten-cover-girls-episode-009-hamao-english";
#     my $f_tags =
#       "Artist:Hamao, Parody:Original Work, Magazine:Comic Kairakuten 2020-04, Publisher:FAKKU, Language:English, color, schoolgirl outfit, osananajimi, unlimited, non-h, illustration";

#     is( LANraragi::Plugin::Metadata::Fakku::search_for_fakku_url($f_title), $f_url, 'FAKKU search test' );

#     my ( $f_result_tags, $f_result_title ) = LANraragi::Plugin::Metadata::Fakku::get_tags_from_fakku($f_url);
#     is( $f_result_tags,  $f_tags,  'FAKKU tags parsing test' );
#     is( $f_result_title, $f_title, 'FAKKU title parsing test' );
# }

note("Hitomi Tests");

{
    my $hi_gID      = "2261881";
    my %hi_hashdata = trap { LANraragi::Plugin::Metadata::Hitomi::get_tags_from_Hitomi( $hi_gID, 1 ); };

    ok( length $hi_hashdata{tags} > 0, 'Hitomi API Tag retrieval test' );
    is( $hi_hashdata{title},
        "Nakayoshi Onna Boukensha wa Yoru ni Naru to Yadoya de Mechakucha Ecchi Suru | Party of Female Adventurers Fuck a lot at the Inn Once Nighttime Comes.",
        'Hitomi title test'
    );
}

done_testing();
