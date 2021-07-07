# LANraragi::Plugin::Metadata::EHentai
use strict;
use warnings;
use utf8;
use Data::Dumper;

use Cwd qw( abs_path );
use Mojo::JSON qw(decode_json encode_json);
use Mojo::File;

use Test::More;
use Test::Deep;

my ($ROOT) = abs_path(__FILE__) =~ m/(.*)\/tests.+/;
my $SAMPLES = "$ROOT/tests/samples";

my @all_tags = (
    'artist:yatsuki hiyori',
    'male:business suit',
    'male:glasses',
    'female:anal',
    'female:beauty mark',
    'female:big breasts',
    'female:business suit',
    'female:dark skin',
    'female:gyaru',
    'female:hair buns',
    'female:milf',
    'female:nakadashi',
    'female:paizuri',
    'female:pantyhose',
    'female:ponytail',
    'female:schoolgirl uniform',
    'female:stockings',
    'female:sweating',
    'tankoubon',
    'category:manga',
    # additional tags
    'uploader:hobohobo',
    'timestamp:1615623691'
);

use_ok('LANraragi::Plugin::Metadata::EHentai');

note ( 'testing retrieving tags without "additionaltags" ...' );
{
    my $jsonresponse = decode_json( Mojo::File->new("$SAMPLES/eh/001_gid-1866546.json")->slurp );

    my $tags = LANraragi::Plugin::Metadata::EHentai::get_tags_from_json($jsonresponse, 0);

    isa_ok( $tags, 'ARRAY' );
    cmp_bag( $tags, [ @all_tags[0..19] ], 'tag list' );
}

note ( 'testing retrieving tags with "additionaltags" ...' );
{
    my $jsonresponse = decode_json( Mojo::File->new("$SAMPLES/eh/001_gid-1866546.json")->slurp );

    my $tags = LANraragi::Plugin::Metadata::EHentai::get_tags_from_json($jsonresponse, 1);

    isa_ok( $tags, 'ARRAY' );
    cmp_bag( $tags, \@all_tags, 'tag list' );
}

note ( 'testing looking for the language in the DOM ...' );
{
    my $dom = Mojo::DOM->new( Mojo::File->new("$SAMPLES/eh/001_gid-1866546.html")->slurp );

    my $language = LANraragi::Plugin::Metadata::EHentai::get_language_from_dom( $dom );

    is( $language, 'japanese', "language from DOM" );
}

note ( 'testing the existence of a language tags ...' );
{
    ok( ! LANraragi::Plugin::Metadata::EHentai::has_language_tag( [ qw( category:manga tankoubon ) ] ), "no language" );
    ok( ! LANraragi::Plugin::Metadata::EHentai::has_language_tag( [ qw( category:manga language ) ] ), "no language" );
    ok( ! LANraragi::Plugin::Metadata::EHentai::has_language_tag( [ qw( category:manga language: ) ] ), "no language" );
    ok( LANraragi::Plugin::Metadata::EHentai::has_language_tag( [ qw( category:manga language:eng ) ] ), "has language" );
}

done_testing();
