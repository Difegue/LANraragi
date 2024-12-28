package LANraragi::Plugin::Metadata::Koromo;

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
        #Standard metadata
        name        => "koromo",
        type        => "metadata",
        namespace   => "koromoplugin",
        author      => "CirnoT, Difegue",
        version     => "2.2",
        description => "Collects metadata embedded into your archives as Koromo-style Info.json files. ( {'Tags': [xxx] } syntax)",
        icon        =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABhGlDQ1BJQ0MgcHJvZmlsZQAAKJF9kT1Iw1AUhU9TpVoqDmYQcchQnSyIijhKFYtgobQVWnUweekfNDEkKS6OgmvBwZ/FqoOLs64OroIg+APi4uqk6CIl3pcUWsR44fE+zrvn8N59gNCoMs3qGgc03TbTibiUy69IoVeE0QsRAYgys4xkZiEL3/q6pz6quxjP8u/7s/rUgsWAgEQ8ywzTJl4nnt60Dc77xCIryyrxOfGYSRckfuS64vEb55LLAs8UzWx6jlgklkodrHQwK5sa8RRxVNV0yhdyHquctzhr1Rpr3ZO/MFLQlzNcpzWMBBaRRAoSFNRQQRU2YrTrpFhI03ncxz/k+lPkUshVASPHPDagQXb94H/we7ZWcXLCS4rEge4Xx/kYAUK7QLPuON/HjtM8AYLPwJXe9m80gJlP0uttLXoE9G8DF9dtTdkDLneAwSdDNmVXCtISikXg/Yy+KQ8M3ALhVW9urXOcPgBZmtXSDXBwCIyWKHvN5909nXP7t6c1vx8dzXKFeWpUawAAAAZiS0dEAOwAEABqpSa6lwAAAAlwSFlzAAAuIwAALiMBeKU/dgAAAAd0SU1FB+MKCRQBJSKMeg0AAAGVSURBVDjLpZMxa9tQFIXPeaiyhxiZzKFjBme1JFfYgYAe9Bd0yA8JIaQhkJLBP6T/wh3qpZYzm2I8dyilJJMTW7yTIVGRFasE8uAt93K+d+5991IS8Ybj1SVIer24ty8Jk2wyl5S/GkDSi+O4s9PaOYOQh91wSHK2DeLViVut1pmkTwAQtAPUQcz/xCRBEpKOg3ZwEnbDDklvK6AQ+77fds4tSJbBcM7Nm83GbhXiVcXj8fiHpO/WWgfgHAAkXYxGoy8k/UG/nzxDnsqRxF7cO0iS5AhAQxKLm6bpVZqmn8sxAI3kQ2KjKDqQ9GRFEqDNfpQcukrMkDRF3ADAJJvM1+v1n0G/n5D0AcBaew3gFMCFtfbyuVT/cHCYrFarX1mWLQCgsAWSXtgNO81mY/ed7380xpyUn3XOXefr/Ntyufw9vZn+LL7zn21J+fRmOru/f/hrjNmThFLOGWPeV8UvBklSTnIWdsNh0A4g6RiAI/n17vZuWBVvncQNSBAYEK5OvNGDbSMdRdE+AJdl2aJumfjWdX4EIwDvDt7UjSEAAAAASUVORK5CYII=",
        parameters => []
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;    # Global info hash

    my $logger = get_plugin_logger();
    my $file   = $lrr_info->{file_path};

    my $path_in_archive = is_file_in_archive( $file, "Info.json" );

    unless ($path_in_archive) {

        # Try for the lowercase variant as well
        $path_in_archive = is_file_in_archive( $file, "info.json" );
    }

    if ( !$path_in_archive ) { die "No koromo info.json file found in this archive!\n"; }

    #Extract info.json
    my $filepath = extract_file_from_archive( $file, $path_in_archive );

    #Open it
    my $stringjson = "";

    open( my $fh, '<:encoding(UTF-8)', $filepath )
      or die "Could not open $filepath!\n";

    while ( my $row = <$fh> ) {
        chomp $row;
        $stringjson .= $row;
    }

    #Use Mojo::JSON to decode the string into a hash
    my $hashjson = from_json $stringjson;

    $logger->debug("Found and loaded the following JSON: $stringjson");

    #Parse it
    my ( $tags, $title ) = tags_from_koromo_json($hashjson);

    #Delete it
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

#tags_from_koromo_json(decodedjson)
#Goes through the JSON hash obtained from an Info.json file and return the contained tags (and title if found).
sub tags_from_koromo_json {

    my $hash = $_[0];
    my @found_tags;

    my $title      = $hash->{"Title"};
    my $tags       = $hash->{"Tags"};
    my $characters = $hash->{"Characters"};
    my $series     = $hash->{"Series"};
    my $magazine   = $hash->{"Magazine"};
    my $parody     = $hash->{"Parody"};
    my $groups     = $hash->{"Groups"};
    my $artist     = $hash->{"Artist"};
    my $artists    = $hash->{"Artists"};
    my $language   = $hash->{"Language"};
    my $type       = $hash->{"Types"};
    my $url        = $hash->{"URL"};

    handle_tag_yaml("", $tags, \@found_tags);
    handle_tag_yaml("character:", $characters, \@found_tags);
    handle_tag_yaml("series:", $series, \@found_tags);
    handle_tag_yaml("group:", $groups);
    handle_tag_yaml("artist:", $artists, \@found_tags);

    handle_tag_yaml("series:", $parody, \@found_tags);
    handle_tag_yaml("artist:", $artist, \@found_tags);
    handle_tag_yaml("magazine:", $magazine, \@found_tags );
    handle_tag_yaml("language:", $language, \@found_tags );
    handle_tag_yaml("category:", $type, \@found_tags );
    handle_tag_yaml("source:", $url, \@found_tags );

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
