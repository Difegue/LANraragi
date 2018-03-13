use Mojo::Base 'Mojolicious';

use Test::More tests => 5;
use Test::Mojo;

use LANraragi::Plugin::EHentai;
use LANraragi::Plugin::nHentai;

#EHentai Tests
my $eH_gID = "618395";
my $eH_gToken = "0439fa3666";

my( $test_eH_gID, $test_eH_gToken ) = LANraragi::Plugin::EHentai::lookup_by_title( "TOUHOU GUNMANIA", "", "", "" );

is( $test_eH_gID, $eH_gID, 'eHentai search test 1/2' );
is( $test_eH_gToken, $eH_gToken, 'eHentai search test 2/2' );

my $eH_tags = "parody:touhou project, character:hong meiling, character:marisa kirisame, character:reimu hakurei, character:sanae kochiya, character:youmu konpaku, group:handful happiness, artist:nanahara fuyuki, artbook, full color";
my $test_eH_tags = LANraragi::Plugin::EHentai::get_tags_from_EH( $eH_gID, $eH_gToken );

is( $test_eH_tags, $eH_tags, 'eHentai API Tag retrieval test' );

#NHentai Tests
my $nH_gID = "52249";
my $test_nH_gID = LANraragi::Plugin::nHentai::get_gallery_id_from_title("\"Pieces 1\" shirow");

is( $test_nH_gID, $nH_gID, 'nHentai search test' );

my $nH_tags = "language:japanese, artist:masamune shirow, full color, non-h, artbook, category:manga";
my $test_nH_tags = LANraragi::Plugin::nHentai::get_tags_from_NH($nH_gID);

is( $test_nH_tags, $nH_tags, 'nHentai API Tag retrieval test' );

done_testing();
