package LANraragi::Plugin::Scripts::SourceFinder;

use strict;
use warnings;
no warnings 'uninitialized';

use Mojo::UserAgent;
use LANraragi::Utils::Logging qw(get_logger);
use LANraragi::Utils::Database qw(redis_decode);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "Source Finder",
        type        => "script",
        namespace   => "urlfinder",
        author      => "Difegue",
        version     => "1.0",
        description => "Looks in the database if an archive has a 'source:' tag matching the given URL.",
        #icon        => "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAIAAAAC64paAAAACXBIWXMAAAsTAAALEwEAmpwYAAAA\nB3RJTUUH4wYCFA8s1yKFJwAAAB1pVFh0Q29tbWVudAAAAAAAQ3JlYXRlZCB3aXRoIEdJTVBkLmUH\nAAACL0lEQVQ4y6XTz0tUURQH8O+59773nLFcaGWTk4UUVCBFiJs27VxEQRH0AyRo4x8Q/Qtt2rhr\nU6soaCG0KYKSwIhMa9Ah+yEhZM/5oZMG88N59717T4sxM8eZCM/ycD6Xwznn0pWhG34mh/+PA8mk\n8jO5heziP0sFYwfgMDFQJg4IUjmquSFGG+OIlb1G9li5kykgTgvzSoUCaIYlo8/Igcjpj5wOkARp\n8AupP0uzJLijCY4zzoXOxdBLshAgABr8VOp7bpAXDEI7IBrhdksnjNr3WzI4LaIRV9fk2iAaYV/y\nA1dPiYjBAALgpQxnhV2XzTCAGWGeq7ACBvCdzKQyTH+voAm2hGlpcmQt2Bc2K+ymAhWPxTzPDQLt\nOKo1FiNBQaArq9WNRQwEgKl7XQ1duzSRSn/88vX0qf7DPQddx1nI5UfHxt+m0sLYPiP3shRAG8MD\nok1XEEXR/EI2ly94nrNYWG6Nx0/2Hp2b94dv34mlZge1e4hVCJ4jc6tl9ZP803n3/i4lpdyzq2N0\n7M3DkSeF5ZVYS8v1qxcGz5+5eey4nPDbmGdE9FpGeWErVNe2tTabX3r0+Nk3PwOgXFkdfz99+exA\nMtFZITEt9F23mpLG0hYTVQCKpfKPlZ/rqWKpYoAPcTmpginW76QBbb0OBaBaDdjaDbNlJmQE3/d0\nMYoaybU9126oPkrEhpr+U2wjtoVVGBowkslEsVSupRKdu0Mduq7q7kqExjSS3V2dvwDLavx0eczM\neAAAAABJRU5ErkJggg==",
        oneshot_arg => "URL to search."
    );

}

# Mandatory function to be implemented by your script
sub run_script {
    shift;
    my $lrr_info = shift; # Global info hash 

    my $logger = get_logger( "Source Finder", "plugins" );

    # Only info we need is the URL to search
    my $url = $lrr_info->{oneshot_param};

    # Go through the database and search for source: tags
    my $redis = LANraragi::Model::Config->get_redis;

    my @keys  = $redis->keys('????????????????????????????????????????');
    my @list  = ();

    foreach my $id (@keys) {
        my $arcfile = $redis->hget( $id, "file" );
        if ( -e $arcfile ) {

            my $tags = $redis->hget($id, "tags");
            $tags = redis_decode($tagstr);

            if ( $tags =~ /source:/ ) {
                $tags =~ /.*source:([^,]*),.*/;

                if ($1 eq $url) { 
                    return ( output => $id);  
                }
            }
        }
    }

    return ( error => "URL not found in database.", output => 0 );  
}

}

1;