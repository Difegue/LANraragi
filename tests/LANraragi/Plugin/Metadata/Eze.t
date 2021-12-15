# LANraragi::Plugin::Metadata::Eze
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

use_ok('LANraragi::Plugin::Metadata::Eze');

note("eze Tests");
{
    # Copy the eze sample json to a temporary directory as it's deleted once parsed
    my ( $fh, $filename ) = tempfile();
    cp( $SAMPLES . "/eze/eze_sample.json", $fh );

    # Mock LANraragi::Utils::Archive's subs to return the temporary sample JSON
    # Since we're using exports, the methods are under the plugin's namespace.
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Eze::get_plugin_logger         = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::Eze::extract_file_from_archive = sub { $filename };
    local *LANraragi::Plugin::Metadata::Eze::is_file_in_archive        = sub { 1 };

    my %dummyhash = ( something => 22, file_path => "test" );

    # Since this is calling the sub directly and not in an object context,
    # we pass a dummy string as first parameter to replace the object.
    my %ezetags = trap { LANraragi::Plugin::Metadata::Eze::get_tags( "", \%dummyhash, 1 ); };

    my $ezetags =
      "artist:mitarashi kousei, character:akiko minase, character:yuuichi aizawa, female:aunt, female:lingerie, female:sole female, group:mitarashi club, language:english, language:translated, male:sole male, misc:multi-work series, parody:kanon, source: website.org/g/1179590/7c5815c77b";
    is( $ezetags{title},
        "(C72) [Mitarashi Club (Mitarashi Kousei)] Akiko-san to Issho (Kanon) [English] [Belldandy100] [Decensored]",
        "eze parsing test 1/2"
    );
    is( $ezetags{tags}, $ezetags, "eze parsing test 2/2" );
}

done_testing();
