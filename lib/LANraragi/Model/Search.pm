package LANraragi::Model::Search;

use strict;
use warnings;
use utf8;

use List::Util qw(min);
use Redis;

use LANraragi::Utils::Generic;
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
    foreach my $id (@keys) {
        my $tags  = $redis->hget($id, "tags");
        my $title = $redis->hget($id, "title");
        my $file  = $redis->hget($id, "file");
        $title = LANraragi::Utils::Database::redis_decode($title);
        $tags  = LANraragi::Utils::Database::redis_decode($tags);

        if (-e $file && matches_search_filter($filter, $title . " " . $tags)) {
            # Push id to array
            push @filtered, { id => $id, title => $title, tags => $tags };
        }
    }

    if ($#filtered > 0) {

        if (!$sortkey) {
            $sortkey = "title";
        }

        # Sort by the required metadata, asc or desc
        @filtered = sort { 
  
            #Use either tags or title depending on the sortkey
            my $meta1 = $a->{title};
            my $meta2 = $b->{title};

            if ($sortkey ne "title") {
                my $re = qr/$sortkey/;
                if ($a->{tags} =~ m/.*${re}:(.*)(\,.*|$)/) {
                    $meta1 = $1;
                } else {
                    $meta1 = "zzzz"; # Not a very good way to make items end at the bottom...
                }
                    
                if ($b->{tags} =~ m/.*${re}:(.*)(\,.*|$)/)  {
                    $meta2 = $1;
                } else {
                    $meta2 = "zzzz";
                }
            }

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
    my $end = min($start+$keysperpage-1,$#filtered);
    return ( $#keys+1, $#filtered+1, @filtered[$start..$end] );
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



1;