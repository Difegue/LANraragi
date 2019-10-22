use strict;
use warnings;
use utf8;

use Mojo::Base 'Mojolicious';

use Test::More tests => 16;
use Test::Mojo;
use Test::MockObject;
use Mojo::JSON qw (decode_json);

use LANraragi::Model::Config;
use LANraragi::Model::Search;

# DataModel for searches
# Switch devmode to 1 for debug output in test
my %datamodel = %{decode_json qq(
    {
    "LRR_CONFIG": {
        "pagesize": "100",
        "devmode": "0"
    },
    "e69e43e1355267f7d32a4f9b7f2fe108d2401ebf": {
        "isnew": "none",
        "tags": "character:segata sanshiro",
        "title": "Saturn Backup Cartridge - Japanese Manual",
        "file": "README.md"
    },
    "e69e43e1355267f7d32a4f9b7f2fe108d2401ebg": {
        "isnew": "none",
        "tags": "character:segata",
        "title": "Saturn Backup Cartridge - American Manual",
        "file": "README.md"
    },
    "e4c422fd10943dc169e3489a38cdbf57101a5f7e": {
        "isnew": "true",
        "tags": "parody: jojo's bizarre adventure",
        "title": "Rohan Kishibe goes to Gucci",
        "file": "README.md"
    },
    "4857fd2e7c00db8b0af0337b94055d8445118630": {
        "isnew": "none",
        "tags": "artist:shirow masamune",
        "title": "Ghost in the Shell 1.5 - Human-Error Processor vol01ch01",
        "file": "README.md"
    },
    "2810d5e0a8d027ecefebca6237031a0fa7b91eb3": {
        "isnew": "none",
        "tags": "parody:fate grand order,  character:abigail williams,  character:artoria pendragon alter,  character:asterios,  character:ereshkigal,  character:gilgamesh,  character:hans christian andersen,  character:hassan of serenity,  character:hector,  character:helena blavatsky,  character:irisviel von einzbern,  character:jeanne alter,  character:jeanne darc,  character:kiara sessyoin,  character:kiyohime,  character:lancer,  character:martha,  character:minamoto no raikou,  character:mochizuki chiyome,  character:mordred pendragon,  character:nitocris,  character:oda nobunaga,  character:osakabehime,  character:penthesilea,  character:queen of sheba,  character:rin tosaka,  character:saber,  character:sakata kintoki,  character:scheherazade,  character:sherlock holmes,  character:suzuka gozen,  character:tamamo no mae,  character:ushiwakamaru,  character:waver velvet,  character:xuanzang,  character:zhuge liang,  group:wadamemo,  artist:wada rco,  artbook,  full color",
        "title": "Fate GO MEMO 2",
        "file": "README.md"
    },
    "28697b96f0ac5858be2614ed10ca47742c9522fd": {
        "isnew": "none",
        "tags": "parody:fate grand order,  group:wadamemo,  artist:wada rco,  artbook,  full color",
        "title": "Fate GO MEMO",
        "file": "README.md"
    }
})};

# Mock Redis object which uses the datamodel
my $redis = Test::MockObject->new();
$redis->mock( 'keys',    sub { return keys %datamodel; } );
$redis->mock( 'exists',  sub { 0 } );
$redis->mock( 'hexists', sub { 1 } );
$redis->mock( 'hset',    sub { 1 } );
$redis->mock( 'quit',    sub { 1 } );

$redis->mock( 'hget', # $redis->hget => get key in datamodel
    sub {
        my $self = shift;
        my ($key, $hashkey) = @_;

        my $value = $datamodel{$key}{$hashkey};
        return $value;
     } );

$redis->fake_module(
    "Redis",
    new => sub {$redis});

is( $redis->hget("28697b96f0ac5858be2614ed10ca47742c9522fd","title"), "Fate GO MEMO", 'Redis mock test' );

# Search queries
my $search = qq(Ghost in the Shell);
my ($total, $filtered, @ids);

sub do_test_search {
    ($total, $filtered, @ids) = LANraragi::Model::Search::do_search($search, "", 0, 0, 0, 0);
}

do_test_search();
is(%{$ids[0]}{title}, "Ghost in the Shell 1.5 - Human-Error Processor vol01ch01", qq(Basic search ($search)));

$search = qq("Fate GO MEMO");
do_test_search();
is($filtered, 2, qq(Non-exact quoted search ($search)));

$search = qq("Fate GO MEMO?");
do_test_search();
is($filtered, 1, qq(Wildcard search ($search)));

$search = qq("Fate GO MEMO _");
do_test_search();
is($filtered, 1, qq(Wildcard search ($search)));

$search = qq("Saturn*Cartridge*Japanese");
do_test_search();
is(%{$ids[0]}{title}, "Saturn Backup Cartridge - Japanese Manual", qq(Multiple wildcard search ($search)));

$search = qq("Saturn\%American");
do_test_search();
is(%{$ids[0]}{title}, "Saturn Backup Cartridge - American Manual", qq(Multiple wildcard search ($search)));

$search = qq("artist:wada rco" character:ereshkigal);
do_test_search();
ok( $filtered eq 1 && %{$ids[0]}{title} eq "Fate GO MEMO 2",
    qq(Tag inclusion search ($search)));

$search = qq("artist:wada rco" -character:ereshkigal);
do_test_search();
ok( $filtered eq 1 && %{$ids[0]}{title} eq "Fate GO MEMO",
    qq(Tag exclusion search ($search)));

$search = qq("artist:wada rco" -"character:waver velvet");
do_test_search();
ok( $filtered eq 1 && %{$ids[0]}{title} eq "Fate GO MEMO",
    qq(Tag exclusion with quotes ($search)));

$search = qq("artist:wada rco" "-character:waver velvet");
do_test_search();
is($filtered, 0, qq(Incorrect tag exclusion ($search)));

$search = qq(character:segata\$);
do_test_search();
ok( $filtered eq 1 && %{$ids[0]}{title} eq "Saturn Backup Cartridge - American Manual",
    qq(Exact search without quotes ($search)));

$search = qq("Fate GO MEMO"\$);
do_test_search();
is($filtered, 1, qq(Exact search with quotes ($search)));

$search = qq("Saturn Backup Cartridge - *"\$);
do_test_search();
is($filtered, 2, qq(Exact search with quotes and wildcard ($search)));

$search = qq("character:segata");
($total, $filtered, @ids) = LANraragi::Model::Search::do_search($search, qq("American"), 0, 0, 0, 0);
is($filtered, 1, qq(Search with favorite tag applied ($search) + ("American")));

($total, $filtered, @ids) = LANraragi::Model::Search::do_search("", "", 0, 0, 0, 1);
ok( $filtered eq 1 && %{$ids[0]}{title} eq "Rohan Kishibe goes to Gucci",
    qq(Search with new filter applied));

done_testing();
