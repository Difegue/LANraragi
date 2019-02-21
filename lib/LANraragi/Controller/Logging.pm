package LANraragi::Controller::Logging;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Encode;
use File::ReadBackwards;

use LANraragi::Utils::Generic;
use LANraragi::Utils::Archive;
use LANraragi::Utils::Database;

# This action will render a template
sub index {

    my $self = shift;

    $self->render(
        template => "logs",
        title    => $self->LRR_CONF->get_htmltitle,
        cssdrop  => LANraragi::Utils::Generic::generate_themes_selector,
        csshead  => LANraragi::Utils::Generic::generate_themes_header
    );
}

sub print_general {

    my $self  = shift;
    my $lines = 100;     #Number of lines to read

    if ( $self->req->param('lines') ) {
        $lines = $self->req->param('lines');
    }

    $self->render(
        text => &get_lines_from_file( $lines, "./log/lanraragi.log" ) );
}

sub print_plugins {

    my $self  = shift;
    my $lines = 100;     #Number of lines to read

    if ( $self->req->param('lines') ) {
        $lines = $self->req->param('lines');
    }

    $self->render(
        text => &get_lines_from_file( $lines, "./log/plugins.log" ) );
}

sub print_mojo {

    my $self = shift;

    #Depending on the mode, look for development or production.log
    my $mode = $self->app->mode;

    my $lines = 100;    #Number of lines to read

    if ( $self->req->param('lines') ) {
        $lines = $self->req->param('lines');
    }

    $self->render( text => &get_lines_from_file( $lines, "./log/$mode.log" ) );
}

sub get_lines_from_file {

    my $lines = $_[0];
    my $file  = $_[1];

    #Load the last X lines of file
    if ( -e $file ) {
        my $bw  = File::ReadBackwards->new($file);
        my $res = "";
        for ( my $i = 0 ; $i <= $lines ; $i++ ) {
            my $line = $bw->readline();
            if ($line) {
                $res = $line . $res;
            }

        }

        return decode_utf8($res);
    }

    return "No logs to be found here!";

}

1;
