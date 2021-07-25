use strict;
use warnings;
use utf8;
use Cwd;
use File::Temp qw(tempfile);
use File::Copy "cp";

use Test::MockObject;
use Mojo::JSON qw (decode_json);

sub setup_eze_mock {

    # Copy the eze sample json to a temporary directory as it's deleted once parsed
    my $cwd = getcwd;
    my ( $fh, $filename ) = tempfile();
    cp( $cwd . "/tests/samples/eze/eze_sample.json", $fh );

    # Mock LANraragi::Utils::Archive's subs to return the temporary sample JSON
    # Since we're using exports, the methods are under the plugin's namespace.
    no warnings 'once', 'redefine';
    *LANraragi::Plugin::Metadata::Eze::extract_file_from_archive = sub { $filename };
    *LANraragi::Plugin::Metadata::Eze::is_file_in_archive        = sub { 1 };
}

sub setup_redis_mock {

    # DataModel for searches
    # files are set to package.json since the search engine checks for file existence and I ain't about to mock perl's -e call
    # Switch devmode to 1 for debug output in test
    my %datamodel = %{ decode_json qq(
        {
        "LRR_CONFIG": {
            "pagesize": "100",
            "devmode": "1"
        },
        "SET_1589141306": {
            "archives": "[\\\"e69e43e1355267f7d32a4f9b7f2fe108d2401ebf\\\",\\\"e69e43e1355267f7d32a4f9b7f2fe108d2401ebg\\\"]",
            "last_used": "1589141306",
            "name": "Segata Sanshiro",
            "pinned": "1",
            "search": ""
        },
        "SET_1589138380":{
            "archives": "[]",
            "id": "SET_1589138380",
            "last_used": "1589138380",
            "name": "AMERICA ONRY",
            "pinned": "0",
            "search": "American"
        },
        "e69e43e1355267f7d32a4f9b7f2fe108d2401ebf": {
            "isnew": "false",
            "pagecount": 2,
            "progress": 10,
            "tags": "character:segata sanshiro",
            "title": "Saturn Backup Cartridge - Japanese Manual",
            "file": "package.json"
        },
        "e69e43e1355267f7d32a4f9b7f2fe108d2401ebg": {
            "isnew": "false",
            "pagecount": 0,
            "progress": 34,
            "tags": "character:segata",
            "title": "Saturn Backup Cartridge - American Manual",
            "file": "package.json"
        },
        "e4c422fd10943dc169e3489a38cdbf57101a5f7e": {
            "isnew": "true",
            "pagecount": 0,
            "progress": 0,
            "tags": "parody: jojo's bizarre adventure",
            "title": "Rohan Kishibe goes to Gucci",
            "file": "package.json"
        },
        "4857fd2e7c00db8b0af0337b94055d8445118630": {
            "isnew": "false",
            "pagecount": 34,
            "progress": 34,
            "tags": "artist:shirow masamune",
            "title": "Ghost in the Shell 1.5 - Human-Error Processor vol01ch01",
            "file": "package.json"
        },
        "2810d5e0a8d027ecefebca6237031a0fa7b91eb3": {
            "isnew": "false",
            "pagecount": 34,
            "progress": 34,
            "tags": "parody:fate grand order,  character:abigail williams,  character:artoria pendragon alter,  character:asterios,  character:ereshkigal,  character:gilgamesh,  character:hans christian andersen,  character:hassan of serenity,  character:hector,  character:helena blavatsky,  character:irisviel von einzbern,  character:jeanne alter,  character:jeanne darc,  character:kiara sessyoin,  character:kiyohime,  character:lancer,  character:martha,  character:minamoto no raikou,  character:mochizuki chiyome,  character:mordred pendragon,  character:nitocris,  character:oda nobunaga,  character:osakabehime,  character:penthesilea,  character:queen of sheba,  character:rin tosaka,  character:saber,  character:sakata kintoki,  character:scheherazade,  character:sherlock holmes,  character:suzuka gozen,  character:tamamo no mae,  character:ushiwakamaru,  character:waver velvet,  character:xuanzang,  character:zhuge liang,  group:wadamemo,  artist:wada rco,  artbook,  full color",
            "title": "Fate GO MEMO 2",
            "file": "package.json"
        },
        "28697b96f0ac5858be2614ed10ca47742c9522fd": {
            "isnew": "false",
            "pagecount": 0,
            "progress": 0,
            "tags": "parody:fate grand order,  group:wadamemo,  artist:wada rco,  artbook,  full color",
            "title": "Fate GO MEMO",
            "file": "package.json"
        }
    })
    };

    # Mock Redis object which uses the datamodel
    my $redis = Test::MockObject->new();
    $redis->mock(
        'keys',    # $redis->keys => get keys matching predicate in datamodel
        sub {
            shift;
            my $expr = $_[0] =~ s/\?/\./gr;    # Replace redis' '?' wildcards with regex '.'s
            return grep { /$expr/ } keys %datamodel;
        }
    );
    $redis->mock( 'exists',  sub { shift; return $_[0] eq "LRR_SEARCHCACHE" ? 0 : 1 } );
    $redis->mock( 'hexists', sub { 1 } );
    $redis->mock( 'hset',    sub { 1 } );
    $redis->mock( 'quit',    sub { 1 } );
    $redis->mock( 'select',  sub { 1 } );

    $redis->mock(
        'hget',                                # $redis->hget => get value of key in datamodel
        sub {
            my $self = shift;
            my ( $key, $hashkey ) = @_;

            my $value = $datamodel{$key}{$hashkey};
            return $value;
        }
    );

    $redis->mock(
        'hgetall',                             # $redis->hgetall => get all values of key in datamodel
        sub {
            my $self = shift;
            my $key  = shift;

            my %value = %{ $datamodel{$key} };
            return %value;
        }
    );

    $redis->fake_module( "Redis", new => sub { $redis } );
}

sub get_logger_mock {
    my $mock = Test::MockObject->new();
    $mock->mock(
        'debug', sub { },
        'info', sub { }
    );
    return $mock;
}

1;
