package LANraragi::Controller::Reader;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::URL;

use Encode;

use LANraragi::Utils::Generic qw(generate_themes_header);

# This action will render a template
sub index {
    my $self = shift;

    if ( $self->req->param('id') ) {

        my $id = $self->req->param('id');
        my $char = chop $id;
        if ( $char ne "/" ) {
            $id .= $char;
        }

        # Allow adding to static categories
        my @categories     = LANraragi::Model::Category->get_static_category_list;
        my @arc_categories = LANraragi::Model::Category::get_categories_containing_archive( $self->req->param('id') );

        # Get query string from referrer URL, if there's one
        my $referrer = $self->req->headers->referrer;
        my $query    = "";

        if ($referrer) {
            $query = Mojo::URL->new($referrer)->query->to_string;
        }

        $self->render(
            template       => "reader",
            title          => $self->LRR_CONF->get_htmltitle,
            use_local      => $self->LRR_CONF->enable_localprogress,
            id             => $id,
            arc_categories => \@arc_categories,
            categories     => \@categories,
            csshead        => generate_themes_header($self),
            version        => $self->LRR_VERSION,
            ref_query      => $query,
            userlogged     => $self->LRR_CONF->enable_pass == 0 || $self->session('is_logged')
        );
    } else {

        # No parameters back the fuck off
        $self->redirect_to('index');
    }
}

1;
