package LANraragi::Plugin::Metadata::GalleryDL;

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
        name        => "GalleryDL",
        type        => "metadata",
        namespace   => "gallerydlplugin",
        author      => "Okaros",
        version     => "1.0",
        description =>
            "Collects metadata from gallery-dl-created info.json files, either embedded in your archive or in the same folder with the same name. ({archive_name}.json)",
        parameters => []
    );
}

#This plugin is intended to work with archives and metadata files created using gallery-dl's default metadata structure: https://github.com/mikf/gallery-dl/
#
#The expectation is that including/excluding tags, reformatting titles, and other metadata adjustments will be handled via gallery-dl, so minimal processing/configuration at the Plugin-level is needed when importing into Lanraragi.
#You can configure gallery-dl to write its metadata to either a .json file with the same name as the archive or you can embed an info.json file directly in your archive. Gallery-dl can be configured for either option; This plugin will ignore an external json file if it finds an embedded info.json file.
#
#Different sites supported by gallery-dl use different metadata formats; This plugin should automatically handle tags that arrive either as an array of tag strings (both plain tags and "tag:value" strings) or as nested tag:[values] hashes as long as the metadata json file contains a top-level "tags" entry.
#
#Top-level "category" and "source" metadata entries pulled in or created via gallery-dl will be added as tags so they can be utilized by Lanrargi; Simply exclude or rename these fields if you don't want this behaviour.
#
#Note: If your gallery-dl metadata file contains *no* tag information it will be skipped.
#Note: You will need to generate a top-level 'title' field in your metadata if one isn't present by default (some gallery-dl extractors don't automatically set 'title' when processing pools/galleries/searches/etc...)
#
#An example gallery-dl postprocessor configuration block to create an appropriate external metadata file might simply look like this:
#   {
#     "name": "metadata",
#     "directory": "/path/to/archives",
#     "event": "finalize-success"
#     "filename": "{title}.json",
#   }
#Full configuration of gallery-dl is beyond the scope of this documentation, please check out the gallery-dl documentation if you need more assistance.
#
#Based on the EZE metadata plugin by Difegue

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;                           # Global info hash
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

    if ($hashjson->{tags} == undef) {
        return (error => "The info.json file could not be parsed as a gallery-dl file!");
    }

    #Parse it
    my ( $tags, $title ) = tags_from_gdl_json( $hashjson );

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

#tags_from_gdl_json(decodedjson)
#Goes through the JSON hash obtained from an info.json file and return the contained tags.
sub tags_from_gdl_json {

    my ( $hash ) = @_;
    my $return = "";
    my $logger = get_plugin_logger();

    #Tags are in tags -> one array per namespace
    my $tags = $hash->{"tags"};

    my $title = $hash->{"title"};
    $title = trim($title);

    my $tagstype = ref $hash->{"tags"};
    if ( $tagstype eq ref {}) {
        #If tags is a hash, we need to convert it before chopping it up
        $logger->info("Parsing hash-style tags");
        foreach my $namespace ( sort keys %$tags ) {
            # Get the array for this namespace and iterate on it
            my $members = $tags->{$namespace};
            foreach my $tag (@$members) {
                $return .= ", " unless $return eq "";
                $return .= $namespace . ":" . $tag;
            }
        }
    }
    elsif ( $tagstype eq ref []) {
        #An array of key:value strings is our 'native' format, so we can go straight to chopping it up for processing
        $logger->info("Parsing array-style tags");
        my @taglist = @$tags;
        $return .= join( ', ', @taglist );
    }
    else {
        my $message = "Tags are in an unexpected structure, can't be parsed";
        $logger->error($message);
        die "${message}\n";
    }

    # Add source and category tag if possible
    my $source    = $hash->{"source"};
    my $category  = $hash->{"category"};

    if ($category) {
        $return .= ", category:$category";
    }

    if ( $source ) {
        $return .= ", source:$source";
    }

    return ( $return, $title );
}
1;
