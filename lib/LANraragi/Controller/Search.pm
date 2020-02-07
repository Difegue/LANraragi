package LANraragi::Controller::Search;
use Mojo::Base 'Mojolicious::Controller';

use LANraragi::Model::Search;

# Undocumented API matching the Datatables spec.
sub handle_datatables {

    my $self  = shift;
    my $redis = $self->LRR_CONF->get_redis();
    my $req   = $self->req;

    my $draw    = $req->param('draw');
    my $start   = $req->param('start');
    my $length  = $req->param('length');

    # Jesus christ what the fuck datatables
    my $filter    = $req->param('search[value]');
    my $sortindex = $req->param('order[0][column]');
    my $sortorder = $req->param('order[0][dir]');
    my $sortkey   = $req->param("columns[$sortindex][name]");

    # See if specific column searches were made
    my $i = 0;
    my $columnfilter   = "";
    my $newfilter      = 0;
    my $untaggedfilter = 0;

    while ($req->param("columns[$i][name]")) {

        # Favtags (tags column)
        if ($req->param("columns[$i][name]") eq "tags") {
            $columnfilter = $req->param("columns[$i][search][value]");
        } 
        
        # New filter (isnew column)
        if ($req->param("columns[$i][name]") eq "isnew") {
            $newfilter = $req->param("columns[$i][search][value]") eq "true";
        } 

        # Untagged filter (untagged column)
        if ($req->param("columns[$i][name]") eq "untagged") {
            $untaggedfilter = $req->param("columns[$i][search][value]") eq "true";
        } 
        $i++;
    }

    if ($sortorder && $sortorder eq 'desc') { $sortorder = 1; }
        else { $sortorder = 0; }

    my ($total, $filtered, @ids) = 
        LANraragi::Model::Search::do_search($filter, $columnfilter, $start, $sortkey, $sortorder, $newfilter, $untaggedfilter);

    $self->render(
        json => get_datatables_object($draw, $redis, $total, $filtered, @ids)
    );
    $redis->quit();

}

# Public search API with saner parameters.
sub handle_api {

    my $self  = shift;
    my $redis = $self->LRR_CONF->get_redis();
    my $req   = $self->req;

    my $filter    = $req->param('filter');
    my $start     = $req->param('start');
    my $sortkey   = $req->param('sortby');
    my $sortorder = $req->param('order');
    my $newfilter = $req->param('newonly');
    my $untaggedf = $req->param('untaggedonly');

    if ($sortorder && $sortorder eq 'desc') { $sortorder = 1; }
        else { $sortorder = 0; }

    my ($total, $filtered, @ids) = 
        LANraragi::Model::Search::do_search($filter, "", $start, $sortkey, $sortorder, $newfilter eq "true", $untaggedf eq "true");

    $self->render(
        json => get_datatables_object(0, $redis, $total, $filtered, @ids)
    );
    $redis->quit();

}

# get_datatables_object($draw, $total, $totalsearched, @pagedkeys)
# Creates a Datatables-compatible json from the given data.
sub get_datatables_object {

    my ( $draw, $redis, $total, $filtered, @keys ) = @_;

    # Get archive data from keys 
    my @data = ();
    foreach my $key (@keys) {
        push @data, LANraragi::Utils::Database::build_archive_JSON($redis, $key->{id});
    }

    # Create json object matching the datatables structure
    return {
        draw => $draw,
        recordsTotal => $total,
        recordsFiltered => $filtered,
        data => \@data
    };
}

1;
