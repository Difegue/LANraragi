package LANraragi::Controller::I18n;
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template.. as a JS file.
# This allows us to use the i18n system in frontend without additional libraries!
sub index {
    my $self = shift;

    $self->res->headers->content_type('application/javascript');
    $self->render( template => "i18n" );
}

1;
