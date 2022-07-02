use strict;
use warnings;
use utf8;
use Data::Dumper;

use Cwd qw( getcwd );
use Mojo::JSON qw(decode_json encode_json);
use Mojo::File;

use Test::More;
use Test::Deep;

my $cwd     = getcwd();
my $SAMPLES = "$cwd/tests/samples";
require "$cwd/tests/mocks.pl";
setup_redis_mock();

my @all_tags = ( 
  'female:big breasts', 'female:big clit', 'female:blindfold', 'female:clit stimulation', 'female:collar', 'female:cunnilingus', 'female:elf', 
  'female:exhibitionism', 'female:females only', 'female:fff threesome', 'female:fingering', 'female:group', 'female:masturbation', 'female:nun', 
  'female:pixie cut', 'female:ponytail', 'female:slime', 'female:small breasts', 'female:squirting', 'female:stockings', 'female:tentacles', 'female:tomboy', 
  'female:tribadism', 'female:unusual pupils', 'female:yuri', 'story arc', 'parody:original', 'artist:yukataro', 'group:sonotaozey', 'type:doujinshi', 
  'language:english'
  );

use_ok('LANraragi::Plugin::Metadata::Hitomi');

note('testing getting tags from JSON ...');

{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Hitomi::get_plugin_logger = sub { return get_logger_mock(); };

    my $json = Mojo::File->new("$SAMPLES/hitomi/2261881.js")->slurp;
    my @tags = LANraragi::Plugin::Metadata::Hitomi::get_tags_from_taglist($json);

    cmp_bag( \@tags, \@all_tags, 'tag list' );
}

note('testing getting title from JSON ...');

{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Hitomi::get_plugin_logger = sub { return get_logger_mock(); };

    my $json = Mojo::File->new("$SAMPLES/hitomi/2261881.js")->slurp;
    my @tags = LANraragi::Plugin::Metadata::Hitomi::get_tags_from_taglist($json);

    my $title = LANraragi::Plugin::Metadata::Hitomi::get_title_from_json($json);

    is( $title, 'Nakayoshi Onna Boukensha wa Yoru ni Naru to Yadoya de Mechakucha Ecchi Suru | Party of Female Adventurers Fuck a lot at the Inn Once Nighttime Comes.', 'title' );
}

done_testing();
