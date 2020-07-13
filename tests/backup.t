use strict;
use warnings;
use utf8;
use Cwd;

use Mojo::Base 'Mojolicious';

use Test::More tests => 1;
use Test::Mojo;
use Test::MockObject;
use Mojo::JSON qw(decode_json encode_json);
use Data::Dumper;

use LANraragi::Model::Config;
use LANraragi::Model::Backup;

# Mock Redis
my $cwd = getcwd;
require $cwd . "/tests/mocks.pl";
setup_redis_mock();

# Would've liked to compare JSON strings directly here, but since the key order is non-deterministic it's easier to compare the result hashes.
my %expected_backup =
  %{ decode_json
      qq({"archives":[{"arcid":"e4c422fd10943dc169e3489a38cdbf57101a5f7e","filename":null,"tags":"parody: jojo's bizarre adventure","thumbhash":null,"title":"Rohan Kishibe goes to Gucci"},{"arcid":"4857fd2e7c00db8b0af0337b94055d8445118630","filename":null,"tags":"artist:shirow masamune","thumbhash":null,"title":"Ghost in the Shell 1.5 - Human-Error Processor vol01ch01"},{"arcid":"e69e43e1355267f7d32a4f9b7f2fe108d2401ebf","filename":null,"tags":"character:segata sanshiro","thumbhash":null,"title":"Saturn Backup Cartridge - Japanese Manual"},{"arcid":"e69e43e1355267f7d32a4f9b7f2fe108d2401ebg","filename":null,"tags":"character:segata","thumbhash":null,"title":"Saturn Backup Cartridge - American Manual"},{"arcid":"28697b96f0ac5858be2614ed10ca47742c9522fd","filename":null,"tags":"parody:fate grand order,  group:wadamemo,  artist:wada rco,  artbook,  full color","thumbhash":null,"title":"Fate GO MEMO"},{"arcid":"2810d5e0a8d027ecefebca6237031a0fa7b91eb3","filename":null,"tags":"parody:fate grand order,  character:abigail williams,  character:artoria pendragon alter,  character:asterios,  character:ereshkigal,  character:gilgamesh,  character:hans christian andersen,  character:hassan of serenity,  character:hector,  character:helena blavatsky,  character:irisviel von einzbern,  character:jeanne alter,  character:jeanne darc,  character:kiara sessyoin,  character:kiyohime,  character:lancer,  character:martha,  character:minamoto no raikou,  character:mochizuki chiyome,  character:mordred pendragon,  character:nitocris,  character:oda nobunaga,  character:osakabehime,  character:penthesilea,  character:queen of sheba,  character:rin tosaka,  character:saber,  character:sakata kintoki,  character:scheherazade,  character:sherlock holmes,  character:suzuka gozen,  character:tamamo no mae,  character:ushiwakamaru,  character:waver velvet,  character:xuanzang,  character:zhuge liang,  group:wadamemo,  artist:wada rco,  artbook,  full color","thumbhash":null,"title":"Fate GO MEMO 2"}],"categories":[{"archives":["e69e43e1355267f7d32a4f9b7f2fe108d2401ebf","e69e43e1355267f7d32a4f9b7f2fe108d2401ebg"],"catid":"SET_1589141306","name":"Segata Sanshiro","search":""},{"archives":[],"catid":"SET_1589138380","name":"AMERICA ONRY","search":"American"}]})
  };

# Backup the mocked Redis DB and compare it against our known backup object
my $resultJSON = LANraragi::Model::Backup::build_backup_JSON();
is( %{ decode_json $resultJSON}, %expected_backup, "Backup creation test" );
