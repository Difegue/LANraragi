package LANraragi::Controller::Api::Search;
use Mojo::Base 'Mojolicious::Controller';

use List::Util qw(min);

use LANraragi::Model::Search;
use LANraragi::Utils::Generic  qw(render_api_response);
use LANraragi::Utils::Database qw(invalidate_cache get_archive_json_multi);

# Undocumented API matching the Datatables spec.
sub handle_datatables {

    my $self = shift;
    my $req  = $self->req;

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

    while ( $req->param("columns[$i][name]") ) {

        # Collection (tags column)
        if ( $req->param("columns[$i][name]") eq "tags" ) {
            $categoryfilter = $req->param("columns[$i][search][value]");

            # Specific hacks for the buily-in newonly/untagged selectors
            # Those have hardcoded 'category' IDs
            if ( $categoryfilter eq "NEW_ONLY" ) {
                $newfilter      = 1;
                $categoryfilter = "";
            }

            if ( $categoryfilter eq "UNTAGGED_ONLY" ) {
                $untaggedfilter = 1;
                $categoryfilter = "";
            }

        }
        $i++;
    }

    $sortorder = ( $sortorder && $sortorder eq 'desc' ) ? 1 : 0;

    # TODO add a parameter to datatables for grouptanks? Not really essential rn tho
    my ( $total, $filtered, @ids ) =
      LANraragi::Model::Search::do_search( $filter, $categoryfilter, $start, $sortkey, $sortorder, $newfilter, $untaggedfilter, 0 );

    $self->render( json => get_datatables_object( $draw, $total, $filtered, @ids ) );
}

# Public search API with saner parameters.
sub handle_api {

    my $self = shift;
    my $req  = $self->req;

    my $filter     = $req->param('filter');
    my $category   = $req->param('category') || "";
    my $start      = $req->param('start')    || 0;
    my $sortkey    = $req->param('sortby');
    my $sortorder  = $req->param('order');
    my $newfilter  = $req->param('newonly')       || "false";
    my $untaggedf  = $req->param('untaggedonly')  || "false";
    my $grouptanks = $req->param('groupby_tanks') || "false";

    $sortorder = ( $sortorder && $sortorder eq 'desc' ) ? 1 : 0;

    my ( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search(
        $filter, $category, $start, $sortkey, $sortorder,
        $newfilter eq "true",
        $untaggedf eq "true",
        $grouptanks eq "true"
    );

    $self->render( json => get_datatables_object( 0, $total, $filtered, @ids ) );
}

sub clear_cache {
    invalidate_cache();
    render_api_response( shift, "clear_cache" );
}

# Pull random archives out of the given search
sub get_random_archives {

    my $self = shift;
    my $req  = $self->req;

    my $filter       = $req->param('filter');
    my $category     = $req->param('category')      || "";
    my $newfilter    = $req->param('newonly')       || "false";
    my $untaggedf    = $req->param('untaggedonly')  || "false";
    my $grouptanks   = $req->param('groupby_tanks') || "false";
    my $random_count = $req->param('count')         || 5;

    # Use the search engine to get IDs matching the filter/category selection, with start=-1 to get all data
    my ( $total, $filtered, @ids ) = LANraragi::Model::Search::do_search(
        $filter, $category, -1, "title", 0,
        $newfilter eq "true",
        $untaggedf eq "true",
        $grouptanks eq "true"
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

# get_datatables_object($draw, $total, $totalsearched, @pagedkeys)
# Creates a Datatables-compatible json from the given data.
sub get_datatables_object {

    my ( $draw, $total, $filtered, @ids ) = @_;

    # Get archive data
    my @data = get_archive_json_multi(@ids);

    # Create json object matching the datatables structure
    return {
        draw            => $draw,
        recordsTotal    => $total,
        recordsFiltered => $filtered,
        data            => \@data
    };
}

1;
