# LANraragi::Plugin::Metadata::GalleryDL
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

setup_redis_mock();

use_ok('LANraragi::Plugin::Metadata::GalleryDL');

sub gallerydl_test {

    my ( $jsonpath ) = @_;

    # Copy the gallerydl sample json to a temporary directory as it's deleted once parsed
    my ( $fh, $filename ) = tempfile();
    cp( $SAMPLES . $jsonpath, $fh );

    # Mock LANraragi::Utils::Archive's subs to return the temporary sample JSON
    # Since we're using exports, the methods are under the plugin's namespace.
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::GalleryDL::get_plugin_logger         = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::GalleryDL::extract_file_from_archive = sub { $filename };
    local *LANraragi::Plugin::Metadata::GalleryDL::is_file_in_archive        = sub { 1 };

    my %dummyhash = ( something => 42, file_path => "dummy" );

    # Since this is calling the sub directly and not in an object context,
    # we pass a dummy string as first parameter to replace the object.
    my %gallerydltags =
        trap { LANraragi::Plugin::Metadata::GalleryDL::get_tags( "", \%dummyhash ); };
    return %gallerydltags;

}

#Testing the processing of an array of tag strings with no values, just keys. Also test absence of source/category metadata
note("gallerydl-arraysingletags, no source/category Tests");
{
    my %gallerydltags = gallerydl_test( "/gallerydl/gallerydl_arraysingletags_sample.json" );

    is( $gallerydltags{title},
        "Quickie Gift",
        "title parsing test 1/4"
    );

    is( index($gallerydltags{tags}, "source"), -1, "no source returned 2/4"); #We haven't inserted a source tag by mistake somehow

    is( index($gallerydltags{tags}, "category"), -1, "no category returned 3/4"); #We haven't inserted a category tag either

    is( $gallerydltags{tags},
        "anthro, candy, cute, furry, krill, sea bunny shrimp, shrimp, sweet, treats",
        "tags parsing test 4/4"
    );
}

#Testing the processing of an array of key:value tag strings
note("gallerydl-arrayfulltags Tests");
{
    my %gallerydltags = gallerydl_test( "/gallerydl/gallerydl_arrayfulltags_sample.json" );

    is( $gallerydltags{title},
        "(C91) [HitenKei (Hiten)] R.E.I.N.A [Chinese] [無邪気漢化組]",
        "title parsing test 1/2"
    );
    #We don't need separate tests for validating the category/source tag parsing because that's built into testing the full list of tags
    is( $gallerydltags{tags},
        "language:chinese, language:translated, parody:original, group:hitenkei, artist:hiten, male:sole male, female:defloration, female:pantyhose, female:sole female, female:x-ray, category:exhentai, source:https://exhentai.org/g/1017975/49b3c275a1",
        "tags parsing test 2/2"
    );
}

#Testing the processing of multi-value hash-formatted tags
note("gallerydl-hashtags Tests");
{
    my %gallerydltags = gallerydl_test( "/gallerydl/gallerydl_hashtags_sample.json" );

    is( $gallerydltags{title},
        "Tree of Life [Zummeng]",
        "title parsing test 1/2"
    );
    #We don't need separate tests for validating the category/source tag parsing because that's built into testing the full list of tags
    is( $gallerydltags{tags},
        "artist:zummeng, character:leopold_(zummeng), character:miralle, general:anthro, general:big_breasts, general:blood, general:blood_from_wound, general:bodily_fluids, general:breasts, general:bruised, general:bruised_belly, general:cave, general:cavern, general:colored_fire, general:duo, general:female, general:fire, general:laser, general:male, general:muscular, general:muscular_anthro, general:muscular_male, general:navel, general:plant, general:purple_fire, general:smoke, general:snow, general:snowing, general:snowstorm, general:tree, general:wide_hips, general:wounded, meta:2024, meta:comic, meta:hi_res, species:domestic_cat, species:felid, species:feline, species:felis, species:lion, species:mammal, species:pantherine, category:e621, source:https://e621.net/pools/19303",
        "tags parsing test 2/2"
    );
}

note("gallerydl no tags in file");
{
    my %gallerydltags = gallerydl_test( "/gallerydl/gallerydl_broken.json" );

    is( $gallerydltags{title}, undef, "no title returned 1/3");
    is( $gallerydltags{tags}, undef, "no tags returned 2/3");
    isnt( $gallerydltags{error}, undef, "Proper error returned 3/3");
}

done_testing();
