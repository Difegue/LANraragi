package LANraragi::Controller::Logging;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Encode;

use LANraragi::Utils::Generic;
use LANraragi::Utils::Archive;
use LANraragi::Utils::Database;
use LANraragi::Utils::Logging qw(get_logdir get_lines_from_file);

# This action will render a template
sub index {

    my $self = shift;

    $self->render(
        template => "logs",
        title    => $self->LRR_CONF->get_htmltitle,
        cssdrop  => LANraragi::Utils::Generic::generate_themes_selector,
        csshead  => LANraragi::Utils::Generic::generate_themes_header($self),
        version  => $self->LRR_VERSION
    );
}

sub print_lines_from_file {

    my ($mojo, $file) = @_;

    # Number of lines to read
    my $lines  = 100;     
    my $logdir = get_logdir;

    if ( $mojo->req->param('lines') ) {
        $lines = $mojo->req->param('lines');
    }

    $mojo->render(
        text => get_lines_from_file( $lines, $logdir."/$file.log" ) 
    );

}

sub print_general {
    print_lines_from_file(shift, "lanraragi");
}

sub print_shinobu {
    print_lines_from_file(shift, "shinobu");
}

sub print_plugins {
    print_lines_from_file(shift, "plugins");
}

sub print_redis {
    print_lines_from_file(shift, "redis");
}

sub print_mojo {

    my $self = shift;

    #Depending on the mode, look for development or production.log
    my $mode = $self->app->mode;
    print_lines_from_file($self, $mode);
}

1;
