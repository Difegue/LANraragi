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

note("eze-lite Tests, with save original title but no original title exist");
{
    # Copy the eze sample json to a temporary directory as it's deleted once parsed
    my ( $fh, $filename ) = tempfile();
    cp( $SAMPLES . "/eze/eze_lite_sample.json", $fh );

    # Mock LANraragi::Utils::Archive's subs to return the temporary sample JSON
    # Since we're using exports, the methods are under the plugin's namespace.
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Eze::get_plugin_logger         = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::Eze::extract_file_from_archive = sub { $filename };
    local *LANraragi::Plugin::Metadata::Eze::is_file_in_archive        = sub { 1 };

    my %dummyhash = ( something => 22, file_path => "test" );
    my $save_title = 1;
    my $origin_title = 1;
    my $additional_tags = 1;

    # Since this is calling the sub directly and not in an object context,
    # we pass a dummy string as first parameter to replace the object.
    my %ezetags = trap { LANraragi::Plugin::Metadata::Eze::get_tags( "", \%dummyhash, $save_title, $origin_title, $additional_tags ); };

    my $ezetags =
      "artist:mitarashi kousei, character:akiko minase, character:yuuichi aizawa, female:aunt, female:lingerie, female:sole female, group:mitarashi club, language:english, language:translated, male:sole male, misc:multi-work series, parody:kanon, timestamp:1517540580, source:website.org/g/1179590/7c5815c77b";
    is( $ezetags{title},
        "(C72) [Mitarashi Club (Mitarashi Kousei)] Akiko-san to Issho (Kanon) [English] [Belldandy100] [Decensored]",
        "eze-lite, with save original title but no original title exist parsing test 1/2"
    );
    is( $ezetags{tags}, $ezetags, "eze-lite, with save original title but no original title exist parsing test 2/2" );
}

note("eze-full Tests without 'save_title', without 'additional_tags'");
{
    # Copy the eze sample json to a temporary directory as it's deleted once parsed
    my ( $fh, $filename ) = tempfile();
    cp( $SAMPLES . "/eze/eze_full_sample.json", $fh );

    # Mock LANraragi::Utils::Archive's subs to return the temporary sample JSON
    # Since we're using exports, the methods are under the plugin's namespace.
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Eze::get_plugin_logger         = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::Eze::extract_file_from_archive = sub { $filename };
    local *LANraragi::Plugin::Metadata::Eze::is_file_in_archive        = sub { 1 };

    my %dummyhash = ( something => 22, file_path => "test" );
    my $save_title = 0;
    my $origin_title = 0;
    my $additional_tags = 0;

    # Since this is calling the sub directly and not in an object context,
    # we pass a dummy string as first parameter to replace the object.
    my %ezetags = trap { LANraragi::Plugin::Metadata::Eze::get_tags( "", \%dummyhash, $save_title, $origin_title, $additional_tags ); };

    my $ezetags =
      "artist:hiten, female:defloration, female:pantyhose, female:sole female, group:hitenkei, language:chinese, language:translated, male:sole male, parody:original, category:doujinshi, source:exhentai.org/g/1017975/49b3c275a1";
    is( !$ezetags{title},
        1,
        "eze-full without 'save_title', without 'additional_tags' parsing test 1/2"
    );
    is( $ezetags{tags}, $ezetags, "eze-full without 'save_title', without 'additional_tags' parsing test 2/2" );
}

note("eze-full Tests with 'save_title', with 'additional_tags'");
{
    # Copy the eze sample json to a temporary directory as it's deleted once parsed
    my ( $fh, $filename ) = tempfile();
    cp( $SAMPLES . "/eze/eze_full_sample.json", $fh );

    # Mock LANraragi::Utils::Archive's subs to return the temporary sample JSON
    # Since we're using exports, the methods are under the plugin's namespace.
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Eze::get_plugin_logger         = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::Eze::extract_file_from_archive = sub { $filename };
    local *LANraragi::Plugin::Metadata::Eze::is_file_in_archive        = sub { 1 };

    my %dummyhash = ( something => 22, file_path => "test" );
    my $save_title = 1;
    my $origin_title = 0;
    my $additional_tags = 1;

    # Since this is calling the sub directly and not in an object context,
    # we pass a dummy string as first parameter to replace the object.
    my %ezetags = trap { LANraragi::Plugin::Metadata::Eze::get_tags( "", \%dummyhash, $save_title, $origin_title, $additional_tags ); };

    my $ezetags =
      "artist:hiten, female:defloration, female:pantyhose, female:sole female, group:hitenkei, language:chinese, language:translated, male:sole male, parody:original, category:doujinshi, uploader:cocy, timestamp:1484412360, source:exhentai.org/g/1017975/49b3c275a1";
    is( $ezetags{title},
        "(C91) [HitenKei (Hiten)] R.E.I.N.A [Chinese] [無邪気漢化組]",
        "eze-full with 'save_title', with 'additional_tags' parsing test 1/2"
    );
    is( $ezetags{tags}, $ezetags, "eze-full with 'save_title', with 'additional_tags' parsing test 2/2" );
}

note("eze-full Tests with save original title, with 'additional_tags'");
{
    # Copy the eze sample json to a temporary directory as it's deleted once parsed
    my ( $fh, $filename ) = tempfile();
    cp( $SAMPLES . "/eze/eze_full_sample.json", $fh );

    # Mock LANraragi::Utils::Archive's subs to return the temporary sample JSON
    # Since we're using exports, the methods are under the plugin's namespace.
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Eze::get_plugin_logger         = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::Eze::extract_file_from_archive = sub { $filename };
    local *LANraragi::Plugin::Metadata::Eze::is_file_in_archive        = sub { 1 };

    my %dummyhash = ( something => 22, file_path => "test" );
    my $save_title = 1;
    my $origin_title = 1;
    my $additional_tags = 1;

    # Since this is calling the sub directly and not in an object context,
    # we pass a dummy string as first parameter to replace the object.
    my %ezetags = trap { LANraragi::Plugin::Metadata::Eze::get_tags( "", \%dummyhash, $save_title, $origin_title, $additional_tags ); };

    my $ezetags =
      "artist:hiten, female:defloration, female:pantyhose, female:sole female, group:hitenkei, language:chinese, language:translated, male:sole male, parody:original, category:doujinshi, uploader:cocy, timestamp:1484412360, source:exhentai.org/g/1017975/49b3c275a1";
    is( $ezetags{title},
        "(C91) [HitenKei (Hiten)] R.E.I.N.A [中国翻訳]",
        "eze-full with save original title, with 'additional_tags' parsing test 1/2"
    );
    is( $ezetags{tags}, $ezetags, "eze-full with save original title, with 'additional_tags' parsing test 2/2" );
}

done_testing();
