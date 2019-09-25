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

    my ($total, @ids) = LANraragi::Model::Search::do_search($filter, $start, $sortkey, $sortorder);

    $self->render(
        json => create_json($draw, $total, @ids);
    );

}

sub handle_api {
    
}

# create_json($draw, $total, @keys)
# Creates a Datatables-compatible json from the given data.
sub create_json {

    my ( $draw, $total, @keys ) = @_;

    # Get archive data from id keys 
    my @data;
    foreach my $id (@keys) {
        push @data, LANraragi::Model::Search::build_archive_JSON($id);
    }

    # Create json object matching the datatables structure
    my $response = {
        draw => $draw,
        recordsTotal => $total,
        recordsFiltered => $#keys,
        data => @data
    };

    return encode_json($response);
}

1;
