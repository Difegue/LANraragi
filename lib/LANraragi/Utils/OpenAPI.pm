package LANraragi::Utils::OpenAPI;

use strict;
use warnings;
use utf8;

use Exporter 'import';
our @EXPORT_OK = qw(apply_bypass);

# Override OpenAPI request/response validation to bypass all schema checks
# while preserving routing and error passthrough.
sub apply_bypass {
    my $app = shift;

    # Override request validation: always pass through to controller.
    # https://metacpan.org/pod/Mojolicious::Plugin::OpenAPI#openapi.valid_input
    $app->helper(
        'openapi.valid_input' => sub {
            my $c = shift;
            return if $c->res->code;
            return $c;
        }
    );

    # Override the plugin's "openapi" render handler to skip response validation.
    # The original (Mojolicious::Plugin::OpenAPI::_render) validates responses
    # against the schema and rejects violations as 500; this handler skips that.
    $app->renderer->add_handler(
        openapi => sub {
            my ( $renderer, $c, $output, $args ) = @_;

            # Bypass logic only applies if rendering is done through OpenAPI plugin
            my $stash = $c->stash;
            return unless exists $stash->{openapi};

            # Prevent double-encoding of JSON body
            # See Mojolicious::Plugin::OpenAPI::Parameters::_helper_build_response_body
            delete $args->{encoding};
            $$output = $c->openapi->build_response_body( $stash->{openapi} );
        }
    );
}

1;
