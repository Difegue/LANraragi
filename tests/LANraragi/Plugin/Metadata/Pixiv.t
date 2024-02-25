use strict;
use warnings;

use Cwd qw( getcwd );
use Mojo::JSON qw(decode_json encode_json);
use Mojo::File;

use Test::More;
use Test::Deep;

my $cwd     = getcwd();
my $SAMPLES = "$cwd/tests/samples";
require "$cwd/tests/mocks.pl";
setup_redis_mock();

use_ok('LANraragi::Plugin::Metadata::Pixiv');

note("Start Pixiv test modules...");

note("testing illustration ID extraction from one-shot parameter");

{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Pixiv::get_plugin_logger        = sub { return get_logger_mock(); };
    
    # illustration ID extraction SHOULD work for positive examples, and SHOULD NOT work for negative examples.

    my @positive_examples = (
        "pixiv.net/en/artworks/123456",
        "https://www.pixiv.net/en/artworks/123456",
        "www.pixiv.net/artworks/123456",
        "123456"
    );

    my @negative_examples = (
        "e-hentai.org/g/123456/abcdef",
        "abc1234"
    );

    for my $positive_example (@positive_examples) {
        my %lrr_info = ( oneshot_param => $positive_example );
        my $predicted_illust_id = LANraragi::Plugin::Metadata::Pixiv::find_illust_id($lrr_info);
        is( $predicted_illust_id, "123456", "positive ID extraction (param)" );
    }

    for my $negative_example (@negative_examples) {
        my %lrr_info = ( oneshot_param => $negative_example );
        my $predicted_illust_id = LANraragi::Plugin::Metadata::Pixiv::find_illust_id($lrr_info);
        is( $predicted_illust_id, "", 'negative ID extraction (param)' );
    }

}

note("testing illustration ID extraction from file");

{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Pixiv::get_plugin_logger        = sub { return get_logger_mock(); };

    # illustration ID extraction SHOULD work for positive examples, and SHOULD NOT work for negative examples.

    my @positive_examples = (
        "{123456} dummy title",
        "{123456}.zip",
        "pixiv_{123456} dummy title",
    );

    my @negative_examples = {
        "ehentai_{123456} dummy title",
    };

    for my $positive_example (@positive_examples) {
        my %lrr_info = ( archive_title => $positive_example );
        my $predicted_illust_id = LANraragi::Plugin::Metadata::Pixiv::find_illust_id($lrr_info);
        is( $predicted_illust_id, "123456", "positive ID extraction (file)" );
    }

    for my $negative_example (@negative_examples) {
        my %lrr_info = ( archive_title => $negative_example );
        my $predicted_illust_id = LANraragi::Plugin::Metadata::Pixiv::find_illust_id($lrr_info);
        is( $predicted_illust_id, "", 'negative ID extraction (file)' );
    }

}

note("testing JSON body extraction from HTML file");

{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Pixiv::get_plugin_logger        = sub { return get_logger_mock(); };

    my $body = Mojo::File -> new("$SAMPLES/pixiv/illust.html") -> slurp;
    my $json = LANraragi::Plugin::Metadata::Pixiv::get_json_from_html($body);

    isa_ok( $json, 'HASH', 'json' );
    is(
        $json -> {illust} -> {114245433} -> {illustId},
        "114245433",
        "Illustration ID"
    );

}

note("testing metadata extraction from JSON object (Illust)");

{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Pixiv::get_plugin_logger        = sub { return get_logger_mock(); };

    my $body = Mojo::File -> new("$SAMPLES/pixiv/illust.html") -> slurp;
    my $tag_languages_str = "";
    my $json = LANraragi::Plugin::Metadata::Pixiv::get_json_from_html($body);
    my %hashdata = LANraragi::plugin::Metadata::Pixiv::get_hash_metadata_from_json( $json, "114245433", $tag_languages_str);

    is(
        $hashdata{'tags'},
        "公式企画, 企画目録, MIKU, 初音ミク, HatsuneMiku, mikuexpo10th, source:https://pixiv.net/artworks/114245433, user_id:11, artist:pixiv事務局, date_created:1702919363, date_uploaded:1703505966",
        "Match illustration metadata"
    );

}

note("testing metadata extraction from JSON object (Manga)");

{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Pixiv::get_plugin_logger        = sub { return get_logger_mock(); };

    my $body = Mojo::File -> new("$SAMPLES/pixiv/manga.html") -> slurp;
    my $tag_languages_str = "";
    my $json = LANraragi::Plugin::Metadata::Pixiv::get_json_from_html($body);
    my %hashdata = LANraragi::plugin::Metadata::Pixiv::get_hash_metadata_from_json( $json, "114245433", $tag_languages_str);

    is(
        $hashdata{'tags'},
        "漫画, pixivコミック, コミックELMO, なつめとなつめ, source:https://pixiv.net/artworks/116253902, user_id:11, artist:pixiv事務局, date_created:1708484400, date_uploaded:1708484400",
        "Match manga metadata"
    );

}

note("testing language-specific metadata extraction (en+jp)");

{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Pixiv::get_plugin_logger        = sub { return get_logger_mock(); };

    my $body = Mojo::File -> new("$SAMPLES/pixiv/illust.html") -> slurp;
    my $tag_languages_str = "jp, en";
    my $json = LANraragi::Plugin::Metadata::Pixiv::get_json_from_html($body);
    my %hashdata = LANraragi::plugin::Metadata::Pixiv::get_hash_metadata_from_json( $json, "114245433", $tag_languages_str);

    is(
        $hashdata{'tags'},
        "公式企画, official project, 企画目録, MIKU, 初音ミク, hatsune miku, HatsuneMiku, mikuexpo10th, source:https://pixiv.net/artworks/114245433, user_id:11, artist:pixiv事務局, date_created:1702919363, date_uploaded:1703505966",
        "Match illustration metadata"
    );

}

note("Finish Pixiv test modules.");