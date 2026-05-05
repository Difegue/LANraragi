use strict;
use warnings;
use utf8;
use Cwd;

use Mojo::Base 'Mojolicious';

use Test::More;
use Test::Deep;
use Test::Mojo;
use Test::MockObject;
use Mojo::JSON qw(decode_json encode_json);
use Data::Dumper;

# Mock Redis
my $cwd = getcwd;
require $cwd . "/tests/mocks.pl";
setup_redis_mock();

use LANraragi::Model::Config;
use LANraragi::Model::Backup;

# Would've liked to compare JSON strings directly here, but since the key order is non-deterministic it's easier to compare the result hashes.
my %expected_backup =
  %{ decode_json qq({"archives":[
          {"arcid":"be447b58ea66137c415ee306ee2ac44b308ee484","filename":null,"tags":"series:Neon Genesis Evangelion, artist:Yoshiyuki Sadamoto, chapter:1, character:Shinji Ikari, character:Misato Katsuragi, science fiction","thumbhash":null,"title":"\u4f7f\u5f92\u3001\u8972\u6765", "summary":"", "stamps":"[\\\"STAMPS_0_1777224824660\\\", \\\"STAMPS_0_1777224824661\\\", \\\"STAMPS_1_1777224824662\\\", \\\"STAMPS_2_1777224824663\\\", \\\"STAMPS_3_1777224824664\\\"]"},
          {"arcid":"e4c422fd10943dc169e3489a38cdbf57101a5f7e","filename":null,"tags":"parody: jojo's bizarre adventure","thumbhash":null,"title":"Rohan Kishibe goes to Gucci", "summary":"", "stamps":null},
          {"arcid":"4857fd2e7c00db8b0af0337b94055d8445118630","filename":null,"tags":"artist:shirow masamune","thumbhash":null,"title":"Ghost in the Shell 1.5 - Human-Error Processor vol01ch01", "summary":"", "stamps":null},
          {"arcid":"e69e43e1355267f7d32a4f9b7f2fe108d2401ebf","filename":null,"tags":"character:segata sanshiro, male:very cool","thumbhash":null,"title":"Saturn Backup Cartridge - Japanese Manual", "summary":"", "stamps":null},
          {"arcid":"e69e43e1355267f7d32a4f9b7f2fe108d2401ebg","filename":null,"tags":"character:segata, female:very cool too","thumbhash":null,"title":"Saturn Backup Cartridge - American Manual", "summary":"", "stamps":null},
          {"arcid":"28697b96f0ac5858be2614ed10ca47742c9522fd","filename":null,"tags":"parody:fate grand order,  group:wadamemo,  artist:wada rco,  artbook,  full color, male:very cool too","thumbhash":null,"title":"Fate GO MEMO", "summary":"", "stamps":null},
          {"arcid":"2810d5e0a8d027ecefebca6237031a0fa7b91eb3","filename":null,"tags":"parody:fate grand order,  character:abigail williams,  character:artoria pendragon alter,  character:asterios,  character:ereshkigal,  character:gilgamesh,  character:hans christian andersen,  character:hassan of serenity,  character:hector,  character:helena blavatsky,  character:irisviel von einzbern,  character:jeanne alter,  character:jeanne darc,  character:kiara sessyoin,  character:kiyohime,  character:lancer,  character:martha,  character:minamoto no raikou,  character:mochizuki chiyome,  character:mordred pendragon,  character:nitocris,  character:oda nobunaga,  character:osakabehime,  character:penthesilea,  character:queen of sheba,  character:rin tosaka,  character:saber,  character:sakata kintoki,  character:scheherazade,  character:sherlock holmes,  character:suzuka gozen,  character:tamamo no mae,  character:ushiwakamaru,  character:waver velvet,  character:xuanzang,  character:zhuge liang,  group:wadamemo,  artist:wada rco,  artbook,  full color","thumbhash":null,"title":"Fate GO MEMO 2", "summary":"", "stamps":null},
          {"arcid":"28697b96f0ac5777be2614ed10ca47742c9522fa","filename":null,"tags":"year of shadow, character:vector the crocodile","thumbhash":null,"title":"Find the Computer Room", "summary":"", "stamps":null},
          {"arcid":"28697b96f0ac5858be2666ed10ca47742c955555","filename":null,"tags":"medjed, character:doubles guy, character:king of GETs, check this 5","thumbhash":null,"title":"All about Egypt", "summary":"CURSE OF RA", "stamps":null}
        ],
        "categories":[
          {"archives":["e69e43e1355267f7d32a4f9b7f2fe108d2401ebf","e69e43e1355267f7d32a4f9b7f2fe108d2401ebg"],"catid":"SET_1589141306","name":"Segata Sanshiro","search":""},
          {"archives":[],"catid":"SET_1589138380","name":"AMERICA ONRY","search":"American"}
        ],
        "tankoubons":[
          {"archives":["28697b96f0ac5858be2666ed10ca47742c955555", "28697b96f0ac5777be2614ed10ca47742c9522fa"],"tankid":"TANK_1589141306","name":"Hello"},
          {"archives":["28697b96f0ac5777be2614ed10ca47742c9522fa"],"tankid":"TANK_1589138380","name":"World"}
        ],
        "stamps":[
          {"archive_id":"be447b58ea66137c415ee306ee2ac44b308ee484","content":"Lorem","position":"0,0","stamp_id":"STAMPS_0_1777224824660"},
          {"archive_id":"be447b58ea66137c415ee306ee2ac44b308ee484","content":"Ipsum","position":"0,0","stamp_id":"STAMPS_0_1777224824661"},
          {"archive_id":"be447b58ea66137c415ee306ee2ac44b308ee484","content":"Dolor","position":"0,0","stamp_id":"STAMPS_1_1777224824662"},
          {"archive_id":"be447b58ea66137c415ee306ee2ac44b308ee484","content":"Sit","position":"0,0","stamp_id":"STAMPS_2_1777224824663"},
          {"archive_id":"be447b58ea66137c415ee306ee2ac44b308ee484","content":"Amet","position":"0,0","stamp_id":"STAMPS_3_1777224824664"}
        ]})
  };

# Backup the mocked Redis DB and compare it against our known backup object
my $resultJSON      = LANraragi::Model::Backup::build_backup_JSON();
my %computed_backup = %{ decode_json $resultJSON };

my @sorted_computed = sort { $a->{arcid} cmp $b->{arcid} } @{ $computed_backup{"archives"} };
my @sorted_expected = sort { $a->{arcid} cmp $b->{arcid} } @{ $expected_backup{"archives"} };

cmp_deeply( \@sorted_computed, \@sorted_expected, "Backup archive comparison" );

@sorted_computed = sort { $a->{catid} cmp $b->{catid} } @{ $computed_backup{"categories"} };
@sorted_expected = sort { $a->{catid} cmp $b->{catid} } @{ $expected_backup{"categories"} };

cmp_deeply( \@sorted_computed, \@sorted_expected, "Backup category comparison" );

@sorted_computed = sort { $a->{tankid} cmp $b->{tankid} } @{ $computed_backup{"tankoubons"} };
@sorted_expected = sort { $a->{tankid} cmp $b->{tankid} } @{ $expected_backup{"tankoubons"} };

cmp_deeply( \@sorted_computed, \@sorted_expected, "Backup tankoubon comparison" );

@sorted_computed = sort { $a->{stamp_id} cmp $b->{stamp_id} } @{ $computed_backup{"stamps"} };
@sorted_expected = sort { $a->{stamp_id} cmp $b->{stamp_id} } @{ $expected_backup{"stamps"} };

cmp_deeply( \@sorted_computed, \@sorted_expected, "Backup stamps comparison" );

done_testing();
