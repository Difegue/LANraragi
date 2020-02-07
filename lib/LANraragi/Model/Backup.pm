package LANraragi::Model::Backup;

use strict;
use warnings;
use utf8;

use Redis;
use Encode;
use Mojo::JSON qw(decode_json encode_json);

use LANraragi::Utils::Generic qw(remove_newlines);
use LANraragi::Utils::Archive;
use LANraragi::Utils::Database qw(redis_decode invalidate_cache);
use LANraragi::Utils::Logging qw(get_logger);

#build_backup_JSON()
#Goes through the Redis archive IDs and builds a JSON string containing their metadata.
sub build_backup_JSON {
    my $redis = LANraragi::Model::Config->get_redis;
    my $json  = "[ ";

    #Fill the list with archives by looking up in redis
    my @keys = $redis->keys('????????????????????????????????????????');

    #40-character long keys only => Archive IDs

    #Parse the archive list and add them to JSON.
    foreach my $id (@keys) {

        my %hash = $redis->hgetall($id);

        my ( $name, $title, $tags, $thumbhash ) =
          @hash{qw(name title tags thumbhash)};

        ( $_ = redis_decode($_) ) for ( $name, $title, $tags );
        ( remove_newlines($_) )   for ( $name, $title, $tags );
        ( $_ = encode_json($_))   for ( $name, $title, $tags );

        #Backup all user-generated metadata, alongside the unique ID.
        $json .= qq(
                {
                    "arcid": "$id",
                    "title": $title,
                    "tags": $tags,
                    "thumbhash": "$thumbhash",
                    "filename": $name
                },);
    }

    #remove last comma for json compliance
    chop($json);

    $json .= "]";

    $redis->quit();
    return $json;

}

#restore_from_JSON(backupJSON)
#Restores metadata from a JSON to the Redis archive, for existing IDs.
sub restore_from_JSON {
    my $redis = LANraragi::Model::Config->get_redis;

    my $logger = get_logger( "Backup/Restore", "lanraragi" );

    my $json = decode_json( $_[0] );

    foreach my $archive (@$json) {
        my $id = $archive->{"arcid"};

        #If the archive exists, restore metadata.
        if ( $redis->exists($id) ) {

            $logger->info("Restoring metadata for Archive $id...");
            my $title     = encode_utf8( $archive->{"title"} );
            my $tags      = encode_utf8( $archive->{"tags"} );
            my $thumbhash = encode_utf8( $archive->{"thumbhash"} );

            $redis->hset( $id, "title", $title );
            $redis->hset( $id, "tags",  $tags );

            if (   $redis->hexists( $id, "thumbhash" )
                && $redis->hget( $id, "thumbhash" ) eq "" )
            {
                $redis->hset( $id, "thumbhash", $thumbhash );
            }

        }
    }

    #Force a refresh
    invalidate_cache();
    $redis->quit();

}

1;
