package LANraragi::Plugin::Metadata::HentagOnline;

use strict;
use warnings;
use feature qw(signatures);
no warnings 'experimental::signatures';

use URI::Escape;
use Mojo::JSON qw(from_json);
use Mojo::UserAgent;

#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_plugin_logger);

use LANraragi::Utils::String;
use String::Similarity;

# Most parsing is reused between the two plugins
require LANraragi::Plugin::Metadata::Hentag;

#Meta-information about your plugin.
sub plugin_info {

    return (
        name        => "Hentag Online Lookups",
        type        => "metadata",
        namespace   => "hentagonlineplugin",
        author      => "siliconfeces",
        version     => "0.2",
        description => "Searches hentag.com for tags matching your archive",
        parameters  => [
            {   type => "string",
                desc =>
                  "Comma-separated list of languages to consider. First language = most preferred. Default is \"english, japanese\""
            }
        ],
        oneshot_arg => "Hentag.com vault URL (Will attach matching tags to your archive)",
        icon        =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAACXBIWXMAAAPoAAAD6AG1e1JrAAAEzklEQVR4nO2Xa0xbZRjH6xe/0NKW0p7TQgul9GJpuQ0YbcFgXFx0M+NaoF0gY4mbkwLLxjYoMoiZMVGnDJZt2TT7plnGxmVCgXEdi859MGabH0xqNHFeBsxsETSGnL95314sWyuXrMYYP/zznHN6zvv83uft87zvw4tnzRYho/HGMmrEMmpOxGg5MWuAiNFBzOofE30uN0Ao0yJWkuKXBsL41LWIo5KkQijVeiVKo4XHlyV5GcUmqBKLllWJRYiXmyFg1AgHEbgXxKVAqjJDaS6A0mRDQtpmsMZsyNNyIDeuLoUpd1mqNiM2LsXLy9Xsw+H875eP5N9Fi+Vn7rWcL7hk5RYIZCshAjMXiNVItW7FKxcG0OCZgmtoAq6hcTj7PkRp77sou/QeynojiqMi71w8vmzYvg28g5u/4Tpsi2izLnBuyxz3ZiFQajqPGFki4thnHlsCgUSN8nd60HLjSzSNXcP+8es4MPEZXFfHYb/SA/uVbr+NKM4+2M1VjZxC8Udvczy/Y7gt81yr5R46bEtwZvQhlkmJsP56OM+cx8GpG2gcnfFBjM2iYXQS9oEeVAycWIu4iv4uEBCe2zJPZk8AQAA6bb/BkXE5PACrg0imQ9XJc2ie/RxNnhk0jc5i/9h1NIz8BWAf7A46C173d6Gin1jfNXlefvl9rAtALNdBJNbBuetjNM/cROP0FJqmZ9A0fQ0N0xOo9pwOOg2I3FcOnUT16GmQsFN5TsFx9Qzy6uvAa7P6AIhdFYDVQ8ikotY8gnbHPA7Vf43D+7xorf8OrrqbKDzUAPtQyDL0d1HHzx07AP22l5BWVgxjyQ5qtS9spUvK2xBA1jA6836HO2sBbVn30ZGzCFfqbRhfLEalp8cX5oETNMTOqXPIrnPg6acYCMQp4Mcmgy9IgkBIsky/QYBMDzoKFtFquwe3bQ5Hn30IV8YtpJdUrATo64Jz8ixy9tZSx5JEI+IUBiqS0hEBnBRAQ+vAoxIxWgrQaVui75MMOlrwEC7zLZh3lIcH2FODmBiVz/EjE+KFA6jO6EWMTAkho6EgJBo+q4FAloyazKHoAXTYlugM5Yo8JCRY/bIErSIhH7uzJ0GKVyutH08QwB1MyTlSniPoLv09kLpPFKDNPyixr1t/iajQ96IUgXk6cGTNRzsC99FufRBR5PeoRqDF8iMa8+5E0FdosfwUnQi0+tNwZ+Yg3Yql8nTEU5mDVsKasCtrzJ8FUaoDjoxLNN9J0SEi1S9wTWpCTeZwdAuRI1iKQz/wXf8jldCxhr3gf4DO/8wSuNdzJPv3AAz/PcBAGAB+xCVYWPOxPJiGWR502H4NArQXPIDLfBvpJXbYh7tXHskmziJ3b+3KCDB6zjeWnltnY2IAX6ZCVfoFHCvkghvTG4V/YI/5U2iKttBTb+UnvgaFQOyc/gDpjgrw+UkBAOKcEzFkPB23vtaMNUAgS4JW9TIac+/QPeFI/g9ozv8WWSm7ESNVwtb8Ko1A6cXj9FT8/FvNiE8yQSTTUuciRkedi1jdMrFhmlPTKs0pgUim+wR5n4hRZEPAJNOmRShNBWsINKqb6DdCKXUeOt6ymNFBxOq9vA2156wBQrov0G/oHzO0bNNWnLTg8WQPCY1gIPw6cu8Vs3rLnwIWEm0oy+KXAAAAAElFTkSuQmCC",
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;
    my ($allowed_languages) = @_;

    my $ua                = $lrr_info->{user_agent};
    my $oneshot_param     = $lrr_info->{oneshot_param};
    my $logger            = get_plugin_logger();
    my $raw_existing_tags = $lrr_info->{existing_tags};
    my @existing_tags;

    if ( defined($raw_existing_tags) ) {
        @existing_tags = split( ',', $lrr_info->{existing_tags} );
    }

    if ( !defined($allowed_languages) || $allowed_languages eq '' ) {

        # Weeby default
        $allowed_languages = "english, japanese";
    }

    my $vault_id;
    my @source_urls   = undef;
    my $archive_title = undef;

    # First, try running based on a vault ID from a hentag URL
    if ( defined($oneshot_param) && $oneshot_param ne '' ) {
        $logger->info("Oneshot param = $oneshot_param");

        # URL was passed as a oneshot param, done!
        $vault_id = parse_vault_url($oneshot_param);
        if ( !defined($vault_id) ) {
            $logger->info("Failed parsing URL $oneshot_param");

            # Don't continue execution if the oneshot URL was invalid. Raise an error instead to avoid surprises
            return ( error => "Did not recognize the URL, is it a proper vault URL?" );
        }
    } elsif ( my $hentag_source = get_existing_hentag_source_url(@existing_tags) ) {

       # There might be a hentag URL inside a tag. If it fails parsing, that's okay, just continue execution with any other approach
        if ( defined($hentag_source) ) {
            $logger->info("Found an existing (parsable) hentag source, will use that!");
            $vault_id = parse_vault_url($hentag_source);
        }
    } else {

        # Try to fetch any other existing source tags
        @source_urls = get_source_tags(@existing_tags);
    }

    my $string_json = '';
    if ( defined($vault_id) ) {

        # Use a vault ID for lookups
        $logger->info('Vault ID run');
        $string_json = get_json_by_vault_id( $ua, $vault_id, $logger );
    } elsif (@source_urls) {

        # Use existing URL tags for lookups
        $logger->info('URL lookup run');
        $string_json = get_json_by_urls( $ua, $logger, @source_urls );
    } else {

        # Title lookup
        $logger->info('Title lookup');
        $archive_title = $lrr_info->{archive_title};

        if ( $string_json eq '' ) {
            $string_json = get_json_by_title( $ua, $archive_title, $logger );
        }
    }

    if ( $string_json ne '' ) {
        $logger->debug("Received the following JSON: $string_json");
        my $json = from_json($string_json);

        #Parse it
        my ( $tags, $title ) = tags_from_hentag_api_json( $json, $allowed_languages, $archive_title );

        #Return tags IFF data is found
        $logger->info("Sending the following tags to LRR: $tags");
        if ($title) {
            $logger->info("Parsed title is $title");
            return ( tags => $tags, title => $title );
        } elsif ( $tags ne "" ) {
            return ( tags => $tags );
        }
    }

    return ( error => "No matching Hentag Archive Found!" );
}

# Returns the ID from a hentag URL, or undef if invalid.
sub parse_vault_url ($url) {
    if ( !defined $url ) {
        return;
    }
    if ( $url =~ /https?:\/\/(?:www\.)?hentag\.com\/vault\/([a-zA-Z0-9]*)\/?.*/ ) {
        return $1;
    }
    return;
}

# Fairly good for mocking in tests
# get_json_by_title(ua, archive_title, logger)
sub get_json_by_title ( $ua, $archive_title, $logger ) {
    my $string_json = '';
    my $url         = Mojo::URL->new('https://hentag.com/api/v1/search/vault/title');
    $logger->info("Hentag search for $archive_title");

    my $res = $ua->post( $url => json => { title => $archive_title } )->result;

    if ( $res->is_success ) {
        $string_json = $res->text;
        $logger->info( 'Successful request, response: ' . $string_json );
    }
    return $string_json;
}

# Fairly good for mocking in tests
# Returns the json response (as a string) from hentag. If no response, an empty string is returned.
sub get_json_by_vault_id ( $ua, $vault_id, $logger ) {
    my $string_json = '';
    my $url         = Mojo::URL->new('https://hentag.com/api/v1/search/vault/id');
    $logger->info("Hentag search for $vault_id");

    my $res = $ua->post( $url => json => { ids => [$vault_id] } )->result;

    if ( $res->is_success ) {
        $string_json = $res->text;
        $logger->info( 'Successful request, response: ' . $string_json );
    }
    return $string_json;
}

# Fairly good for mocking in tests
# Returns the json response (as a string) from hentag. If no response, an empty string is returned.
sub get_json_by_urls ( $ua, $logger, @urls ) {
    my $string_json = '';
    my $url         = Mojo::URL->new('https://hentag.com/api/v1/search/vault/url');
    $logger->info("Hentag search based on URLs: @urls");
    my $res = $ua->post( $url => json => { urls => \@urls } )->result;

    if ( $res->is_success ) {
        $string_json = $res->text;
        $logger->info( 'Successful request, response: ' . $string_json );
    }
    return $string_json;
}

# Fetches tags and title, restricted to a language
# If $title_hint is set, it attempts to pick the "best" result if multiple hits were returned from Hentag
sub tags_in_language_from_hentag_api_json ( $json, $language, $title_hint = undef ) {
    $language =~ s/^\s+|\s+$//g;
    $language = lc($language);

    # The JSON can contain multiple hits. Fetch all that match the requested language
    my @lang_json_pairs = map { LANraragi::Plugin::Metadata::Hentag::language_from_hentag_json($_) eq $language ? $_ : () } @$json;

    if (@lang_json_pairs) {

        # Possible improvement: Look for hits with "better" metadata (more tags, more tags in namespaces, etc).
        my ( $tags, $title ) =
          LANraragi::Plugin::Metadata::Hentag::tags_from_hentag_json( pick_best_hit( $title_hint, @lang_json_pairs ) );
        return ( $tags, $title );
    }
    return ( '', '' );
}

# Returns (string_with_tags, string_with_title) on success, (empty_string, empty_string) on failure
sub tags_from_hentag_api_json ( $json, $string_prefered_languages, $title_hint = undef ) {
    my @prefered_languages = split( ",", $string_prefered_languages );
    foreach my $language (@prefered_languages) {
        my ( $tags, $title ) = tags_in_language_from_hentag_api_json( $json, $language, $title_hint );
        if ( $tags ne '' ) {
            return ( $tags, $title );
        }
    }
    return ( '', '' );
}

sub get_existing_hentag_source_url (@tags) {
    foreach my $tag ( get_source_tags(@tags) ) {
        if ( parse_vault_url($tag) ) {
            return $tag;
        }
    }
    return;
}

sub get_source_tags (@tags) {
    my @found_tags;
    foreach my $tag (@tags) {
        if ( $tag =~ /.*source:(.*)/ ) {
            push( @found_tags, $1 );
        }
    }
    return @found_tags;
}

sub pick_best_hit ( $title_hint, @hits ) {
    if ( !defined($title_hint) ) {
        return $hits[0];
    }
    $title_hint = lc( LANraragi::Utils::String::clean_title($title_hint) );

    my @titles;
    while ( my ( $index, $elem ) = each @hits ) {
        my ( $tags, $title ) = LANraragi::Plugin::Metadata::Hentag::tags_from_hentag_json($elem);
        $titles[$index] = lc( LANraragi::Utils::String::clean_title($title) );
    }
    return $hits[ LANraragi::Utils::String::most_similar( $title_hint, @titles ) ];
}

1;
