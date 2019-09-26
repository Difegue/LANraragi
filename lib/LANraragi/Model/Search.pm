package LANraragi::Model::Search;

use strict;
use warnings;
use utf8;

use List::Util qw(min);
use Redis;
use Encode;
use Mojo::JSON qw(decode_json encode_json);

use LANraragi::Utils::Generic;
use LANraragi::Utils::Archive;
use LANraragi::Utils::Database;

use LANraragi::Model::Config;

# do_search (filter, page, key, order)
# Performs a search on the database.
sub do_search {

    my ( $filter, $start, $sortkey, $sortorder) = @_;

    my $redis = LANraragi::Model::Config::get_redis;
    my $logger =
        LANraragi::Utils::Generic::get_logger( "Search Engine", "lanraragi" );

    # Get all archives from redis
    my @keys = $redis->keys('????????????????????????????????????????');
    my @filtered;

    # Go through tags and apply search filter
    # TODO: subprocess this by chunks for s p e e d
    foreach my $id (@keys) {
        my $tags  = $redis->hget($id, "tags");
        my $title = $redis->hget($id, "title");
        $metadata = LANraragi::Utils::Database::redis_decode($title . " " . $tags);

        if (matches_search_filter($filter, $metadata)) {
            # Push id to array
            push @filtered, $id;          
        }
    }

    if ($#filtered > 0) {

        if (!$sortkey) {
            $sortkey = "title";
        }

        # Sort by the required metadata, asc or desc
        @filtered = sort { 
  
            #TODO: add namespace finding capabilities here instead of just using redis columns
            my $meta1 = $redis->hget($a, $sortkey);
            $meta1 = LANraragi::Utils::Database::redis_decode($meta1);
            my $meta2 = $redis->hget($b, $sortkey);
            $meta2 = LANraragi::Utils::Database::redis_decode($meta2);

            if ($sortorder) { 
                lc($meta2) cmp lc($meta1)
            } else {
                lc($meta1) cmp lc($meta2)
            }

        } @filtered;
    }

    # Only get the first X keys
    # TODO: cache @filtered
    my $keysperpage = LANraragi::Model::Config::get_pagesize;

    # Return total keys and the filtered ones
    my $end = min($keysperpage,$#filtered);
    return ( $#keys, @filtered[$start..$end] );
}

# matches_search_filter($filter, $tags)
# Search engine core.
sub matches_search_filter {

    my ( $filter, $tags ) = @_;
    if (!$filter) {$filter = "";}

    # Special characters: 
    # "" for exact search (or $ but is that one really useful)
    # ?/_ for any character
    # * % for multiple characters
    # - to exclude the next tag

    $b = reverse($filter); 
    while ($b ne "") {

        my $char = chop $b;
        my $isneg = 0;

        if ($char eq "-") {
            $isneg = 1;
            $char = chop $b;
        }

        # Get characters until the next space, or the next " if the following char is "
        my $delimiter = ' ';
        if ($char eq '"') {
            $delimiter = '"';
        }

        my $tag = "";
        my $isexact = 0;
        TAGBUILD: while (1) {
            if ($char eq $delimiter || $char eq "") { last TAGBUILD; }
            $tag = $tag . $char; # Add characters in reverse order since we used reverse earlier on 
            $char = chop $b;
        }; 

        #If last char is $, enable isexact
        $char = chop $tag;
        if ($char eq "\$") {
            $isexact = 1;
        } else {
            $tag = $tag . $char;
        }

        # Replace placeholders with regex-friendly variants,
        # And escape already present regex characters
        # ? _ => .
        $tag =~ s/\?|\_/\./g;
        # * % => .*
        $tag =~ s/\*|\%/\.\*/g;
        # + ( ) ^ | \ => escaped with an extra \
        $tag =~ s/(\+|\(|\)|\^|\||\\)/\\$1/g;

        # Got the tag, check if it's present
        my $tagpresent = 0;
        if ($isexact) { # The tag must necessarily be complete if isexact = 1
            $tagpresent = $tags =~ m/(.* |^)$tag(\,.*|$)/i; # Check for space before and comma after the tag, or start/end of string to account for the first/last tag.
        } else {
            $tagpresent = $tags =~ m/.*$tag.*/i;
        }

        #present true & isneg true => false, present false & isneg false => false
        return 0 if ($tagpresent == $isneg); 

    };

    # All filters passed!
    return 1;
}

# build_archive_JSON(id)
# Builds a JSON object for an archive already registered in the Redis database and returns it.
# TODO: adapted from Shinobu code, remember to purge a bunch of code in Shinobu once this is merged
sub build_archive_JSON {
    my ( $id ) = @_;

    my $redis   = LANraragi::Model::Config::get_redis;
    my $dirname = LANraragi::Model::Config::get_userdir;

    #Extra check in case we've been given a bogus ID
    return "" unless $redis->exists($id);

    my %hash = $redis->hgetall($id);
    my ( $path, $suffix );

    #It's not a new archive, but it might have never been clicked on yet,
    #so we'll grab the value for $isnew stored in redis.
    my ( $name, $title, $tags, $filecheck, $isnew ) =
      @hash{qw(name title tags file isnew)};

    #Parameters have been obtained, let's decode them.
    ( $_ = LANraragi::Utils::Database::redis_decode($_) )
      for ( $name, $title, $tags );

    #Workaround if title was incorrectly parsed as blank
    if ( !defined($title) || $title =~ /^\s*$/ ) {
        $title = $name;
    }

    my $arcdata = {
        arcid => $id,
        title => $title,
        tags  => $tags,
        isnew => $isnew
    };

    $redis->quit;
    return $arcdata;
}

1;