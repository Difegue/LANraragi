package LANraragi::Utils::Login;

use strict;
use warnings;

use MIME::Base64 qw(encode_base64);

use Exporter 'import';
our @EXPORT_OK = qw(is_logged_in_api);

# Check if an API is logged in.
sub is_logged_in_api {
    my $c = shift;

    # The API key is in the Authentication header.
    my $expected_key = $c->LRR_CONF->get_apikey;
    my $expected_header = "Bearer " . encode_base64( $expected_key, "" );

    my $auth_header = $c->req->headers->authorization || "";

    # It can also be passed as a parameter. (Undocumented, mostly just meant for OPDS)
    my $param_key = $c->req->param('key') || '';

    return 1
        if ( $expected_key ne "" && $auth_header eq $expected_header )
        || ( $param_key ne "" && $param_key eq $expected_key )
        || $c->session('is_logged')
        || $c->LRR_CONF->enable_pass == 0;
    return 0;
}

1;
