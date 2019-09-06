package LANraragi::Model::Stats;

use strict;
use warnings;
use utf8;

use Redis;
use File::Find;

use LANraragi::Utils::Generic;
use LANraragi::Utils::Archive;
use LANraragi::Utils::Database;

use LANraragi::Model::Config;

sub get_archive_count {

    #We can't trust the DB to contain the exact amount of files,
    #As deleted files are still kept in store.
    my $dirname = LANraragi::Model::Config::get_userdir;
    my $count   = 0;

    #Count files the old-fashioned way instead
    find(
        {
            wanted => sub {
                return if -d $_;    #Directories are excluded on the spot
                if ( $_ =~ /^.+\.(?:zip|rar|7z|tar|tar\.gz|lzma|xz|cbz|cbr)$/ ) {
                    $count++;
                }
            },
            no_chdir    => 1,
            follow_fast => 1
        },
        $dirname
    );
    return $count;
}

sub build_tag_json {

    my $t;
    my @tags;
    my %tagcloud;

    #Login to Redis and get all hashes
    my $redis = LANraragi::Model::Config::get_redis();
    my $logger = LANraragi::Utils::Generic::get_logger( "Tag Stats", "lanraragi" );

    #40-character long keys only => Archive IDs
    my @keys = $redis->keys('????????????????????????????????????????');

    #Iterate on hashes to get their tags
    foreach my $id (@keys) {
        if ( $redis->hexists( $id, "tags" ) ) {

            $t = $redis->hget( $id, "tags" );
            $t = LANraragi::Utils::Database::redis_decode($t);

            #Split tags by comma
            @tags = split( /,\s?/, $t );

            foreach my $t (@tags) {

                LANraragi::Utils::Generic::remove_spaces($t);
                LANraragi::Utils::Generic::remove_newlines($t);

                #Increment value of tag or create it
                if ( exists( $tagcloud{$t} ) ) 
                    { $tagcloud{$t}++; }
                else                             
                    { $tagcloud{$t} = 1; }
            }

        }
    }

    #Go through the tagCloud hash and build a JSON
    my $tagsjson = "[";

    for(keys %tagcloud) {
        my $w = $tagcloud{$_};
        # Split namespace
        # detect the : symbol and only use what's after it
        my $ns = "";
        my $t = $_;
        if ( $t =~ /(.*):(.*)/ ) { $ns = $1; $t = $2; }

        if ($_ ne "") { $tagsjson .= qq({"text": "$t", "namespace": "$ns", "weight": $w },); }
    }

    chop $tagsjson if $tagsjson ne "[";
    $tagsjson .= "]";
    $logger->debug("Tag stats JSON is $tagsjson");
    return $tagsjson;
}

sub compute_content_size {
    #Get size of archive folder
    my $dirname = LANraragi::Model::Config::get_userdir;
    my $size    = 0;

    find( sub { $size += -s if -f }, $dirname );

    return int( $size / 1073741824 * 100 ) / 100;
}

1;