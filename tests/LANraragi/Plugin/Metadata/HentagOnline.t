# LANraragi::Plugin::Metadata::HentagOnline
use strict;
use warnings;
use utf8;
use Data::Dumper;
use File::Temp qw(tempfile);
use File::Copy "cp";

use Cwd qw( getcwd );

use Test::Trap;
use Test::More;
use Test::Deep;

my $cwd     = getcwd();
my $SAMPLES = "$cwd/tests/samples";
require "$cwd/tests/mocks.pl";

use_ok('LANraragi::Plugin::Metadata::HentagOnline');

note("00 - api response");
{
    my $received_title;
    my $mock_json = Mojo::File->new("$SAMPLES/hentag/02_search_response.json")->slurp;

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::HentagOnline::get_plugin_logger         = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::HentagOnline::get_json_from_api = sub {
        my ( $ua, $archive_title ) = @_;
        $received_title = $archive_title;
        return $mock_json;
    };

    my %dummyhash = ( file_path => "test" );

    # Since this is calling the sub directly and not in an object context,
    # we pass a dummy string as first parameter to replace the object.
    my %ko_tags = LANraragi::Plugin::Metadata::HentagOnline::get_tags( "", \%dummyhash, 1, 1 );

    my $expected_title = "[Jikahatsudensho (flanvia)] Zange Ana | Confession Hole [English] [Kyuume] [Digital]";
    my $expected_tags =
      "series:girls und panzer, group:circle shakunetsu, artist:sabaku, character:saori takebe, male:dilf, male:facial hair, male:sole male, female:blowjob, female:clothed male nude female, female:focus blowjob, female:handjob, female:prostitution, female:sole female, language:spanish, url:https://e-hentai.org/g/2463143/4f5b5e3e61, url:https://exhentai.org/g/2463143/4f5b5e3e61";
    is( $received_title, $expected_title, "sent correct title to get_json_from_api");
    is( $ko_tags{title}, $expected_title, "correct title" );
    is( $ko_tags{tags},  $expected_tags, "correct tags" );
}

done_testing();
