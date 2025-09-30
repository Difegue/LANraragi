use strict;
use warnings;
use utf8;
use Data::Dumper;

use Cwd        qw( getcwd );
use Mojo::JSON qw(decode_json encode_json);
use Mojo::File;

use Test::More;
use Test::Deep;
use Test::Trap;

my $cwd     = getcwd();
my $SAMPLES = "$cwd/tests/samples";
require "$cwd/tests/mocks.pl";

setup_redis_mock();

my @tags_list_from_gallery_no_source = (
    'Artist:Hamao',
    'Parody:Original Work',
    'Magazine:Comic Kairakuten 2020-04',
    'Publisher:FAKKU', 'color',     'schoolgirl outfit',
    'osananajimi',     'unlimited', 'non-h', 'illustration'
);

my @tags_list_from_gallery_with_source = (
    'Artist:Hamao', 'Parody:Original Work', 'Magazine:Comic Kairakuten 2020-04', 'Publisher:FAKKU',
    'color',        'schoolgirl outfit',    'osananajimi',                       'unlimited',
    'non-h',        'illustration',         'source:https://url/to/my/page.html'
);

use_ok('LANraragi::Plugin::Metadata::Fakku');

note("testing searching URL by title ...");

{
    my $html = ( Mojo::File->new("$SAMPLES/fakku/001_search_response.html")->slurp );
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Fakku::get_search_result_dom = sub { return Mojo::DOM->new($html); };
    local *LANraragi::Plugin::Metadata::Fakku::get_plugin_logger     = sub { return get_logger_mock(); };

    my $url = LANraragi::Plugin::Metadata::Fakku::search_for_fakku_url("my wonderful manga");
    is( $url, "https://www.fakku.net/hentai/kairakuten-cover-girls-episode-009-hamao-english", "url check" );
}

note("testing parsing gallery front page no source tag...");

{
    my $html = ( Mojo::File->new("$SAMPLES/fakku/002_gallery_front.html")->slurp );
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Fakku::get_dom_from_fakku = sub { return Mojo::DOM->new($html); };
    local *LANraragi::Plugin::Metadata::Fakku::get_plugin_logger  = sub { return get_logger_mock(); };

    my ( $tags, $title, $summary ) = LANraragi::Plugin::Metadata::Fakku::get_tags_from_fakku("https://url/to/my/page.html");
    cmp_bag( [ split( ', ', $tags ) ], \@tags_list_from_gallery_no_source, "tag check" );
    is( $title,   'Kairakuten Cover Girl\'s Episode 009: Hamao',     "title check" );
    is( $summary, 'Bold baby bold. This is a test summary. Hi mom.', "summary check" );
}

note("testing parsing gallery front page with source tag...");

{
    my $html = ( Mojo::File->new("$SAMPLES/fakku/002_gallery_front.html")->slurp );
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Fakku::get_dom_from_fakku = sub { return Mojo::DOM->new($html); };
    local *LANraragi::Plugin::Metadata::Fakku::get_plugin_logger  = sub { return get_logger_mock(); };

    my ( $tags, $title, $summary ) =
      LANraragi::Plugin::Metadata::Fakku::get_tags_from_fakku( "https://url/to/my/page.html", "", 1 );
    cmp_bag( [ split( ', ', $tags ) ], \@tags_list_from_gallery_with_source, "tag check" );
    is( $title,   'Kairakuten Cover Girl\'s Episode 009: Hamao',     "title check" );
    is( $summary, 'Bold baby bold. This is a test summary. Hi mom.', "summary check" );
}

note("get_tags dies if fakku's cookie doesn't exists");

{
    my $ua_mock = Test::MockObject->new();
    $ua_mock->mock( 'cookie_jar' => sub { return; } );

    my $lrr_info = { 'user_agent' => $ua_mock };

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Fakku::fakku_cookie_exists = sub { return; };
    local *LANraragi::Plugin::Metadata::Fakku::get_plugin_logger   = sub { return get_logger_mock(); };

    # Act
    trap { LANraragi::Plugin::Metadata::Fakku::get_tags( 'dummy', $lrr_info, 0 ); };

    like( $trap->die, qr/^Not logged in to FAKKU/, 'die message' );
}

note("when oneshot_param is defined, use it to connect to fakku");

{
    my $ua_mock = Test::MockObject->new();
    $ua_mock->mock( 'cookie_jar' => sub { return; } );

    my $oneshot_param = 'try-me';
    my $lrr_info      = {
        'user_agent'    => $ua_mock,
        'oneshot_param' => $oneshot_param,
        'archive_title' => 'invalid title',
        'existing_tags' => 'dummy, source:fakku.net/bla'
    };
    my $fakku_URL;

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Fakku::fakku_cookie_exists = sub { return 1; };
    local *LANraragi::Plugin::Metadata::Fakku::get_plugin_logger   = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::Fakku::get_tags_from_fakku = sub {
        ( $fakku_URL, undef, undef ) = @_;
        return ( 'the tags', 'the title', 'the summary' );
    };

    # Act
    my @rdata = LANraragi::Plugin::Metadata::Fakku::get_tags( 'dummy', $lrr_info, 0 );

    is( $fakku_URL, $oneshot_param, 'used oneshot_param' );
}

note("when oneshot_param isn't defined, use tag 'source'");

{
    my $ua_mock = Test::MockObject->new();
    $ua_mock->mock( 'cookie_jar' => sub { return; } );

    my $tag_source = 'fakku.net/bla';
    my $lrr_info   = {
        'user_agent'    => $ua_mock,
        'archive_title' => 'invalid title',
        'existing_tags' => "dummy,source:${tag_source}"
    };
    my $fakku_URL;

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Fakku::fakku_cookie_exists = sub { return 1; };
    local *LANraragi::Plugin::Metadata::Fakku::get_plugin_logger   = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::Fakku::get_tags_from_fakku = sub {
        ( $fakku_URL, undef, undef ) = @_;
        return ( 'the tags', 'the title', 'the summary' );
    };

    # Act
    my @rdata = LANraragi::Plugin::Metadata::Fakku::get_tags( 'dummy', $lrr_info, 0 );

    is( $fakku_URL, $tag_source, 'found \'source:*\' tag' );
}

note("when oneshot_param and tag 'source' aren't useful, search by title");

{
    my $ua_mock = Test::MockObject->new();
    $ua_mock->mock( 'cookie_jar' => sub { return; } );

    my $archive_title = 'current title';
    my $found_url     = 'url from title';
    my $lrr_info      = {
        'user_agent'    => $ua_mock,
        'archive_title' => $archive_title,
        'existing_tags' => "dummy,source:hsite.com/bla"
    };
    my $fakku_URL;
    my $used_title;

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Fakku::fakku_cookie_exists  = sub { return 1; };
    local *LANraragi::Plugin::Metadata::Fakku::get_plugin_logger    = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::Fakku::search_for_fakku_url = sub {
        ( $used_title, undef ) = @_;
        return $found_url;
    };
    local *LANraragi::Plugin::Metadata::Fakku::get_tags_from_fakku = sub {
        ( $fakku_URL, undef, undef ) = @_;
        return ( 'the tags', 'the title', 'the summary' );
    };

    # Act
    my @rdata = LANraragi::Plugin::Metadata::Fakku::get_tags( 'dummy', $lrr_info, 0 );

    is( $used_title, $archive_title, 'title to search' );
    is( $fakku_URL,  $found_url,     'found URL' );
}

note("when no URL is found, die with error");

{
    my $ua_mock = Test::MockObject->new();
    $ua_mock->mock( 'cookie_jar' => sub { return; } );

    my $archive_title = 'current title';
    my $found_url     = 'url from title';
    my $lrr_info      = {
        'user_agent'    => $ua_mock,
        'archive_title' => $archive_title,
        'existing_tags' => "dummy,source:hsite.com/bla"
    };
    my $fakku_URL;
    my $used_title;

    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Fakku::fakku_cookie_exists  = sub { return 1; };
    local *LANraragi::Plugin::Metadata::Fakku::get_plugin_logger    = sub { return get_logger_mock(); };
    local *LANraragi::Plugin::Metadata::Fakku::search_for_fakku_url = sub { return; };

    # Act
    trap { LANraragi::Plugin::Metadata::Fakku::get_tags( 'dummy', $lrr_info, 0 ); };

    like( $trap->die, qr/^No matching FAKKU Gallery Found/, 'die message' );
}

done_testing();
