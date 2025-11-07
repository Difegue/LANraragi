package LANraragi::Controller::Api::Metrics;
use Mojo::Base 'Mojolicious::Controller';

use LANraragi::Model::Metrics;

sub serve_metrics {
    my $self = shift;
    my $metrics_output = LANraragi::Model::Metrics::get_prometheus_metrics($self);
    $self->render(
        text    => $metrics_output,
        format  => 'txt',
        headers => { 'Content-Type' => 'text/plain; charset=utf-8' }
    );
}

1; 