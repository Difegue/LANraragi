use strict;
use warnings;
use utf8;

use Mojo::Base 'Mojolicious';

use Test::More tests => 2;
use Test::Mojo;
use Test::MockObject;
use Mojo::JSON qw (decode_json);

use LANraragi::Model::Config;
use LANraragi::Model::Search;

# DataModel for searches
my %datamodel = %{decode_json qq(
    {
    "LRR_CONFIG": {
        "pagesize": "100"

    },
    "e69e43e1355267f7d32a4f9b7f2fe108d2401ebf": {
        "isnew": "none",
        "tags": "character:segata sanshiro",
        "title": "Saturn Backup Cartridge - Japanese Manual",
        "file": "README.md"
    },
    "e4c422fd10943dc169e3489a38cdbf57101a5f7e": {
        "isnew": "none",
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
my ($total, $filtered, @ids) = LANraragi::Model::Search::do_search("Saturn", "", 0, 0, 0);
is(%{@ids[0]}{title}, "Saturn Backup Cartridge - Japanese Manual", "Search for 'Saturn'");




done_testing();
