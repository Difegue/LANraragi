use strict;
use warnings;
use utf8;
use Data::Dumper;

use Cwd qw( getcwd );
use Mojo::JSON qw(decode_json encode_json);
use Mojo::File;
use Mojolicious;
use LANraragi::Model::Config;

use Test::More;
use Test::Deep;
use Test::MockObject;

my $cwd = getcwd();
my $SAMPLES = "$cwd/tests/samples";

my $mock_log = Test::MockObject->new();
$mock_log->mock( 'debug', sub { } );
$mock_log->mock( 'info', sub { } );

my @tags_list_from_gallery = (
    'female:sole female', 'male:sole male', 'artist:kemuri haku', 'full censorship',
    'male:shotacon', 'female:defloration', 'female:nakadashi', 'female:big breasts',
    'language:translated', 'language:english'
);

my @tags_list_from_sha1 = (
    'ahegao', 'artist:ao banana', 'blowjob', 'busty', 'creampie', 'dark skin', 'eyebrows',
    'heart pupils', 'hentai', 'language:english', 'magazine:comic shitsurakuten 2016-04',
    'muscles', 'parody:original work', 'publisher:fakku', 'swimsuit', 'tanlines', 'uncensored',
    'unlimited', 'x-ray'
);

use_ok('LANraragi::Plugin::Metadata::Chaika');

note ( 'testing retrieving tags by ID ...' );

{
    my $json = decode_json( Mojo::File->new("$SAMPLES/chaika/001_gid_27240.json")->slurp );

    no warnings 'once', 'redefine';
    *LANraragi::Plugin::Metadata::Chaika::get_json_from_chaika = sub { return $json; };
    *LANraragi::Plugin::Metadata::Chaika::get_local_logger = sub { return $mock_log; };

    my ( $tags, $title ) = LANraragi::Plugin::Metadata::Chaika::tags_from_chaika_id( "my-type", 123 );

    is($title, $json->{title}, 'gallery title');
    cmp_bag( [ split( ', ', $tags ) ] , \@tags_list_from_gallery, 'gallery tag list');
}

note ( 'testing retrieving tags by SHA1 when "gallery" has "tags" ...' );

{
    my $json_by_sha1 = [ { 'id' => '666' } ];
    my $json = decode_json( Mojo::File->new("$SAMPLES/chaika/001_gid_27240.json")->slurp );
    my @type_params = ();

    no warnings 'once', 'redefine';
    *LANraragi::Plugin::Metadata::Chaika::get_local_logger = sub { return $mock_log; };
    *LANraragi::Plugin::Metadata::Chaika::get_json_from_chaika = sub {
        my ( $type, $value ) = @_;
        push( @type_params, $type );
        return ( $type eq 'sha1' ) ? $json_by_sha1 : $json;
    };

    my ( $tags, $title ) = LANraragi::Plugin::Metadata::Chaika::tags_from_sha1( "my-hash" );

    is($title, $json->{title}, 'gallery title');
    cmp_bag( [ split( ', ', $tags ) ] , \@tags_list_from_gallery, 'gallery tag list');
    cmp_deeply( \@type_params, [ 'sha1', 'gallery' ], 'API call sequence');
}

note ( 'testing retrieving tags by SHA1 when "gallery" has no "tags" ...' );

{
    my $json = decode_json( Mojo::File->new("$SAMPLES/chaika/002_sha1_response.json")->slurp );
    my @type_params = ();

    no warnings 'once', 'redefine';
    *LANraragi::Plugin::Metadata::Chaika::get_local_logger = sub { return $mock_log; };
    *LANraragi::Plugin::Metadata::Chaika::get_json_from_chaika = sub {
        my ( $type, $value ) = @_;
        push( @type_params, $type );
        return ( $type eq 'sha1' ) ? $json : {};
    };

    my ( $tags, $title ) = LANraragi::Plugin::Metadata::Chaika::tags_from_sha1( "my-hash" );

    is($title, $json->[0]->{title}, 'gallery title');
    cmp_bag( [ split( ', ', $tags ) ] , \@tags_list_from_sha1, 'gallery tag list');
    cmp_deeply( \@type_params, [ 'sha1', 'gallery' ], 'API call sequence');
}

done_testing();
