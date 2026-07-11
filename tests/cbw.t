use strict;
use warnings;
use utf8;
use Cwd;

use Test::More;

use LANraragi::Utils::Archive qw(is_cbw parse_cbw_urls);

# is_cbw suffix detection (case-insensitive, doesn't match other formats)
ok( LANraragi::Utils::Archive::is_cbw("foo.cbw"),  "is_cbw matches .cbw" );
ok( LANraragi::Utils::Archive::is_cbw("FOO.CBW"),  "is_cbw is case-insensitive" );
ok( !LANraragi::Utils::Archive::is_cbw("foo.cbz"), "is_cbw rejects .cbz" );
ok( !LANraragi::Utils::Archive::is_cbw("foo.pdf"), "is_cbw rejects .pdf" );

# Range expansion with zero-padding
{
    my @urls = LANraragi::Utils::Archive::expand_cbw_range("http://cdn/[00:8-11].jpg");
    is_deeply(
        \@urls,
        [ "http://cdn/08.jpg", "http://cdn/09.jpg", "http://cdn/10.jpg", "http://cdn/11.jpg" ],
        "expand_cbw_range zero-pads and expands the range"
    );
}

# Range with no padding format
{
    my @urls = LANraragi::Utils::Archive::expand_cbw_range("http://cdn/[0:1-3].jpg");
    is_deeply( \@urls, [ "http://cdn/1.jpg", "http://cdn/2.jpg", "http://cdn/3.jpg" ], "expand_cbw_range without padding" );
}

# Descending range
{
    my @urls = LANraragi::Utils::Archive::expand_cbw_range("http://cdn/[0:3-1].jpg");
    is_deeply( \@urls, [ "http://cdn/3.jpg", "http://cdn/2.jpg", "http://cdn/1.jpg" ], "expand_cbw_range descending" );
}

# URL without a range is returned unchanged
{
    my @urls = LANraragi::Utils::Archive::expand_cbw_range("http://cdn/single.jpg");
    is_deeply( \@urls, ["http://cdn/single.jpg"], "expand_cbw_range leaves plain URLs alone" );
}

# Full XML parse: variable substitution + range expansion + ordering
{
    my $xml = <<'XML';
<WebComic>
  <Info/>
  <Variables>
    <Variable Key="Base" Value="http://www.example.com/comic/" />
  </Variables>
  <Images>
    <Image Url="{Base}cover.jpg" />
    <Image Url="{Base}[00:1-3].png" />
    <Image PageLinkType="Url" Url="{Base}extra.webp" />
  </Images>
</WebComic>
XML

    my @urls = LANraragi::Utils::Archive::parse_cbw_xml($xml);
    is_deeply(
        \@urls,
        [   "http://www.example.com/comic/cover.jpg",
            "http://www.example.com/comic/01.png",
            "http://www.example.com/comic/02.png",
            "http://www.example.com/comic/03.png",
            "http://www.example.com/comic/extra.webp",
        ],
        "parse_cbw_xml substitutes variables, expands ranges, and preserves order"
    );
}

# Non-Url PageLinkType entries are skipped
{
    my $xml = <<'XML';
<WebComic>
  <Images>
    <Image Url="http://cdn/a.jpg" />
    <Image PageLinkType="File" Url="local.jpg" />
    <Image Url="http://cdn/b.jpg" />
  </Images>
</WebComic>
XML

    my @urls = LANraragi::Utils::Archive::parse_cbw_xml($xml);
    is_deeply( \@urls, [ "http://cdn/a.jpg", "http://cdn/b.jpg" ], "parse_cbw_xml skips non-Url PageLinkType entries" );
}

# Synthetic page names derive extension from the URL and zero-pad the index
is( LANraragi::Utils::Archive::cbw_page_name( 1,  "http://cdn/cover.jpg",       12 ), "01.jpg", "cbw_page_name pads to total width" );
is( LANraragi::Utils::Archive::cbw_page_name( 3,  "http://cdn/p.png?size=big",  12 ), "03.png", "cbw_page_name strips query string" );
is( LANraragi::Utils::Archive::cbw_page_name( 10, "http://cdn/noext",          12 ), "10.jpg", "cbw_page_name defaults to jpg" );

# Malformed input dies with a clear message
{
    eval { LANraragi::Utils::Archive::parse_cbw_xml("") };
    ok( $@ =~ /empty/i, "parse_cbw_xml dies on empty input" );

    eval { LANraragi::Utils::Archive::parse_cbw_xml("<NotAComic/>") };
    ok( $@ =~ /WebComic/i, "parse_cbw_xml dies when the root element is missing" );

    eval { LANraragi::Utils::Archive::parse_cbw_xml("<WebComic><Images/></WebComic>") };
    ok( $@ =~ /No image URLs/i, "parse_cbw_xml dies when there are no images" );
}

# Reading the bundled sample file end-to-end
{
    my $cwd    = getcwd;
    my @urls   = parse_cbw_urls( $cwd . "/tests/samples/sample.cbw" );
    is( scalar @urls, 5, "sample.cbw expands to 5 pages" );
    is( $urls[0], "http://www.example.com/comic/cover.jpg", "sample.cbw first page is the cover" );
}

done_testing();
