package LANraragi::Controller::Api::Search;
use Mojo::Base 'Mojolicious::Controller';

use feature qw(say signatures);
no warnings 'experimental::signatures';

use List::Util qw(min);

use LANraragi::Model::Search;
use LANraragi::Utils::Generic  qw(render_api_response parse_bool);
use LANraragi::Utils::Database qw(invalidate_cache get_archive_json_multi);
use LANraragi::Utils::Logging qw(get_logger);

# Undocumented API matching the Datatables spec.
sub handle_datatables ($self) {

    my $req = $self->req;

    my $logger = get_logger( "Search API", "lanraragi" );
    my $draw   = $req->param('draw');
    my $start  = $req->param('start');
    my $length = $req->param('length');

    # Jesus christ what the fuck datatables
    my $filter    = $req->param('search[value]');
    my $sortindex = $req->param('order[0][column]');
    my $sortorder = $req->param('order[0][dir]');
    my $sortkey   = $req->param("columns[$sortindex][name]");

    # See if specific column searches were made
    my $i              = 0;
    my $categoryfilter = "";
    my $newfilter      = 0;
    my $untaggedfilter = 0;
    my $tankoubonsfilter = 0;

    while ( $req->param("columns[$i][name]") ) {

        # Collection (tags column)
        if ( $req->param("columns[$i][name]") eq "tags" ) {
            my $raw_filter = $req->param("columns[$i][search][value]") // "";

            # Parse comma-separated category filters
            # Pseudo-categories (NEW_ONLY, UNTAGGED_ONLY, TANKOUBONS_ONLY) become boolean flags
            # Real category IDs are collected and rejoined
            my @real_categories;
            for my $cat ( split /,/, $raw_filter ) {
                if ( $cat eq "NEW_ONLY" ) {
                    $newfilter = 1;
                } elsif ( $cat eq "UNTAGGED_ONLY" ) {
                    $untaggedfilter = 1;
                } elsif ( $cat eq "TANKOUBONS_ONLY" ) {
                    $tankoubonsfilter = 1;
                } elsif ( $cat ne "" ) {
                    push @real_categories, $cat;
                }
            }
            $categoryfilter = join( ",", @real_categories );
        }
        $i++;
    }

    $sortorder = ( $sortorder && $sortorder eq 'desc' ) ? 1 : 0;

    my $grouptanks = $req->param('grouptanks') || 0;

    # Force grouptanks on when tankoubons filter is enabled, since tanks only appear when grouped
    if ($tankoubonsfilter) {
        $grouptanks = 1;
    }
    $logger->debug("grouptanks=$grouptanks, tankoubonsfilter=$tankoubonsfilter");

    my ( $total, $filtered, @ids ) =
      LANraragi::Model::Search::do_search( $filter, $categoryfilter, $start, $sortkey, $sortorder, $newfilter, $untaggedfilter, $grouptanks, $tankoubonsfilter );

    $self->render( json => get_datatables_object( $draw, $total, $filtered, @ids ) );
}

# Public search API with saner parameters.
sub handle_api ($self) {

    my $req = $self->req;

    my $filter    = $req->param('filter');
    my $category  = $req->param('category') || "";
    my $start     = $req->param('start')    || 0;
    my $sortkey   = $req->param('sortby');
    my $sortorder = $req->param('order');

    my ( $newfilter, $err ) = parse_bool( $req->param('newonly'), 'newonly' );
    if ($err) {
        render_api_response( $self, "search", $err );
        return;
    }

    ( my $untaggedf, $err ) = parse_bool( $req->param('untaggedonly'), 'untaggedonly' );
    if ($err) {
        render_api_response( $self, "search", $err );
        return;
    }

    ( my $grouptanks, $err ) = parse_bool( $req->param('groupby_tanks'), 'groupby_tanks' );
    if ($err) {
        render_api_response( $self, "search", $err );
        return;
    }

    ( my $tankoubonsonly, $err ) = parse_bool( $req->param('tankoubonsonly'), 'tankoubonsonly' );
    if ($err) {
        render_api_response( $self, "search", $err );
        return;
    }

    # Force grouptanks on when tankoubonsonly is enabled, since tanks only appear when grouped
    if ($tankoubonsonly) {
        $grouptanks = 1;
    }

    $sortorder = ( $sortorder && $sortorder eq 'desc' ) ? 1 : 0;

    my ( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search(
        $filter, $category, $start, $sortkey, $sortorder,
        $newfilter,
        $untaggedf,
        $grouptanks,
        $tankoubonsonly
    );

    if ( $total eq -1 && $filtered eq -1 ) {

        # Search engine not initialized
        $self->render(
            json => {
                recordsTotal    => 0,
                recordsFiltered => 0,
                data            => []
            },
            status => 204
        );
    } else {
        $self->render( json => get_api_object( $total, $filtered, @ids ) );
    }
}

sub clear_cache {
    invalidate_cache();
    render_api_response( shift, "clear_cache" );
}

# Pull random archives out of the given search
sub get_random_archives ($self) {

    my $req = $self->req;

    my $filter       = $req->param('filter');
    my $category     = $req->param('category') || "";
    my $random_count = $req->param('count')    || 5;

    my ( $newfilter, $err ) = parse_bool( $req->param('newonly'), 'newonly' );
    if ($err) {
        render_api_response( $self, "get_random_archives", $err );
        return;
    }

    ( my $untaggedf, $err ) = parse_bool( $req->param('untaggedonly'), 'untaggedonly' );
    if ($err) {
        render_api_response( $self, "get_random_archives", $err );
        return;
    }

    ( my $grouptanks, $err ) = parse_bool( $req->param('groupby_tanks'), 'groupby_tanks' );
    if ($err) {
        render_api_response( $self, "get_random_archives", $err );
        return;
    }

    ( my $tankoubonsonly, $err ) = parse_bool( $req->param('tankoubonsonly'), 'tankoubonsonly' );
    if ($err) {
        render_api_response( $self, "get_random_archives", $err );
        return;
    }

    # Force grouptanks on when tankoubonsonly is enabled, since tanks only appear when grouped
    if ($tankoubonsonly) {
        $grouptanks = 1;
    }

    # Use the search engine to get IDs matching the filter/category selection, with start=-1 to get all data
    my ( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search(
        $filter, $category, -1, "title", 0,
        $newfilter,
        $untaggedf,
        $grouptanks,
        $tankoubonsonly
    );
    my @random_ids;

    $random_count = min( $random_count, scalar(@ids) );

    # Get random IDs out of the array
    for ( 1 .. $random_count ) {
        my $random_index = int( rand( scalar(@ids) ) );
        push( @random_ids, splice( @ids, $random_index, 1 ) );
    }

    my @data = get_archive_json_multi(@random_ids);
    $self->render(
        json => {
            data         => \@data,
            recordsTotal => $random_count
        }
    );
}

# Creates a Datatables-compatible json from the given data.
sub get_datatables_object ( $draw, $total, $totalsearched, @ids ) {

    # Get archive data
    my @data = get_archive_json_multi(@ids);

    # Create json object matching the datatables structure
    return {
        draw            => $draw,
        recordsTotal    => $total,
        recordsFiltered => $totalsearched,
        data            => \@data
    };
}

# Creates an API json from the given data.
sub get_api_object ( $total, $totalsearched, @ids ) {

    # Get archive data
    my @data = get_archive_json_multi(@ids);

    # Create json object matching the datatables structure
    return {
        recordsTotal    => $total,
        recordsFiltered => $totalsearched,
        data            => \@data
    };
}

1;
