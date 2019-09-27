package LANraragi::Controller::Search;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Encode;
use Mojo::JSON qw(decode_json encode_json from_json);
use File::Path qw(remove_tree);

use LANraragi::Utils::Generic;
use LANraragi::Utils::Archive;
use LANraragi::Utils::Database;
use LANraragi::Utils::TempFolder;

use LANraragi::Model::Search;
use LANraragi::Model::Config;

# Undocumented API matching the Datatables spec.
sub handle_datatables {

    my $self = shift;
    my $req  = $self->req->json;

    my $draw    = $req->{draw};
    my $start   = $req->{start};
    my $length  = $req->{length};

    my $filter    = $req->{search}{value};
    my $sortindex = $req->{order}[0]{column};
    my $sortorder = $req->{order}[0]{dir};
    my $sortkey   = $req->{columns}[$sortindex]{name};

    if ($sortorder && $sortorder eq 'desc') { $sortorder = 1; }
        else { $sortorder = 0; }

    my ($total, @ids) = LANraragi::Model::Search::do_search($filter, $start, $sortkey, $sortorder);

    $self->render(
        json => get_datatables_object($draw, $total, @ids)
    );

}

# Public search API with saner parameters.
sub handle_api {

    my $self = shift;
    my $req  = $self->req;

    my $filter    = $req->param('filter');
    my $start     = $req->param('start');
    my $sortkey   = $req->param('sortby');
    my $sortorder = $req->param('order');

    if ($sortorder && $sortorder eq 'desc') { $sortorder = 1; }
        else { $sortorder = 0; }

    my ($total, @ids) = LANraragi::Model::Search::do_search($filter, $start, $sortkey, $sortorder);

    $self->render(
        json => get_datatables_object(0, $total, @ids)
    );

}

# get_datatables_object($draw, $total, @keys)
# Creates a Datatables-compatible json from the given data.
sub get_datatables_object {

    my ( $draw, $total, @keys ) = @_;

    # Get archive data from keys 
    my @data = ();
    foreach my $key (@keys) {
        push @data, LANraragi::Model::Search::build_archive_JSON($key->{id});
    }

    # Create json object matching the datatables structure
    return {
        draw => $draw,
        recordsTotal => $total,
        recordsFiltered => $#data,
        data => \@data
    };
}

1;
