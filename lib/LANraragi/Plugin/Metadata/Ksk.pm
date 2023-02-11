package LANraragi::Plugin::Metadata::Ksk;

use strict;
use warnings;

use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::Archive qw(is_file_in_archive extract_file_from_archive);

use YAML::Syck qw(LoadFile);

sub plugin_info {

    return (
        name        => "ksk",
        type        => "metadata",
        namespace   => "kskplugin",
        author      => "Hackerman",
        version     => "0.001",
        description => "Collects metadata embedded into your archives as koushoku.yaml files.",
        icon =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAABmJLR0QAAAAAAAD5Q7t/AAAACXBI\nWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH4wYDFCYzptBwXAAAAB1pVFh0Q29tbWVudAAAAAAAQ3Jl\nYXRlZCB3aXRoIEdJTVBkLmUHAAAAjUlEQVQ4y82UwQ7AIAhDqeH/f7k7kRgmiozDPKppyisAkpTG\nM6T5vAQBCIAeQQBCUkiWRTV68KJZ1FuG5vY/oazYGdcWh7diy1Bml5We1yiMW4dmQr+W65mPjFjU\n5PMg2P9jKKvUdxWMU8neqYUW4cBpffnxi8TsXk/Qs8GkGGaWhmes1ZmNmr8kuMPwAJzzZSoHwxbF\nAAAAAElFTkSuQmCC",
        parameters => [ { type => "bool", desc => "Save archive title" }, { type => "bool", desc => "Assume english" } ],
    );
}

sub get_tags {
    shift;
    my $lrr_info = shift;
    my ( $save_title, $assume_english ) = @_;
    my $logger = get_plugin_logger();
    my $file   = $lrr_info->{file_path};

    my $path_in_archive = is_file_in_archive( $file, "koushoku.yaml" );

    if ( !$path_in_archive ) {
        return ( error => "No koushoku.yaml file found in archive" );
    }

    my $filepath = extract_file_from_archive( $file, $path_in_archive );

    my $parsed_data = LoadFile($filepath);

    my ( $tags, $title ) = tags_from_ksk_yaml( $parsed_data, $assume_english );

    unlink $filepath;

    #Return tags
    $logger->info("Sending the following tags to LRR: $tags");
    if ( $save_title && $title ) {
        $logger->info("Parsed title is $title");
        return ( tags => $tags, title => $title );
    } else {
        return ( tags => $tags );
    }
}

sub tags_from_ksk_yaml {
    my $hash           = $_[0];
    my $assume_english = $_[1];
    my @found_tags;
    my $logger = get_plugin_logger();

    my $title    = $hash->{"Title"};
    my $tags     = $hash->{"Tags"};
    my $parody   = $hash->{"Parody"};
    my $artists  = $hash->{"Artist"};
    my $magazine = $hash->{"Magazine"};
    my $url      = $hash->{"URL"};

    foreach my $tag (@$tags) {
        push( @found_tags, $tag );
    }
    foreach my $tag (@$artists) {
        push( @found_tags, "artist:" . $tag );
    }
    foreach my $tag (@$parody) {
        push( @found_tags, "series:" . $tag );
    }
    foreach my $tag (@$magazine) {
        push( @found_tags, "magazine:" . $tag );
    }
    if ($assume_english) {
        push( @found_tags, "language:english" );
    }

    push( @found_tags, "source:" . $url ) unless !$url;

    #Done-o
    my $concat_tags = join( ", ", @found_tags );
    return ( $concat_tags, $title );

}

1;
