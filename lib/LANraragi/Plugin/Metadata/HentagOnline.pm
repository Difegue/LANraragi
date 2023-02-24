package LANraragi::Plugin::Metadata::HentagOnline;

use strict;
use warnings;

#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use URI::Escape;
use Mojo::JSON qw(from_json);
use Mojo::UserAgent;

#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_plugin_logger);

# Most parsing is reused between the two plugins
require LANraragi::Plugin::Metadata::Hentag;

#Meta-information about your plugin.
sub plugin_info {

    return (
        name        => "Hentag Online Lookups",
        type        => "metadata",
        namespace   => "hentagonlineplugin",
        author      => "siliconfeces",
        version     => "0.1",
        description => "Searches hentag.com for tags matching your archive",
		parameters  => [
            { type => "bool", desc => "Save archive title" }
        ],
        icon =>
           "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAACXBIWXMAAAPoAAAD6AG1e1JrAAAEzklEQVR4nO2Xa0xbZRjH6xe/0NKW0p7TQgul9GJpuQ0YbcFgXFx0M+NaoF0gY4mbkwLLxjYoMoiZMVGnDJZt2TT7plnGxmVCgXEdi859MGabH0xqNHFeBsxsETSGnL95314sWyuXrMYYP/zznHN6zvv83uft87zvw4tnzRYho/HGMmrEMmpOxGg5MWuAiNFBzOofE30uN0Ao0yJWkuKXBsL41LWIo5KkQijVeiVKo4XHlyV5GcUmqBKLllWJRYiXmyFg1AgHEbgXxKVAqjJDaS6A0mRDQtpmsMZsyNNyIDeuLoUpd1mqNiM2LsXLy9Xsw+H875eP5N9Fi+Vn7rWcL7hk5RYIZCshAjMXiNVItW7FKxcG0OCZgmtoAq6hcTj7PkRp77sou/QeynojiqMi71w8vmzYvg28g5u/4Tpsi2izLnBuyxz3ZiFQajqPGFki4thnHlsCgUSN8nd60HLjSzSNXcP+8es4MPEZXFfHYb/SA/uVbr+NKM4+2M1VjZxC8Udvczy/Y7gt81yr5R46bEtwZvQhlkmJsP56OM+cx8GpG2gcnfFBjM2iYXQS9oEeVAycWIu4iv4uEBCe2zJPZk8AQAA6bb/BkXE5PACrg0imQ9XJc2ie/RxNnhk0jc5i/9h1NIz8BWAf7A46C173d6Gin1jfNXlefvl9rAtALNdBJNbBuetjNM/cROP0FJqmZ9A0fQ0N0xOo9pwOOg2I3FcOnUT16GmQsFN5TsFx9Qzy6uvAa7P6AIhdFYDVQ8ikotY8gnbHPA7Vf43D+7xorf8OrrqbKDzUAPtQyDL0d1HHzx07AP22l5BWVgxjyQ5qtS9spUvK2xBA1jA6836HO2sBbVn30ZGzCFfqbRhfLEalp8cX5oETNMTOqXPIrnPg6acYCMQp4Mcmgy9IgkBIsky/QYBMDzoKFtFquwe3bQ5Hn30IV8YtpJdUrATo64Jz8ixy9tZSx5JEI+IUBiqS0hEBnBRAQ+vAoxIxWgrQaVui75MMOlrwEC7zLZh3lIcH2FODmBiVz/EjE+KFA6jO6EWMTAkho6EgJBo+q4FAloyazKHoAXTYlugM5Yo8JCRY/bIErSIhH7uzJ0GKVyutH08QwB1MyTlSniPoLv09kLpPFKDNPyixr1t/iajQ96IUgXk6cGTNRzsC99FufRBR5PeoRqDF8iMa8+5E0FdosfwUnQi0+tNwZ+Yg3Yql8nTEU5mDVsKasCtrzJ8FUaoDjoxLNN9J0SEi1S9wTWpCTeZwdAuRI1iKQz/wXf8jldCxhr3gf4DO/8wSuNdzJPv3AAz/PcBAGAB+xCVYWPOxPJiGWR502H4NArQXPIDLfBvpJXbYh7tXHskmziJ3b+3KCDB6zjeWnltnY2IAX6ZCVfoFHCvkghvTG4V/YI/5U2iKttBTb+UnvgaFQOyc/gDpjgrw+UkBAOKcEzFkPB23vtaMNUAgS4JW9TIac+/QPeFI/g9ozv8WWSm7ESNVwtb8Ko1A6cXj9FT8/FvNiE8yQSTTUuciRkedi1jdMrFhmlPTKs0pgUim+wR5n4hRZEPAJNOmRShNBWsINKqb6DdCKXUeOt6ymNFBxOq9vA2156wBQrov0G/oHzO0bNNWnLTg8WQPCY1gIPw6cu8Vs3rLnwIWEm0oy+KXAAAAAElFTkSuQmCC",
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;     # Global info hash
    my ($save_title) = @_;    # Plugin parameter
    my $ua       = $lrr_info->{user_agent};
    my $logger = get_plugin_logger();
    my $archive_title = $lrr_info->{archive_title};

    # Possible improvement: Detect any currently set hentag URLs, fetch based on that id.
    # Endpoint: /api/v1/search/vault/id with payload {"ids": [id]}

    # Another possible improvement: Detect any other existing source tags, perform search based on that
    # Endpoint: /api/v1/search/vault/url with payload {"urls": [url1, url2, ...]}

    my $stringjson = get_json_from_api($ua, $archive_title, $logger);

    if ($stringjson ne '') {
        $logger->debug("Received the following JSON: $stringjson");
        my $json = from_json($stringjson);

        #Parse it
        my ( $tags, $title ) = tags_from_hentag_api_json($json);

        #Return tags IFF data is found
        $logger->info("Sending the following tags to LRR: $tags");
        if ( $save_title && $title ) {
            $logger->info("Parsed title is $title");
            return ( tags => $tags, title => $title );
        } elsif ($tags ne "") {
            return ( tags => $tags );
        }
    }

    return ( error => "No matching Hentag Archive Found!" );
}

# Fairly good for mocking in tests
# get_json_from_api(ua, archive_title, logger)
sub get_json_from_api {
    my ($ua, $archive_title, $logger) = @_;
    my $stringjson = '';
    my $url = Mojo::URL->new('https://hentag.com/api/v1/search/vault/title');
    $logger->info("Hentag search for $archive_title");

    my $res = $ua->post($url => json => {title => $archive_title})->result;

    if ($res->is_success) {
        $stringjson = $res->body;
        $logger->info('Successful request, response: '.$stringjson);
    }
    return $stringjson;
}

sub tags_from_hentag_api_json {
    my ($json) = @_;

    # The JSON can contain multiple hits. Loop through them and pick the "best" one using the "pick the first one"-algorithm.
    # Possible improvement: Look for hits with "better" metadata (more tags, more tags in namespaces, etc).
    foreach my $work (@$json) {
        my ( $tags, $title ) = LANraragi::Plugin::Metadata::Hentag::tags_from_hentag_json($work);
        return ($tags, $title);
    }
}

1;
