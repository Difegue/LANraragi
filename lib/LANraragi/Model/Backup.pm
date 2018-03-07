package LANraragi::Model::Backup;

use strict;
use warnings;
use utf8;

use Redis;
use Encode;
use Mojo::JSON qw(decode_json encode_json);

use LANraragi::Model::Utils;
use LANraragi::Model::Config;

#build_backup_JSON()
#Goes through the Redis archive IDs and builds a JSON string containing their metadata.
sub build_backup_JSON {
    my $redis = LANraragi::Model::Config::get_redis;
    my $json  = "[ ";

    #Fill the list with archives by looking up in redis
    my @keys = $redis->keys('????????????????????????????????????????');
    #40-character long keys only => Archive IDs

    #Parse the archive list and add them to JSON.
    foreach my $id (@keys) {

        my %hash = $redis->hgetall($id);

        my ( $name, $title, $tags, $file, $thumbhash ) =
          @hash{qw(name title tags file thumbhash)};

        ( $_ = LANraragi::Model::Utils::redis_decode($_) )
          for ( $name, $title, $tags, $file );

        #Backup all user-generated metadata, alongside the unique ID and the filesystem path.
        #Filesystem path is normally unused but can serve as a fallback if the ID can't be used.
        $json .= qq(
                {
                    "arcid": "$id",
                    "title": "$title",
                    "tags": "$tags",
                    "filename": "$name"
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
    my $redis = LANraragi::Model::Config::get_redis;

    my $json = decode_json( $_[0] );

    foreach my $archive (@$json) {
        my $id = $archive->{"arcid"};

        #If the archive exists, restore metadata.
        if ( $redis->hexists( $id, "title" ) ) {

            #prepare the hash which'll be inserted.
            my %hash = (
                title    => encode_utf8( $archive->{"title"} ),
                tags     => encode_utf8( $archive->{"tags"} ),
            );

            #for all keys of the hash, 
            #add them to the redis hash $id with the matching keys.
            $redis->hset( $id, $_, $hash{$_}, sub { } ) for keys %hash;
            $redis->wait_all_responses;

        }
    }

    $redis->quit();

}

1;
