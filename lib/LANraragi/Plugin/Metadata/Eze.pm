package LANraragi::Plugin::Metadata::Eze;

use strict;
use warnings;

#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use Mojo::JSON qw(from_json);
use File::Basename;
use Time::Local qw(timegm_modern);

#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Database;
use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::String  qw(trim);
use LANraragi::Utils::Archive qw(is_file_in_archive extract_file_from_archive);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "eze",
        type        => "metadata",
        namespace   => "ezeplugin",
        author      => "Difegue",
        version     => "2.4",
        description =>
          "Collects metadata from eze-style info.json files ({'gallery_info': {xxx} } syntax), either embedded in your archive or in the same folder with the same name. ({archive_name}.json)",
        icon =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAACXBIWXMAAAsTAAALEwEAmpwYAAAA\nB3RJTUUH4wYCFDYBnHlU6AAAAB1pVFh0Q29tbWVudAAAAAAAQ3JlYXRlZCB3aXRoIEdJTVBkLmUH\nAAAETUlEQVQ4y22UTWhTWRTHf/d9JHmNJLFpShMcKoRIqxXE4sKpjgthYLCLggU/wI1CUWRUxlmU\nWblw20WZMlJc1yKKKCjCdDdYuqgRiygq2mL8aJpmQot5uabv3XdnUftG0bu593AOv3M45/yvGBgY\n4OrVqwRBgG3bGIaBbduhDSClxPM8tNZMTEwwMTGB53lYloXWmkgkwqdPnygUCljZbJbW1lYqlQqG\nYYRBjuNw9+5dHj16RD6fJ51O09bWxt69e5mammJ5eZm1tTXi8Tiu6xKNRrlx4wZWNBqlXq8Tj8cx\nTRMhBJZlMT4+zuXLlxFCEIvFqFarBEFAKpXCcRzq9TrpdJparcbIyAiHDh1icXERyzAMhBB4nofv\n+5imiWmavHr1inQ6jeM4ZLNZDMMglUqxuLiIlBLXdfn48SNKKXp6eqhUKiQSCaxkMsna2hqe52Hb\nNsMdec3n8+Pn2+vpETt37qSlpYVyucz8/DzT09Ns3bqVYrEIgOM4RCIRrI1MiUQCz/P43vE8jxcv\nXqCUwvM8Zmdn2bJlC6lUitHRUdrb2zFNE9/3sd6/f4/jOLiuSzKZDCH1wV/EzMwM3d3dNN69o729\nnXK5jFKKPXv2sLS0RF9fHydOnMD3fZRSaK0xtNYEQYBpmtTr9RC4b98+LMsCwLZtHj9+TCwWI5/P\nI6Xk5MmTXLhwAaUUG3MA4M6dOzQaDd68eYOUkqHIZj0U2ay11mzfvp1du3YhhGBgYIDjx4/T3d1N\nvV4nCAKklCilcF2XZrOJlBIBcOnSJc6ePYsQgj9yBf1l//7OJcXPH1Y1wK/Ff8SfvT995R9d/SA8\nzyMaja5Xq7Xm1q1bLCwssLS09M1Atm3bFr67urq+8W8oRUqJlBJLCMHNmze5d+8e2Ww2DPyrsSxq\ntRqZTAattZibm6PZbHJFVoUQgtOxtAbwfR8A13WJxWIYANVqFd/36e/v/ypzIpEgCAKEEMzNzYXN\n34CN/FsSvu+jtSaTyeC67jrw4cOHdHZ2kslkQmCz2SQSiYT269evMU0zhF2RVaH1ejt932dlZYXh\n4eF14MLCArZtI6UMAb+1/qBPx9L6jNOmAY4dO/b/agBnnDb9e1un3vhQzp8/z/Xr19eBQgjevn3L\n1NTUd5WilKJQKGAYxje+lpYWrl27xuTk5PqKARSLRfr6+hgaGiKbzfLy5UvGx8dRSqGUwnEcDMNA\nKYUQIlRGNBplZmaGw4cPE4/HOXDgAMbs7Cy9vb1cvHiR+fl5Hjx4QC6XwzAMYrEYz549Y3p6mufP\nn4d6NU0Tx3GYnJzk6NGjNJtNduzYQUdHB+LL8mu1Gv39/WitGRsb4/79+3R1dbF7925yuVw4/Uaj\nwalTpzhy5AhjY2P4vs/BgwdJp9OYG7ByuUwmk6FUKgFw7tw5SqUSlUqFp0+fkkgk2LRpEysrKzx5\n8oTBwUG01ty+fZv9+/eTz+dZXV3lP31rAEu+yXjEAAAAAElFTkSuQmCC",
        parameters => [
            {   type => "bool",
                desc => "Save the original title when available instead of the English or romanised title"
            },
            { type => "bool", desc => "Fetch additional timestamp (time posted) and uploader metadata" },
        ]
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;                           # Global info hash
    my ( $origin_title, $additional_tags ) = @_;    # Plugin parameters

    my $logger = get_plugin_logger();

    my $path_in_archive = is_file_in_archive( $lrr_info->{file_path}, "info.json" );

    my ( $name, $path, $suffix ) = fileparse( $lrr_info->{file_path}, qr/\.[^.]*/ );
    my $path_nearby_json = $path . $name . '.json';

    my $filepath;
    my $delete_after_parse;

    #Extract info.json
    if ($path_in_archive) {
        $filepath = extract_file_from_archive( $lrr_info->{file_path}, $path_in_archive );
        $logger->debug("Found file in archive at $filepath");
        $delete_after_parse = 1;
    } elsif ( -e $path_nearby_json ) {
        $filepath = $path_nearby_json;
        $logger->debug("Found file nearby at $filepath");
        $delete_after_parse = 0;
    } else {
        die "No in-archive info.json or {archive_name}.json file found!\n";
    }

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

    $logger->debug("Loaded the following JSON: $stringjson");

    if ($hashjson->{gallery_info} == undef) {
        return (error => "The info.json file could not be parsed as an eze file!");
    }

    #Parse it
    my ( $tags, $title ) = tags_from_eze_json( $origin_title, $additional_tags, $hashjson );

    if ($delete_after_parse) {

        #Delete it
        unlink $filepath;
    }

    #Return tags
    $logger->info("Sending the following tags to LRR: $tags");

    if ($title) {
        $logger->info("Parsed title is $title");
        return ( tags => $tags, title => $title );
    } else {
        return ( tags => $tags );
    }

}

#tags_from_eze_json(decodedjson)
#Goes through the JSON hash obtained from an info.json file and return the contained tags.
sub tags_from_eze_json {

    my ( $origin_title, $additional_tags, $hash ) = @_;
    my $return = "";

    #Tags are in gallery_info -> tags -> one array per namespace
    my $tags = $hash->{"gallery_info"}->{"tags"};

    # Titles returned by eze are in complete E-H notation.
    my $title = $hash->{"gallery_info"}->{"title"};

    if ( $origin_title && $hash->{"gallery_info"}->{"title_original"} ) {
        $title = $hash->{"gallery_info"}->{"title_original"};
    }

    $title = trim($title);

    foreach my $namespace ( sort keys %$tags ) {

        # Get the array for this namespace and iterate on it
        my $members = $tags->{$namespace};
        foreach my $tag (@$members) {

            $return .= ", " unless $return eq "";
            $return .= $namespace . ":" . $tag;

        }
    }

    # Add source tag if possible
    my $site      = $hash->{"gallery_info"}->{"source"}->{"site"};
    my $gid       = $hash->{"gallery_info"}->{"source"}->{"gid"};
    my $gtoken    = $hash->{"gallery_info"}->{"source"}->{"token"};
    my $category  = $hash->{"gallery_info"}->{"category"};
    my $uploader  = $hash->{"gallery_info_full"}->{"uploader"};
    my $timestamp = $hash->{"gallery_info_full"}->{"date_uploaded"};

    if ($timestamp) {

        # convert microsecond to second
        $timestamp = $timestamp / 1000;
    } else {
        my $upload_date = $hash->{"gallery_info"}->{"upload_date"};
        if ($upload_date) {
            my $time = timegm_modern( $$upload_date[5], $$upload_date[4], $$upload_date[3], $$upload_date[2], $$upload_date[1] - 1,
                $$upload_date[0] );
            $timestamp = $time;
        }
    }

    if ($category) {
        $return .= ", category:$category";
    }

    if ( $additional_tags && $uploader ) {
        $return .= ", uploader:$uploader";
    }

    if ( $additional_tags && $timestamp ) {
        $return .= ", timestamp:$timestamp";
    }

    if ( $site && $gid && $gtoken ) {
        $return .= ", source:$site.org/g/$gid/$gtoken";
    }

    #Done-o
    return ( $return, $title );

}

1;
