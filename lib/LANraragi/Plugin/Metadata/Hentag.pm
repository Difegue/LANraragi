package LANraragi::Plugin::Metadata::Hentag;

use strict;
use warnings;

#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use Mojo::JSON qw(from_json);

#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::Archive qw(is_file_in_archive extract_file_from_archive);

#Meta-information about your plugin.
sub plugin_info {

    return (
        name        => "Hentag",
        type        => "metadata",
        namespace   => "hentagplugin",
        author      => "siliconfeces",
        version     => "0.1",
        description => "Parses Hentag info.json files embedded in archives. Achtung, no API calls!",
		parameters  => [{ type => "bool", desc => "Save archive title" }],
        icon =>
           "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAACXBIWXMAAAPoAAAD6AG1e1JrAAAEzklEQVR4nO2Xa0xbZRjH6xe/0NKW0p7TQgul9GJpuQ0YbcFgXFx0M+NaoF0gY4mbkwLLxjYoMoiZMVGnDJZt2TT7plnGxmVCgXEdi859MGabH0xqNHFeBsxsETSGnL95314sWyuXrMYYP/zznHN6zvv83uft87zvw4tnzRYho/HGMmrEMmpOxGg5MWuAiNFBzOofE30uN0Ao0yJWkuKXBsL41LWIo5KkQijVeiVKo4XHlyV5GcUmqBKLllWJRYiXmyFg1AgHEbgXxKVAqjJDaS6A0mRDQtpmsMZsyNNyIDeuLoUpd1mqNiM2LsXLy9Xsw+H875eP5N9Fi+Vn7rWcL7hk5RYIZCshAjMXiNVItW7FKxcG0OCZgmtoAq6hcTj7PkRp77sou/QeynojiqMi71w8vmzYvg28g5u/4Tpsi2izLnBuyxz3ZiFQajqPGFki4thnHlsCgUSN8nd60HLjSzSNXcP+8es4MPEZXFfHYb/SA/uVbr+NKM4+2M1VjZxC8Udvczy/Y7gt81yr5R46bEtwZvQhlkmJsP56OM+cx8GpG2gcnfFBjM2iYXQS9oEeVAycWIu4iv4uEBCe2zJPZk8AQAA6bb/BkXE5PACrg0imQ9XJc2ie/RxNnhk0jc5i/9h1NIz8BWAf7A46C173d6Gin1jfNXlefvl9rAtALNdBJNbBuetjNM/cROP0FJqmZ9A0fQ0N0xOo9pwOOg2I3FcOnUT16GmQsFN5TsFx9Qzy6uvAa7P6AIhdFYDVQ8ikotY8gnbHPA7Vf43D+7xorf8OrrqbKDzUAPtQyDL0d1HHzx07AP22l5BWVgxjyQ5qtS9spUvK2xBA1jA6836HO2sBbVn30ZGzCFfqbRhfLEalp8cX5oETNMTOqXPIrnPg6acYCMQp4Mcmgy9IgkBIsky/QYBMDzoKFtFquwe3bQ5Hn30IV8YtpJdUrATo64Jz8ixy9tZSx5JEI+IUBiqS0hEBnBRAQ+vAoxIxWgrQaVui75MMOlrwEC7zLZh3lIcH2FODmBiVz/EjE+KFA6jO6EWMTAkho6EgJBo+q4FAloyazKHoAXTYlugM5Yo8JCRY/bIErSIhH7uzJ0GKVyutH08QwB1MyTlSniPoLv09kLpPFKDNPyixr1t/iajQ96IUgXk6cGTNRzsC99FufRBR5PeoRqDF8iMa8+5E0FdosfwUnQi0+tNwZ+Yg3Yql8nTEU5mDVsKasCtrzJ8FUaoDjoxLNN9J0SEi1S9wTWpCTeZwdAuRI1iKQz/wXf8jldCxhr3gf4DO/8wSuNdzJPv3AAz/PcBAGAB+xCVYWPOxPJiGWR502H4NArQXPIDLfBvpJXbYh7tXHskmziJ3b+3KCDB6zjeWnltnY2IAX6ZCVfoFHCvkghvTG4V/YI/5U2iKttBTb+UnvgaFQOyc/gDpjgrw+UkBAOKcEzFkPB23vtaMNUAgS4JW9TIac+/QPeFI/g9ozv8WWSm7ESNVwtb8Ko1A6cXj9FT8/FvNiE8yQSTTUuciRkedi1jdMrFhmlPTKs0pgUim+wR5n4hRZEPAJNOmRShNBWsINKqb6DdCKXUeOt6ymNFBxOq9vA2156wBQrov0G/oHzO0bNNWnLTg8WQPCY1gIPw6cu8Vs3rLnwIWEm0oy+KXAAAAAElFTkSuQmCC",
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;     # Global info hash
    my ($save_title) = @_;    # Plugin parameter

    my $logger = get_plugin_logger();
    my $file   = $lrr_info->{file_path};

    my $path_in_archive = is_file_in_archive( $file, "info.json" );

    if ($path_in_archive) {
        #Extract info.json
        my $filepath = extract_file_from_archive( $file, $path_in_archive );

        #Open it
        my $stringjson = "";

        open( my $fh, '<:encoding(UTF-8)', $filepath )
          or return ( error => "Could not open $filepath!" );

        while ( my $row = <$fh> ) {
            chomp $row;
            $stringjson .= $row;
        }

        #Use Mojo::JSON to decode the string into a hash
        my $hashjson = from_json $stringjson;

        $logger->debug("Found and loaded the following JSON: $stringjson");

        #Parse it
        my ( $tags, $title ) = tags_from_hentag_json($hashjson);

        #Delete it
        unlink $filepath;

        #Return tags
        $logger->info("Sending the following tags to LRR: $tags");
        if ( $save_title && $title ) {
            $logger->info("Parsed title is $title");
            return ( tags => $tags, title => $title );
        } elsif ($tags ne "") {
            return ( tags => $tags );
        }
    }

    return ( error => "No hentag info.json file found in this archive!" );
}

#tags_from_hentag_json(decodedjson)
#Goes through the JSON hash obtained from an info.json file and return the contained tags (and title if found).
sub tags_from_hentag_json {
    my ($hash) = @_;
    my @found_tags;

    my $title      = $hash->{"title"};
    my $parodies   = $hash->{"parodies"};
    my $groups     = $hash->{"circles"};
    my $artists    = $hash->{"artists"};
    my $characters = $hash->{"characters"};
    my $maleTags   = $hash->{"maleTags"};
    my $femaleTags = $hash->{"femaleTags"};
    my $otherTags  = $hash->{"otherTags"};
    my $language   = language_from_hentag_json($hash);
    my $urls       = $hash->{"locations"};
    # not handled yet: category, createdAt

    # tons of different shit creates different kinds of info.json file, so validate the shit out of the data
    @found_tags = try_add_tags(\@found_tags, "series:", $parodies);
    @found_tags = try_add_tags(\@found_tags, "group:", $groups);
    @found_tags = try_add_tags(\@found_tags, "artist:", $artists);
    @found_tags = try_add_tags(\@found_tags, "character:", $characters);
    @found_tags = try_add_tags(\@found_tags, "male:", $maleTags);
    @found_tags = try_add_tags(\@found_tags, "female:", $femaleTags);
    @found_tags = try_add_tags(\@found_tags, "other:", $otherTags);
    push( @found_tags, "language:" . $language ) unless !defined $language;
    @found_tags = try_add_tags(\@found_tags, "source:", $urls);

    #Done-o
    my $concat_tags = join( ", ", @found_tags );
    return ( $concat_tags, $title );

}

sub language_from_hentag_json {
    my ($hash) = @_;

    my $language   = $hash->{"language"};
    return $language;
}

sub try_add_tags {
    my @found_tags = @{$_[0]};
    my $prefix = $_[1];
    my $tags = $_[2];
    my @potential_tags;

    if (ref($tags) eq 'ARRAY') {
        foreach my $tag (@$tags) {
            if (ref($tag) eq 'HASH' || ref($tag) eq 'ARRAY') {
                # Weird stuff in here, don't continue parsing to avoid garbage data
                return @found_tags;
            }
            push( @potential_tags, $prefix . $tag );
        }
    }

    push(@found_tags, @potential_tags);
    return @found_tags;
}

1;
