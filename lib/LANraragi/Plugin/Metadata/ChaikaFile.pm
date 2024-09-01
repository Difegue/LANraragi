package LANraragi::Plugin::Metadata::ChaikaFile;

use strict;
use warnings;

use Mojo::JSON qw(from_json);

use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::Archive qw(is_file_in_archive extract_file_from_archive);

#Meta-information about your plugin.
sub plugin_info {
    return (
        #Standard metadata
        name        => "Chaika.moe api.json",
        type        => "metadata",
        namespace   => "chaikafileplugin",
        author      => "Difegue & Plebs",
        version     => "0.3",
        description => "Collects metadata embedded into your archives as Chaika-style api.json files",
        icon        =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAACXBIWXMAAAsTAAALEwEAmpwYAAAA\nB3RJTUUH4wYCFQocjU4r+QAAAB1pVFh0Q29tbWVudAAAAAAAQ3JlYXRlZCB3aXRoIEdJTVBkLmUH\nAAAEZElEQVQ4y42T3WtTdxzGn/M7J+fk5SRpTk7TxMZkXU84tTbVNrUT3YxO7HA4pdtQZDe7cgx2\ns8vBRvEPsOwFYTDYGJUpbDI2wV04cGXCGFLonIu1L2ptmtrmxeb1JDkvv121ZKVze66f74eH7/f5\nMmjRwMCAwrt4/9KDpflMJpPHvyiR2DPcJklJ3TRDDa0xk36cvrm8vDwHAAwAqKrqjjwXecPG205w\nHBuqa9rk77/d/qJYLD7cCht5deQIIczbgiAEKLVAKXWUiqVV06Tf35q8dYVJJBJem2A7Kwi2nQzD\nZig1CG93+PO5/KN6tf5NKpVqbsBUVVVFUUxwHJc1TXNBoxojS7IbhrnLMMx9pVJlBqFQKBKPxwcB\nkJYgjKIo3QCE1nSKoghbfJuKRqN2RVXexMaQzWaLezyeEUEQDjscjk78PxFFUYRkMsltJgGA3t7e\nyMLCwie6rr8iCILVbDbvMgwzYRjGxe0o4XC4s1AoHPP5fMP5/NNOyzLKAO6Ew+HrDADBbre/Ryk9\nnzx81FXJNlEpVpF+OqtpWu2MpmnXWmH9/f2umZmZi4cOHXnLbILLzOchhz1YerJAs9m1GwRAg2GY\nh7GYah488BJYzYW+2BD61AFBlmX/1nSNRqN9//792ujoaIPVRMjOKHoie3DytVGmp2fXCAEAjuMm\nu7u7Umosho6gjL/u/QHeEgvJZHJ2K/D+/fuL4+PjXyvPd5ldkShy1UXcmb4DnjgQj/fd5gDA6/XS\nYCAwTwh9oT3QzrS1+VDVi+vd3Tsy26yQVoFF3dAXJVmK96p9EJ0iLNOwKKU3CQCk0+lSOpP5WLDz\nF9Q9kZqyO0SloOs6gMfbHSU5NLRiUOuax2/HyZPHEOsLw2SbP83eu/fLxrkNp9P554XxCzVa16MC\n7+BPnTk9cfmH74KJE8nmga7Xy5JkZ8VKifGIHpoBb1VX8hNTd3/t/7lQ3OeXfFPvf/jBRw8ezD/a\n7M/aWq91cGgnJaZ2VcgSdnV1XRNNd3vAoBVVYusmnEQS65hfgSG6c+zy3Kre7nF/KrukcMW0Zg8O\nD08DoJutDxxOEb5IPUymwrq8ft1gLKfkFojkkRxemERCAQUACPFWRazYLJcrFGwQhyufbQQ7rFpy\nLMkCwGZC34qPIuwp+XPOjBFwazQ/txrdFS2GGS/Xuj+pUKLGk1Kjvlded3s72lyGW+PLbGVcmrAA\ngN0wTk1NWYODg9XOKltGtpazi5GigzroUnHN5nUHG1ylRsG7rDXHmnEpu4CeEtEKkqNc6QqlLc/M\n8uT5lLH5eq0aGxsju1O7GQB498a5s/0x9dRALPaQEDZnYwnhWJtMCCNrjeb0UP34Z6e/PW22zjPP\n+vwXBwfPvbw38XnXjk7GsiwKAIQQhjAMMrlsam45d+zLH6/8o6vkWcBcrXbVKQhf6bpucCwLjmUB\nSmmhXC419eblrbD/TAgAkUjE987xE0c7ZDmk66ajUCnq+cL63fErl25s5/8baQPaWLhx6goAAAAA\nSUVORK5CYII=",
        parameters => [
            { type => "bool", desc => "Add the following tags if available: download URL, gallery ID, category, timestamp" },
            {   type => "bool",
                desc =>
                  "Add tags without a namespace to the 'other:' namespace instead, mirroring E-H's behavior of namespacing everything"
            },
            {   type => "string",
                desc => "Add a custom 'source:' tag to your archive. Example: chaika. Will NOT add a tag if blank"
            }
        ],
    );
}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;                            # Global info hash
    my ( $addextra, $addother, $addsource ) = @_;    # Plugin parameters

    my $logger   = get_plugin_logger();
    my $newtags  = "";
    my $newtitle = "";

    # Try reading any embedded api.json file
    my $path_in_archive = is_file_in_archive( $lrr_info->{file_path}, "api.json" );
    if ($path_in_archive) {

        #Extract api.json
        my $filepath = extract_file_from_archive( $lrr_info->{file_path}, $path_in_archive );
        ( $newtags, $newtitle ) = tags_from_file( $filepath, $addextra, $addother, $addsource );
    }

    if ( $newtags eq "" ) {
        my $message = "No Chaika File Found!";
        $logger->info($message);
        die "${message}\n";
    } else {

        $logger->info("Sending the following tags to LRR: $newtags");

        #Return a hash containing the new metadata
        return ( tags => $newtags, title => $newtitle );
    }

}

######
## Chaika Specific Methods
######

# tags_from_file
sub tags_from_file {

    my ( $filepath, $addextra, $addother, $addsource ) = @_;

    my $logger = get_plugin_logger();

    #Open it
    my $stringjson = "";

    open( my $fh, '<:encoding(UTF-8)', $filepath )
      or die "Could not open $filepath!\n";

    while ( my $row = <$fh> ) {
        chomp $row;
        $stringjson .= $row;
    }
    unlink($fh);

    #Use Mojo::JSON to decode the string into a hash
    my $hashjson = from_json($stringjson);

    return parse_chaika_json( $hashjson, $addextra, $addother, $addsource );
}

# Parses the JSON obtained from the Chaika API to get the tags.
# Same as in Chaika.pm, but I'm too stupid to import across plugin (if possible)
# Just copy the method from there if it's updated.
sub parse_chaika_json {

    my ( $json, $addextra, $addother, $addsource ) = @_;

    my $tags = $json->{"tags"} || ();
    foreach my $tag (@$tags) {

        #Replace underscores with spaces
        $tag =~ s/_/ /g;

        #Add 'other' namespace if none
        if ( $addother && index( $tag, ":" ) == -1 ) {
            $tag = "other:" . $tag;
        }
    }

    my $category  = lc $json->{"category"};
    my $download  = $json->{"download"} ? $json->{"download"} : $json->{"archives"}->[0]->{"link"};
    my $gallery   = $json->{"gallery"}  ? $json->{"gallery"}  : $json->{"id"};
    my $timestamp = $json->{"posted"};
    if ( $tags && $addextra ) {
        if ( $category ne "" ) {
            push( @$tags, "category:" . $category );
        }
        if ( $download ne "" ) {
            push( @$tags, "download:" . $download );
        }
        if ( $gallery ne "" ) {
            push( @$tags, "gallery:" . $gallery );
        }
        if ( $timestamp ne "" ) {
            push( @$tags, "timestamp:" . $timestamp );
        }
    }

    if ( $gallery && $gallery ne "" ) {

        # add custom source, but only if having found gallery
        if ( $addsource && $addsource ne "" ) {
            push( @$tags, "source:" . $addsource );
        }
        return ( join( ', ', @$tags ), $json->{"title"} );
    } else {
        return "";
    }
}

1;
