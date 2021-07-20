package LANraragi::Plugin::Metadata::Chaika;

use strict;
use warnings;

use URI::Escape;
use Mojo::UserAgent;
use Mojo::DOM;
use LANraragi::Utils::Logging qw(get_logger);

my $chaika_url = "https://panda.chaika.moe";

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "Chaika.moe",
        type        => "metadata",
        namespace   => "trabant",
        author      => "Difegue",
        version     => "2.1.1",
        description => "Searches chaika.moe for tags matching your archive.",
        icon =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAACXBIWXMAAAsTAAALEwEAmpwYAAAA\nB3RJTUUH4wYCFQocjU4r+QAAAB1pVFh0Q29tbWVudAAAAAAAQ3JlYXRlZCB3aXRoIEdJTVBkLmUH\nAAAEZElEQVQ4y42T3WtTdxzGn/M7J+fk5SRpTk7TxMZkXU84tTbVNrUT3YxO7HA4pdtQZDe7cgx2\ns8vBRvEPsOwFYTDYGJUpbDI2wV04cGXCGFLonIu1L2ptmtrmxeb1JDkvv121ZKVze66f74eH7/f5\nMmjRwMCAwrt4/9KDpflMJpPHvyiR2DPcJklJ3TRDDa0xk36cvrm8vDwHAAwAqKrqjjwXecPG205w\nHBuqa9rk77/d/qJYLD7cCht5deQIIczbgiAEKLVAKXWUiqVV06Tf35q8dYVJJBJem2A7Kwi2nQzD\nZig1CG93+PO5/KN6tf5NKpVqbsBUVVVFUUxwHJc1TXNBoxojS7IbhrnLMMx9pVJlBqFQKBKPxwcB\nkJYgjKIo3QCE1nSKoghbfJuKRqN2RVXexMaQzWaLezyeEUEQDjscjk78PxFFUYRkMsltJgGA3t7e\nyMLCwie6rr8iCILVbDbvMgwzYRjGxe0o4XC4s1AoHPP5fMP5/NNOyzLKAO6Ew+HrDADBbre/Ryk9\nnzx81FXJNlEpVpF+OqtpWu2MpmnXWmH9/f2umZmZi4cOHXnLbILLzOchhz1YerJAs9m1GwRAg2GY\nh7GYah488BJYzYW+2BD61AFBlmX/1nSNRqN9//792ujoaIPVRMjOKHoie3DytVGmp2fXCAEAjuMm\nu7u7Umosho6gjL/u/QHeEgvJZHJ2K/D+/fuL4+PjXyvPd5ldkShy1UXcmb4DnjgQj/fd5gDA6/XS\nYCAwTwh9oT3QzrS1+VDVi+vd3Tsy26yQVoFF3dAXJVmK96p9EJ0iLNOwKKU3CQCk0+lSOpP5WLDz\nF9Q9kZqyO0SloOs6gMfbHSU5NLRiUOuax2/HyZPHEOsLw2SbP83eu/fLxrkNp9P554XxCzVa16MC\n7+BPnTk9cfmH74KJE8nmga7Xy5JkZ8VKifGIHpoBb1VX8hNTd3/t/7lQ3OeXfFPvf/jBRw8ezD/a\n7M/aWq91cGgnJaZ2VcgSdnV1XRNNd3vAoBVVYusmnEQS65hfgSG6c+zy3Kre7nF/KrukcMW0Zg8O\nD08DoJutDxxOEb5IPUymwrq8ft1gLKfkFojkkRxemERCAQUACPFWRazYLJcrFGwQhyufbQQ7rFpy\nLMkCwGZC34qPIuwp+XPOjBFwazQ/txrdFS2GGS/Xuj+pUKLGk1Kjvlded3s72lyGW+PLbGVcmrAA\ngN0wTk1NWYODg9XOKltGtpazi5GigzroUnHN5nUHG1ylRsG7rDXHmnEpu4CeEtEKkqNc6QqlLc/M\n8uT5lLH5eq0aGxsju1O7GQB498a5s/0x9dRALPaQEDZnYwnhWJtMCCNrjeb0UP34Z6e/PW22zjPP\n+vwXBwfPvbw38XnXjk7GsiwKAIQQhjAMMrlsam45d+zLH6/8o6vkWcBcrXbVKQhf6bpucCwLjmUB\nSmmhXC419eblrbD/TAgAkUjE987xE0c7ZDmk66ajUCnq+cL63fErl25s5/8baQPaWLhx6goAAAAA\nSUVORK5CYII=",
        parameters  => [ { type => "bool", desc => "Save archive title" } ],
        oneshot_arg => "Chaika Gallery or Archive URL (Will attach matching tags to your archive)"
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;    # Global info hash
    my ($savetitle) = @_;    # Plugin parameters

    my $logger   = get_logger( "Chaika", "plugins" );
    my $newtags  = "";
    my $newtitle = "";

    # Parse the given link to see if we can extract type and ID
    my $oneshotarg = $lrr_info->{oneshot_param};
    if ( $oneshotarg =~ /https?:\/\/panda\.chaika\.moe\/(gallery|archive)\/([0-9]*)\/?.*/ ) {
        ( $newtags, $newtitle ) = tags_from_chaika_id( $1, $2 );
    } else {

        # Try SHA-1 reverse search first
        ( $newtags, $newtitle ) = tags_from_sha1( $lrr_info->{thumbnail_hash} );

        # Try search if it fails
        if ( $newtags eq "" ) {
            ( $newtags, $newtitle ) = search_for_archive( $lrr_info->{archive_title}, $lrr_info->{existing_tags} );
        }
    }

    if ( $newtags eq "" ) {
        $logger->info("No matching Chaika Archive Found!");
        return ( error => "No matching Chaika Archive Found!" );
    } else {

        $logger->info("Sending the following tags to LRR: $newtags");
        #Return a hash containing the new metadata
        if ( $savetitle && $newtags ne "" ) { return ( tags => $newtags, title => $newtitle ); }
        else                                { return ( tags => $newtags ); }
    }

}

sub get_local_logger {
    my %pi = plugin_info();
    return get_logger( $pi{name}, "plugins" );
}

######
## Chaika Specific Methods
######

# search_for_archive
# Uses chaika's html search to find a matching archive ID
sub search_for_archive {

    my $logger = get_local_logger();
    my $title  = $_[0];
    my $tags   = $_[1];

    #Auto-lowercase the title for better results
    $title = lc($title);

    #Strip away hyphens and apostrophes as they apparently break search
    $title =~ s/-|'/ /g;

    my $URL = "$chaika_url/jsearch/?gsp&title=" . uri_escape_utf8($title) . "&tags=";

    #Append language:english tag, if it exists.
    #Chaika only has english or japanese so I aint gonna bother more than this
    if ( $tags =~ /.*language:\s?english,*.*/gi ) {
        $URL = $URL . uri_escape_utf8("language:english") . "+";
    }

    $logger->debug("Calling $URL");
    my $ua  = Mojo::UserAgent->new;
    my $res = $ua->get($URL)->result;

    my $textrep = $res->body;
    $logger->debug("Chaika API returned this JSON: $textrep");

    my ( $chaitags, $chaititle ) = parse_chaika_json( $res->json->{"galleries"}->[0] );

    return ( $chaitags, $chaititle );
}

# Uses the jsearch API to get the best json for a file.
sub tags_from_chaika_id {

    my ( $type, $ID ) = @_;

    my $json = get_json_from_chaika( $type, $ID );
    return parse_chaika_json( $json );
}

# tags_from_sha1
# Uses chaika's SHA-1 search with the first page hash we have.
sub tags_from_sha1 {

    my ( $sha1 ) = @_;

    my $logger = get_local_logger();

    # The jsearch API immediately returns a JSON.
    # Said JSON is an array containing multiple archive objects.
    # We just take the first one.
    my $json_by_sha1 = get_json_from_chaika( 'sha1', $sha1 );
    my $chaika_id = $json_by_sha1->[0]->{"id"};
    $logger->debug("Gallery ID detected($chaika_id), trying to switch to it.");

    # Switch to gallery tags if there are any.
    # Occasionally archives won't have a matching gallery despite the ID being there. (huh)
    my $json = get_json_from_chaika( 'gallery' , $chaika_id);

    if ( !$json->{"tags"} ) {
        $logger->debug("Gallery doesn't actually have tags! Switching back to Archive.");
        $json = $json_by_sha1->[0];
    }

    return parse_chaika_json( $json );
}

# Calls chaika's API
sub get_json_from_chaika {

    my ( $type, $value ) = @_;

    my $logger = get_local_logger();
    my $URL    = "$chaika_url/jsearch/?$type=$value";
    my $ua     = Mojo::UserAgent->new;
    my $res    = $ua->get($URL)->result;

    if ($res->is_error) {
        return;
    }
    my $textrep = $res->body;
    $logger->debug("Chaika API returned this JSON: $textrep");

    return $res->json;
}

# Parses the JSON obtained from the Chaika API to get the tags.
sub parse_chaika_json {

    my ( $json ) = @_;

    my $tags = $json->{"tags"} || ();
    foreach my $tag (@$tags) {
        #Replace underscores with spaces
        $tag =~ s/_/ /g;
    }

    return ( join( ', ', @$tags ), $json->{"title"} );
}

1;
