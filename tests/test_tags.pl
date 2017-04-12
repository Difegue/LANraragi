use Test::More tests => 4;

use LWP::Simple qw($ua get);

#Add the regular webapp directory to @INC so the test has access to all the files 
use lib "/var/www/lanraragi"; 

#What we're testing
require 'functions/functions_tags.pl';

my $eHentaiURLTest = "http://g.e-hentai.org/?f_doujinshi=1&f_manga=1&f_artistcg=1&f_gamecg=1&f_western=1&f_non-h=1&f_imageset=1&f_cosplay=1&f_asianporn=1&f_misc=1&f_search=TOUHOU%20GUNMANIA&f_apply=Apply+Filter";
my $eHentaiExpectedJSON = qq({"method": "gdata","gidlist": [[618395,"0439fa3666"]]});

my $nHentaiURLTest = "https://nhentai.net/api/galleries/search?query=%22Pieces+1%22+shirow";
my $nHentaiExpectedID = "52249";

my $eHentaiExpectedTags = "touhou project, hong meiling, marisa kirisame, reimu hakurei, sanae kochiya, youmu konpaku, handful happiness, nanahara fuyuki, full color, artbook";
my $nHentaiExpectedTags = "japanese, masamune shirow, full color, non-h, artbook, manga";


is( &eHentaiLookup($eHentaiURLTest), $eHentaiExpectedJSON, 'eHentai search test' );
is( &nHentaiLookup($nHentaiURLTest), $nHentaiExpectedID, 'nHentai search test' );
is( &getTagsFromEHAPI($eHentaiExpectedJSON), $eHentaiExpectedTags, 'eHentai API Tag retrieval test' );
is( &getTagsFromNHAPI($nHentaiExpectedID), $nHentaiExpectedTags, 'nHentai API Tag retrieval test' );

