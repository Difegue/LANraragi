package LANraragi::Controller::Api::Metrics;
use Mojo::Base 'Mojolicious::Controller';

use LANraragi::Model::Metrics;

sub serve_metrics {
    my $self = shift;
    my $metrics_output = LANraragi::Model::Metrics::get_prometheus_metrics($self);
    $self->render(
        text    => $metrics_output,
        format  => 'txt',
        headers => { 'Content-Type' => 'application/openmetrics-text; version=1.0.0; charset=utf-8' }
    );
}

1;