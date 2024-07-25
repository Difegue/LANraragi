package LANraragi::Plugin::Metadata::Ksk;

use strict;
use warnings;

use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::Archive qw(is_file_in_archive extract_file_from_archive);

use YAML::PP qw(LoadFile);

sub plugin_info {

    return (
        name        => "Koushoku/Koharu.yaml",
        type        => "metadata",
        namespace   => "kskyamlmeta",
        author      => "siliconfeces, Nixis198",
        version     => "0.004",
        description => "Collects metadata embedded into your archives as koushoku.yaml/info.yaml files.",
        icon        =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAAFiUAABYlAUlSJPAAAANkSURBVDhPJZJpU5NXGIbf/9Ev0g+MM7Udp9WWDsVOsRYQKEVZQ4BsZnt9sy9shgShBbTYaTVCKY1B1pBEQggGFOogKEvYdOoXfszVQ/rhmTkz59zXc9/PeaRO12163DZCbgc+8y06HTJ+h5UOp4xLvoXdoOFBf5Auu4LS3obc0oJDp8VhNtLlcyN1uRWcZj13vS5cBi1+mwWPYiLY6cYjG+lxKoR8LgHpw9BQz+OBAbS1tch6DR1uO1Kox4dWVcfdDg9uswGnVSc66wn47QJmwtreTEPFVZxCoKosJ3hbRmlpRt8kNEIrdfscNN+o4tfeHhz6VhHBgqG1nsHeDpxGDV6zDkWjIvxLH25tK2+WUkzcG8JrNdJ/x4803NuJrr4G7Y/X8+UWIl1TDUGfgsfUjl2nwm/WMjrUh72tEXXFNYoKP+b74ks4FQOStuEnVNVlWBtv8kBYcmhVBJwWLOo6vKY2fvbaSD0ZxdnWxKWCj1CVXiEyPIBVuAz6bUiySc0dj0zAbsZtaM1fRH4fwm/RMDYYYCP2lNnfBsn89ZghxcIjMfmxng5GQ92ExIwkj6Kn5UYF6uofhMUG2mvLycYi7GaTnKwvk0vH+XctzXE6weupCFvRCP9MjLMx+Tfdulak4s8KqSr5kppvLmNT3WRQWN5Oz7ObibObnmMnMSXECxwtxdidi7L+Z5jlP0bYnJnEKX5PUpeVshqdINzl475dZnN+kqPsIocrApCa5fVchP3kDAeLc3nQ1vQTNqcjbCZncbQ3It1XZLLhR7wUtTMZZWd2Ugj+f3yYjpFLzbC/OM1BZoHcygJ7KeFEuHu7lsJmViN5G+o4jsd5+fAhKyMjecDJUoK9xDTH4uG753E+bCxxtJpkX5xzmQS5FyniU2MYNCKCsbo8b/84GWf7aZSt2Wi+81kdPU+wPj1OOOAhIHbi3Yu0GGqS07evqCv7llCXA+n6VxcpKTzHwsgwH1bTvBf0g7NOwu7J6jPGQn4iQ4H8XPZErNPNdYIWPZfPn6OvUwDUlVe59vknfHe+gLGAn9PtNQ7XnpHLJjgUdQZ6vy4iCMDxaiq/D8WFBXx9oZCA+DFJI3agougiVV9cyEOqij6l32UkFr6Xz7yfibG3PM/eSoLs1Di2+loaS0uovFIkFlDhPxYUixj0Cgg3AAAAAElFTkSuQmCC",
        parameters => [ { type => "bool", desc => "Assume english" }, { type => "bool", desc => "Add 'Released' tag" } ],
    );
}

sub get_tags {
    shift;
    my $lrr_info = shift;
    my ( $assume_english, $add_released ) = @_;

    my $logger = get_plugin_logger();
    my $file   = $lrr_info->{file_path};

    my $path_in_archive = is_file_in_archive( $file, "koushoku.yaml" );

    if ( !$path_in_archive ) {
        $path_in_archive = is_file_in_archive( $file, "info.yaml" );
    }

    if ( !$path_in_archive ) {
        return ( error => "No KSK metadata file found in archive" );
    }

    my $filepath = extract_file_from_archive( $file, $path_in_archive );

    my $parsed_data = LoadFile($filepath);

    my ( $tags, $title ) = tags_from_ksk_yaml( $parsed_data, $assume_english, $add_released );

    unlink $filepath;

    #Return tags
    $logger->info("Sending the following tags to LRR: $tags");
    if ($title) {
        $logger->info("Parsed title is $title");
        return ( tags => $tags, title => $title );
    } else {
        return ( tags => $tags );
    }
}

sub tags_from_ksk_yaml {
    my $hash           = $_[0];
    my $assume_english = $_[1];
    my $add_released   = $_[2];
    my @found_tags;
    my $logger = get_plugin_logger();

    my $title    = $hash->{"Title"};
    my $tags     = $hash->{"Tags"};
    my $parody   = $hash->{"Parody"};
    my $artists  = $hash->{"Artist"};
    my $magazine = $hash->{"Magazine"};
    my $url      = $hash->{"URL"};
    my $released = $hash->{"Released"};

    handle_tag_yaml( "",          $tags,     \@found_tags );
    handle_tag_yaml( "artist:",   $artists,  \@found_tags );
    handle_tag_yaml( "series:",   $parody,   \@found_tags );
    handle_tag_yaml( "magazine:", $magazine, \@found_tags );

    # Koharu-version tags. Uses namespaces, and keys are lowercase
    if (!defined($title)) {
        $title = $hash->{"title"};
    }
    handle_tag_yaml( "",          $hash->{"general"},  \@found_tags );
    handle_tag_yaml( "male:",     $hash->{"male"},     \@found_tags );
    handle_tag_yaml( "female:",   $hash->{"female"},   \@found_tags );
    handle_tag_yaml( "mixed:",    $hash->{"mixed"},    \@found_tags );
    handle_tag_yaml( "other:",    $hash->{"other"},    \@found_tags );
    handle_tag_yaml( "artist:",   $hash->{"artist"},   \@found_tags );
    handle_tag_yaml( "circle:",   $hash->{"circle"},   \@found_tags );
    handle_tag_yaml( "parody:",   $hash->{"parody"},   \@found_tags );
    handle_tag_yaml( "magazine:", $hash->{"magazine"}, \@found_tags );
    handle_tag_yaml( "language:", $hash->{"language"}, \@found_tags );
    handle_tag_yaml( "source:",   $hash->{"source"},   \@found_tags );

    if ($assume_english) {
        push( @found_tags, "language:english" );
    }
    if ( $add_released && $released ne "" ) {
        push( @found_tags, "date_released:" . $released );
    }

    push( @found_tags, "source:" . $url ) unless !$url;

    #Done-o
    my $concat_tags = join( ", ", @found_tags );
    return ( $concat_tags, $title );

}

sub handle_tag_yaml {
    my $namespace = $_[0];
    my $yamldata  = $_[1];

    # Check if array or string, don't iterate if string
    if ( ref $yamldata eq 'ARRAY' ) {
        foreach my $tag (@$yamldata) {
            push( @{ $_[2] }, "$namespace$tag" );
        }
    } elsif ( defined($yamldata) ) {
        push( @{ $_[2] }, "$namespace$yamldata" );
    }

}

1;
