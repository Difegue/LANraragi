package LANraragi::Model::Opds;

use strict;
use warnings;
use utf8;

use Redis;
use POSIX qw(strftime);
use Mojo::Util qw(xml_escape);

use LANraragi::Utils::Generic qw(get_tag_with_namespace);
use LANraragi::Utils::Archive qw(get_filelist);
use LANraragi::Utils::Database qw(get_archive_json );
use LANraragi::Model::Category;
use LANraragi::Model::Search;

sub generate_opds_catalog {

    my $mojo = shift;
    my $cat_id = $mojo->req->param('category') || "";

    # If the user authentified to this via an API key, we need to carry it over to the OPDS links.
    my $api_key = $mojo->req->param('key');
    my @cats    = LANraragi::Model::Category->get_category_list;

    # Use the search engine to get the list of archives to show in the catalog.
    my ( $total, $filtered, @keys ) = LANraragi::Model::Search::do_search( "", $cat_id, -1, "title", 0, 0, 0 );

    my @list = ();

    foreach my $id (@keys) {
        my $arcdata = get_opds_data($id);
        push @list, $arcdata if $arcdata;
    }

    foreach my $cat (@cats) {

        # If the category doesn't have a search string, we can add the total count of archives to the entry.
        if ( $cat->{search} eq "" ) {
            $cat->{count} = scalar @{ $cat->{archives} };
        }

        if ( $cat->{id} eq $cat_id ) {
            $cat->{active} = 1;
        }
    }

    # Sort lists to get reproducible results
    @list = sort { lc( $a->{title} ) cmp lc( $b->{title} ) } @list;
    @cats = sort { lc( $a->{name} ) cmp lc( $b->{name} ) } @cats;

    return $mojo->render_to_string(
        template      => "opds",
        arclist       => \@list,
        catlist       => \@cats,
        nocat         => $cat_id eq "",
        title         => $mojo->LRR_CONF->get_htmltitle,
        motd          => $mojo->LRR_CONF->get_motd,
        version       => $mojo->LRR_VERSION,
        api_key_query => $api_key ? "?key=" . $api_key : "",
        api_key_and   => $api_key ? "&amp;key=" . $api_key : ""
    );
}

sub generate_opds_item {

    my ( $mojo, $id ) = @_;

    # If the user authentified to this via an API key, we need to carry it over to the OPDS links.
    my $api_key = $mojo->req->param('key');

    # Detailed pages just return a single entry instead of all the archives.
    my $arcdata = get_opds_data($id);

    return $mojo->render_to_string(
        template      => "opds_entry",
        arc           => $arcdata,
        title         => $mojo->LRR_CONF->get_htmltitle,
        motd          => $mojo->LRR_CONF->get_motd,
        version       => $mojo->LRR_VERSION,
        api_key_query => $api_key ? "?key=" . $api_key : "",
        api_key_and   => $api_key ? "&amp;key=" . $api_key : ""
    );
}

sub get_opds_data {

    my $id    = shift;
    my $redis = LANraragi::Model::Config->get_redis;

    my $file = $redis->hget( $id, "file" );
    unless ( -e $file ) { return; }

    my $arcdata = get_archive_json( $redis, $id );
    unless ($arcdata) { return; }

    my $tags = $arcdata->{tags};

    # Parse date from the date_added tag, and convert from unix time to ISO 8601.
    my $date = get_tag_with_namespace( "date_added", $tags, "0" );
    $arcdata->{dateadded} = strftime( "%Y-%m-%dT%H:%M:%SZ", gmtime($date) );

    # Infer a few OPDS-related fields from the tags
    $arcdata->{author}   = get_tag_with_namespace( "artist",   $tags, "" );
    $arcdata->{language} = get_tag_with_namespace( "language", $tags, "" );
    $arcdata->{circle}   = get_tag_with_namespace( "group",    $tags, "" );
    $arcdata->{event}    = get_tag_with_namespace( "event",    $tags, "" );

    # Application/zip is universally hated by all readers so it's better to use x-cbz and x-cbr here.
    if ( $file =~ /^(.*\/)*.+\.(pdf)$/ ) {
        $arcdata->{mimetype} = "application/pdf";
    } elsif ( $file =~ /^(.*\/)*.+\.(rar|cbr)$/ ) {
        $arcdata->{mimetype} = "application/x-cbr";
    } elsif ( $file =~ /^(.*\/)*.+\.(epub)$/ ) {
        $arcdata->{mimetype} = "application/epub+zip";
    } else {
        $arcdata->{mimetype} = "application/x-cbz";
    }

    if ( $arcdata->{lastreaddate} > 0) {
      $arcdata->{lastreaddate} = strftime( "%Y-%m-%dT%H:%M:%SZ", gmtime($arcdata->{lastreaddate}) );
    }

    for ( values %{$arcdata} ) { $_ = xml_escape($_); }

    return $arcdata;
}

sub render_archive_page {

    my ( $mojo, $id, $page ) = @_;

    my $redis = $mojo->LRR_CONF->get_redis;
    my $archive = $redis->hget( $id, "file" );

    # Parse archive to get its list of images
    my ( $images, $sizes ) = get_filelist($archive);

    my @images = @$images;

    # If the page number is invalid, use the first page.
    if ( $page > scalar @images ) {
        $page = 1;
    }

    # If the page number is valid, render the page.
    my $image = $images[ $page - 1 ];

    # Use the same code as /api/page to serve the file.
    # This is clean, but might serve other types than JPEG depending on how the archive is built..
    # We could force resizing here to always have JPEG. (TODO?)
    LANraragi::Model::Archive::serve_page( $mojo, $id, $image );
}

1;
