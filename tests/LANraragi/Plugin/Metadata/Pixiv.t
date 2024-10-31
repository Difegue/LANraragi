use strict;
use warnings;
use utf8;
use Data::Dumper;

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

        my $lrr_info = { oneshot_param => $positive_example };
        my $predicted_illust_id = LANraragi::Plugin::Metadata::Pixiv::find_illust_id( $lrr_info );
        is($predicted_illust_id, "123456", "positive example oneshot: $positive_example");

    }

    for my $negative_example (@negative_examples) {

        my $lrr_info = { oneshot_param => $negative_example };
        my $predicted_illust_id = LANraragi::Plugin::Metadata::Pixiv::find_illust_id( $lrr_info );
        is($predicted_illust_id, '', "negative example oneshot: $negative_example");

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

    my @negative_examples = (
        "ehentai_{123456} dummy title",
    );

    for my $positive_example (@positive_examples) {

        my $lrr_info = { archive_title => $positive_example };
        my $predicted_illust_id = LANraragi::Plugin::Metadata::Pixiv::find_illust_id($lrr_info);
        is( $predicted_illust_id, "123456", "positive example file: $positive_example" );
    }

    for my $negative_example (@negative_examples) {

        my $lrr_info = { archive_title => $negative_example };
        my $predicted_illust_id = LANraragi::Plugin::Metadata::Pixiv::find_illust_id($lrr_info);
        is( $predicted_illust_id, '', "negative example file: $negative_example" );
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
        "JSON match illustration ID"
    );

}

note("testing metadata extraction from JSON object (Illust)");

{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Pixiv::get_plugin_logger        = sub { return get_logger_mock(); };

    my $body = Mojo::File -> new("$SAMPLES/pixiv/illust.html") -> slurp;
    my $tag_languages_str = '';
    my $json = LANraragi::Plugin::Metadata::Pixiv::get_json_from_html($body);
    my %dto = LANraragi::Plugin::Metadata::Pixiv::get_illustration_dto_from_json( $json, "114245433" );
    
    my $expected_title = 'HATSUNE MIKU EXPO 10th イラコン開催！';
    my @expected_pixiv_tags = ('公式企画', '企画目録', 'MIKU', '初音ミク', 'HatsuneMiku', 'mikuexpo10th');
    my @expected_manga_data = ();
    my @expected_user_id = ('pixiv_user_id:11');
    my @expected_artist = ('artist:pixiv事務局');
    my @expected_create_date = ('date_created:1702628640');
    my @expected_upload_date = ('date_uploaded:1702628640');

    my @actual_pixiv_tags = LANraragi::Plugin::Metadata::Pixiv::get_pixiv_tags_from_dto( \%dto, $tag_languages_str );
    my @actual_manga_data = LANraragi::Plugin::Metadata::Pixiv::get_manga_data_from_dto( \%dto );
    my @actual_user_id = LANraragi::Plugin::Metadata::Pixiv::get_user_id_from_dto( \%dto );
    my @actual_artist = LANraragi::Plugin::Metadata::Pixiv::get_artist_from_dto( \%dto );
    my @actual_create_date = LANraragi::Plugin::Metadata::Pixiv::get_create_date_from_dto( \%dto );
    my @actual_upload_date = LANraragi::Plugin::Metadata::Pixiv::get_upload_date_from_dto( \%dto );

    cmp_deeply(\@actual_pixiv_tags, \@expected_pixiv_tags , 'pixiv tags equal illust');
    cmp_deeply(\@actual_manga_data, \@expected_manga_data , 'No manga data in illust');
    cmp_deeply(\@actual_user_id, \@expected_user_id, 'user ID equal');
    cmp_deeply(\@actual_artist, \@expected_artist, 'artists equal');
    cmp_deeply(\@actual_create_date, \@expected_create_date, 'create dates equal');
    cmp_deeply(\@actual_upload_date, \@expected_upload_date, 'upload dates equal');

}

note("testing metadata extraction from JSON object (Manga)");

{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Pixiv::get_plugin_logger        = sub { return get_logger_mock(); };

    my $body = Mojo::File -> new("$SAMPLES/pixiv/manga_1.html") -> slurp;
    my $tag_languages_str = '';
    my $json = LANraragi::Plugin::Metadata::Pixiv::get_json_from_html($body);
    my %dto = LANraragi::Plugin::Metadata::Pixiv::get_illustration_dto_from_json( $json, "116253902" );

    my @expected_pixiv_tags = ('漫画', 'pixivコミック', 'コミックELMO', 'なつめとなつめ');
    my @expected_manga_data = ();

    my @actual_pixiv_tags = LANraragi::Plugin::Metadata::Pixiv::get_pixiv_tags_from_dto( \%dto, $tag_languages_str );
    my @actual_manga_data = LANraragi::Plugin::Metadata::Pixiv::get_manga_data_from_dto( \%dto );

    cmp_deeply(\@actual_pixiv_tags, \@expected_pixiv_tags , 'pixiv tags equal manga');
    cmp_deeply(\@actual_manga_data, \@expected_manga_data , 'No manga data in manga');

}

note("testing metadata extraction from JSON object (Manga with manga data)");

{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Pixiv::get_plugin_logger        = sub { return get_logger_mock(); };

    my $body = Mojo::File -> new("$SAMPLES/pixiv/manga_2.html") -> slurp;
    my $tag_languages_str = '';
    my $json = LANraragi::Plugin::Metadata::Pixiv::get_json_from_html($body);
    my %dto = LANraragi::Plugin::Metadata::Pixiv::get_illustration_dto_from_json( $json, "103301948" );

    my @expected_pixiv_tags = ('漫画', '創作', 'オリジナル', '安定の森のおかん力', '愛すべき馬鹿達', '作者の生存確認', 'ラブの波動', '第三話参照', 'オリジナル20000users入り', 'ラブコメの波動を感じる');
    my @expected_manga_data = ("pixiv_series_id:90972", "pixiv_series_title:不穏そうな学校", "pixiv_series_order:13");

    my @actual_pixiv_tags = LANraragi::Plugin::Metadata::Pixiv::get_pixiv_tags_from_dto( \%dto, $tag_languages_str );
    my @actual_manga_data = LANraragi::Plugin::Metadata::Pixiv::get_manga_data_from_dto( \%dto );

    cmp_deeply(\@actual_pixiv_tags, \@expected_pixiv_tags , 'pixiv tags equal manga');
    cmp_deeply(\@actual_manga_data, \@expected_manga_data , 'No manga data in manga');

}

note("testing language-specific metadata extraction (en+jp)");

{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Pixiv::get_plugin_logger        = sub { return get_logger_mock(); };

    my $body = Mojo::File -> new("$SAMPLES/pixiv/illust.html") -> slurp;
    my $tag_languages_str = 'jp, en';
    my $json = LANraragi::Plugin::Metadata::Pixiv::get_json_from_html($body);
    my %dto = LANraragi::Plugin::Metadata::Pixiv::get_illustration_dto_from_json( $json, "114245433" );

    my @expected_pixiv_tags = ('公式企画', 'official project', '企画目録', 'MIKU', '初音ミク', 'hatsune miku', 'HatsuneMiku', 'mikuexpo10th');
    my @actual_pixiv_tags = LANraragi::Plugin::Metadata::Pixiv::get_pixiv_tags_from_dto( \%dto, $tag_languages_str );

    cmp_deeply(\@actual_pixiv_tags, \@expected_pixiv_tags , 'pixiv tags equal illust en+jp');

}

note("testing summary extraction from illust");

{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Pixiv::get_plugin_logger        = sub { return get_logger_mock(); };

    my $body = Mojo::File -> new("$SAMPLES/pixiv/illust.html") -> slurp;
    my $json = LANraragi::Plugin::Metadata::Pixiv::get_json_from_html($body);
    my %dto = LANraragi::Plugin::Metadata::Pixiv::get_illustration_dto_from_json( $json, "114245433" );

    my $expected_pixiv_summary = Mojo::File -> new("$SAMPLES/pixiv/illust_pixiv_comment_unescaped.txt") -> slurp('UTF-8');
    my $actual_pixiv_summary = LANraragi::Plugin::Metadata::Pixiv::get_summary_from_dto( \%dto );

    is( $actual_pixiv_summary, $expected_pixiv_summary, "illust pixiv summary equal" );

}

note("testing summary extraction from manga 1");

{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Pixiv::get_plugin_logger        = sub { return get_logger_mock(); };

    my $body = Mojo::File -> new("$SAMPLES/pixiv/illust.html") -> slurp;
    my $json = LANraragi::Plugin::Metadata::Pixiv::get_json_from_html($body);
    my %dto = LANraragi::Plugin::Metadata::Pixiv::get_illustration_dto_from_json( $json, "116253902" );

    my $expected_pixiv_summary = Mojo::File -> new("$SAMPLES/pixiv/manga_1_pixiv_comment_unescaped.txt") -> slurp('UTF-8');
    my $actual_pixiv_summary = LANraragi::Plugin::Metadata::Pixiv::get_summary_from_dto( \%dto );

    is( $actual_pixiv_summary, $expected_pixiv_summary, "manga 1 pixiv summary equal" );

}

note("testing summary extraction from manga 2");

{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Pixiv::get_plugin_logger        = sub { return get_logger_mock(); };

    my $body = Mojo::File -> new("$SAMPLES/pixiv/illust.html") -> slurp;
    my $json = LANraragi::Plugin::Metadata::Pixiv::get_json_from_html($body);
    my %dto = LANraragi::Plugin::Metadata::Pixiv::get_illustration_dto_from_json( $json, "103301948" );

    my $expected_pixiv_summary = Mojo::File -> new("$SAMPLES/pixiv/manga_2_pixiv_comment_unescaped.txt") -> slurp('UTF-8');
    my $actual_pixiv_summary = LANraragi::Plugin::Metadata::Pixiv::get_summary_from_dto( \%dto );

    is( $actual_pixiv_summary, $expected_pixiv_summary, "manga 2 pixiv summary equal" );

}

note("testing summary sanitization");

{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::Pixiv::get_plugin_logger        = sub { return get_logger_mock(); };

    my $summary_with_script = Mojo::File -> new("$SAMPLES/pixiv/manga_2_pixiv_comment_with_script.txt") -> slurp('UTF-8');
    my $expected_pixiv_summary = Mojo::File -> new("$SAMPLES/pixiv/manga_2_pixiv_comment_unescaped.txt") -> slurp('UTF-8');
    my $actual_pixiv_summary = LANraragi::Plugin::Metadata::Pixiv::sanitize_summary( $summary_with_script );

    is( $actual_pixiv_summary, $expected_pixiv_summary, "manga 2 pixiv summary sanitized" );

}

done_testing();