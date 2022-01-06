# LANraragi::Plugin::Metadata::Koromo
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

use_ok('LANraragi::Plugin::Metadata::Koromo');

note("Koromo Tests");
{
    # Copy the koromo sample json to a temporary directory as it's deleted once parsed
    my ( $fh, $filename ) = tempfile();
    cp( $SAMPLES . "/koromo/koromo_sample.json", $fh );

    # Mock LANraragi::Utils::Archive's subs to return the temporary sample JSON
    # Since we're using exports, the methods are under the plugin's namespace.
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Koromo::get_plugin_logger         = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::Koromo::extract_file_from_archive = sub { $filename };
    local *LANraragi::Plugin::Metadata::Koromo::is_file_in_archive        = sub { 1 };

    my %dummyhash = ( something => 22, file_path => "test" );

    # Since this is calling the sub directly and not in an object context,
    # we pass a dummy string as first parameter to replace the object.
    my %ko_tags = trap { LANraragi::Plugin::Metadata::Koromo::get_tags( "", \%dummyhash, 1 ); };

    my $expected_tags =
      "Teacher, Schoolgirl Outfit, Cheating, Hentai, Ahegao, Creampie, Uncensored, Condom, Unlimited, Heart Pupils, Love Hotel, series:Original Work, artist:▲ Chimaki, language:English, source:https://www.fakku.net/hentai/after-school-english_1632947200";
    is( $ko_tags{title}, "After School", "Koromo parsing test 1/2" );
    is( $ko_tags{tags},  $expected_tags, "Koromo parsing test 2/2" );
}

done_testing();
