package LANraragi::Utils::OpenAPI;

use strict;
use warnings;
use utf8;
use Mojo::JSON qw(encode_json);

use Exporter 'import';
our @EXPORT_OK = qw(apply_openapi_mojo_overrides);


# Override OpenAPI request validation to keep default behavior while ensuring
# validation failures are logged through the app logger (LRR rotating log path).
sub apply_openapi_mojo_overrides {
    my $app = shift;

    # If bypass is enabled, then override request/response validation to bypass all
    # schema checks while preserving routing and error passthrough.
    if ( $app->LRR_CONF->get_disable_openapi ) {
        # Override request validation: always pass through to controller.
        # https://metacpan.org/pod/Mojolicious::Plugin::OpenAPI#openapi.valid_input
        $app->helper(
            'openapi.valid_input' => sub {
                my $c = shift;
                return if $c->res->code; # Exit if status code already provided
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
    } else {
        $app->helper(
            'openapi.valid_input' => sub {
                my $c = shift;
                return if $c->res->code; # Exit if status code already provided

                my @errors = $c->openapi->validate; # Perform the request validation work
                return $c unless @errors;

                # Remain code deals with validation error scenarios
                # Log OpenAPI errors at server-side warning level
                $c->app->log->warn(
                    sprintf(
                        'OpenAPI >>> %s %s %s',
                        $c->req->method,
                        $c->req->url->path,
                        encode_json( \@errors )
                    )
                );

                $c->stash( status => 400 )->render(
                    data => $c->openapi->build_response_body({
                        errors => \@errors,
                        status => 400
                    })
                );
                return;
            }
        );
    }

}

1;
