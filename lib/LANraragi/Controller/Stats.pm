package LANraragi::Controller::Stats;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use File::Find::utf8;

use LANraragi::Model::Utils;
use LANraragi::Model::Config;

# This action will render a template
sub index {
    my $self = shift;

    my $t;
    my @tags;
    my %tagcloud;

    #Login to Redis and get all hashes
    my $redis = $self->LRR_CONF->get_redis();

    #40-character long keys only => Archive IDs
    my @keys         = $redis->keys('????????????????????????????????????????');
    my $archivecount = scalar @keys;

    #Iterate on hashes to get their tags
    foreach my $id (@keys) {

        if ( $redis->hexists( $id, "tags" ) ) {

            $t = $redis->hget( $id, "tags" );
            $t = LANraragi::Model::Utils::redis_decode($t);

            #Split tags by comma
            @tags = split( /,\s?/, $t );

            foreach my $t (@tags) {

                LANraragi::Model::Utils::remove_spaces  ($t);
                LANraragi::Model::Utils::remove_newlines($t);

                unless (
                    $t =~ /(artist|parody|language|event|group|circle):.*/i )
                {    #Filter some specific namespaces from appearing in stats

                    #Strip namespaces if necessary - detect the : symbol and only use what's after it
                    if ( $t =~ /.*:(.*)/ ) { $t = $1 }

                    #Increment value of tag if it's already in the result hash, create it otherwise
                    if   ( exists( $tagcloud{$t} ) ) { $tagcloud{$t}++; }
                    else                             { $tagcloud{$t} = 1; }
                }
            }

        }
    }

    #When we're done going through tags, go through the tagCloud hash and build a JSON
    my $tagsjson = "[";

    @tags = keys %tagcloud;
    my $tagcount = scalar @tags;

    for my $t (@tags) {
        my $w = $tagcloud{$t};
        $tagsjson .= qq({text: "$t", weight: $w },);
    }

    $tagsjson .= "]";

    #Get size of archive folder
    my $dirname = $self->LRR_CONF->get_userdir;
    my $size    = 0;

    find( sub { $size += -s if -f }, $dirname );

    $size = int( $size / 1073741824 * 100 ) / 100;

    $self->render(
        template     => "stats",
        title        => $self->LRR_CONF->get_htmltitle,
        cssdrop      => LANraragi::Model::Utils::generate_themes,
        tagcloud     => $tagsjson,
        tagcount     => $tagcount,
        archivecount => $archivecount,
        arcsize      => $size
    );
}

1;
