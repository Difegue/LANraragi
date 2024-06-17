use strict;
use warnings;
use utf8;
use Data::Dumper;

use Cwd qw( getcwd );
use Mojo::JSON qw(decode_json encode_json);
use Mojo::File;

use Test::More;
use Test::Deep;

my $cwd = getcwd();
my $SAMPLES = "$cwd/tests/samples";
require "$cwd/tests/mocks.pl";

my @tags_list= (
    'full censorship', 'female:sole female', 'male:sole male', 'artist:kemuri haku', 'female:tall girl', 
    'female:cunnilingus', 'male:shotacon', 'female:defloration', 'female:nakadashi', 'female:x-ray',
    'female:big breasts', 'language:translated', 'language:english'
);
my @tags_list_extra= (
    'other:full censorship', 'female:sole female', 'male:sole male', 'artist:kemuri haku', 'female:tall girl', 
    'female:cunnilingus', 'male:shotacon', 'female:defloration', 'female:nakadashi', 'female:x-ray',
    'female:big breasts', 'language:translated', 'language:english', 'category:manga', 'download:/archive/27240/download/',
    'gallery:23532', 'timestamp:1521357552', 'source:chaika'
);

use_ok('LANraragi::Plugin::Metadata::Chaika');

note ( 'testing retrieving tags by ID ...' );

{
    my $json = decode_json( Mojo::File->new("$SAMPLES/chaika/001_gid_27240.json")->slurp );

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Chaika::get_json_from_chaika = sub { return $json; };

    my ( $tags, $title ) = LANraragi::Plugin::Metadata::Chaika::tags_from_chaika_id( "my-type", 123 );

    is($title, $json->{title}, 'gallery title');
    cmp_bag( [ split( ', ', $tags ) ] , \@tags_list, 'gallery tag list');
}

note ( 'testing retrieving tags with original title...' );
{
    my $json = decode_json( Mojo::File->new("$SAMPLES/chaika/001_gid_27240.json")->slurp );

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Chaika::get_json_from_chaika = sub { return $json; };

    my $jpntitle = 1;

    my ( $tags, $title ) = LANraragi::Plugin::Metadata::Chaika::tags_from_chaika_id( "my-type", 123, 0, 0, '', $jpntitle );

    is($title, $json->{title_jpn}, 'gallery original title');
    cmp_bag( [ split( ', ', $tags ) ] , \@tags_list, 'gallery tag list');
}

note ( 'testing retrieving tags by SHA1 ...' );

{
    my $json_by_sha1 = decode_json( Mojo::File->new("$SAMPLES/chaika/002_sha1_response.json")->slurp );
    my $json = decode_json( Mojo::File->new("$SAMPLES/chaika/001_gid_27240.json")->slurp );
    my @type_params = ();

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Chaika::get_plugin_logger = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::Chaika::get_json_from_chaika = sub {
        my ( $type, $value ) = @_;
        push( @type_params, $type );
        return ( $type eq 'sha1' ) ? $json_by_sha1 : $json;
    };

    my ( $tags, $title ) = LANraragi::Plugin::Metadata::Chaika::tags_from_sha1( "my-hash" );

    is($title, $json->{title}, 'gallery title');
    cmp_bag( [ split( ', ', $tags ) ] , \@tags_list, 'gallery tag list');
    cmp_deeply( \@type_params, [ 'sha1' ], 'API call sequence');
}

note ( 'testing retrieving tags by SHA1 with additional tags ...' );

{
    my $json_by_sha1 = decode_json( Mojo::File->new("$SAMPLES/chaika/002_sha1_response.json")->slurp );
    my $json = decode_json( Mojo::File->new("$SAMPLES/chaika/001_gid_27240.json")->slurp );
    my @type_params = ();

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Chaika::get_plugin_logger = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::Chaika::get_json_from_chaika = sub {
        my ( $type, $value ) = @_;
        push( @type_params, $type );
        return ( $type eq 'sha1' ) ? $json_by_sha1 : $json;
    };

    my $addextra = 1;
    my $addother = 1;
    my $addsource = 'chaika';
    my ( $tags, $title ) = LANraragi::Plugin::Metadata::Chaika::tags_from_sha1(
        "my-hash",
        $addextra,
        $addother,
        $addsource
    );

    is($title, $json->{title}, 'gallery title');
    cmp_bag( [ split( ', ', $tags ) ] , \@tags_list_extra, 'gallery tag list');
    cmp_deeply( \@type_params, [ 'sha1' ], 'API call sequence');
}

done_testing();
