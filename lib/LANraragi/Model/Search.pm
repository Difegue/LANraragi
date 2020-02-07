package LANraragi::Model::Search;

use strict;
use warnings;
use utf8;

use List::Util qw(min);
use Redis;
use Encode;
use Storable qw/ nfreeze thaw /;
use Sort::Naturally;

use LANraragi::Utils::Generic;
use LANraragi::Utils::Database;
use LANraragi::Utils::Logging qw(get_logger);

use LANraragi::Model::Config;
use LANraragi::Model::Api;

# do_search (filter, filter2, page, key, order, newonly, untaggedonly)
# Performs a search on the database.
sub do_search {

    my ( $filter, $columnfilter, $start, $sortkey, $sortorder, $newonly, $untaggedonly) = @_;

    my $redis = LANraragi::Model::Config::get_redis;
    my $logger = get_logger( "Search Engine", "lanraragi" );

    # Search filter results
    my @filtered;
    # Get all archives from redis
    my @keys = $redis->keys('????????????????????????????????????????');

    # Look in searchcache first
    my $cachekey = encode_utf8("$columnfilter-$filter-$sortkey-$sortorder-$newonly-$untaggedonly");
    $logger->debug("Search request: $cachekey");

    if ($redis->exists("LRR_SEARCHCACHE") && $redis->hexists("LRR_SEARCHCACHE", $cachekey)) {

        $logger->debug("Using cache for this query.");
        @filtered = @{ thaw $redis->hget("LRR_SEARCHCACHE", $cachekey)};
    } else {
        $logger->debug("No cache available, doing a full DB parse.");

        # If the untagged filter is enabled, call the untagged files API 
        my %untagged = ();
        if ($untaggedonly) {
            %untagged = map { $_ => 1 } LANraragi::Model::Api::find_untagged_archives();
        }

        # Go through tags and apply search filter
        foreach my $id (@keys) {
            my $tags  = $redis->hget($id, "tags");
            my $title = $redis->hget($id, "title");
            my $file  = $redis->hget($id, "file");
            my $isnew = $redis->hget($id, "isnew");
            $title = LANraragi::Utils::Database::redis_decode($title);
            $tags  = LANraragi::Utils::Database::redis_decode($tags);

            # Check new filter first
            if ($newonly && $isnew && $isnew ne "true" && $isnew ne "block") {
                next;
            }

            # Check untagged filter second
            unless (exists($untagged{$id}) || !$untaggedonly) {
                next;
            }

            # Check columnfilter and base search filter
            if ($file && -e $file 
                && matches_search_filter($columnfilter, $title . "," . $tags)
                && matches_search_filter($filter, $title . "," . $tags)) {
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
                    ncmp( lc($meta2), lc($meta1) )
                } else {
                    ncmp( lc($meta1), lc($meta2) )
                }

            } @filtered;
        }

        # Cache this query in Redis
        eval { $redis->hset("LRR_SEARCHCACHE", $cachekey, nfreeze \@filtered); };
    }
    $redis->quit();

    # Only get the first X keys
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
            $char = chop $b;
        }

        my $tag = "";
        my $isexact = 0;
        TAGBUILD: while (1) {
            if ($char eq $delimiter || $char eq "") { last TAGBUILD; }
            $tag = $tag . $char; # Add characters in reverse order since we used reverse earlier on 
            $char = chop $b;
        }; 

        #If last char is $, enable isexact
        if ($delimiter eq '"') {
            $char = chop $b;
            if ($char eq "\$") {
                $isexact = 1;
            } else {
                $b = $b . $char;
            }
        } else {
            $char = chop $tag;
            if ($char eq "\$") {
                $isexact = 1;
            } else {
                $tag = $tag . $char;
            }
        }

        # Escape already present regex characters
        $tag = quotemeta($tag);

        # Replace placeholders(with an extra backslash in em thanks to quotemeta) with regex-friendly variants,
        # ? _ => .
        $tag =~ s/\\\?|\_/\./g;
        # * % => .*
        $tag =~ s/\\\*|\\\%/\.\*/g;

        # Got the tag, check if it's present
        my $tagpresent = 0;
        if ($isexact) { # The tag must necessarily be complete if isexact = 1
            $tagpresent = $tags =~ m/(.*\,\s*|^)$tag(\,.*|$)/i; # Check for comma + potential space before and comma after the tag, or start/end of string to account for the first/last tag.
        } else {
            $tagpresent = $tags =~ m/.*$tag.*/i;
        }

        #present=true & isneg=true => false
        #present=false & isneg=false => false
        return 0 if ($tagpresent == $isneg); 

    };

    # All filters passed!
    return 1;
}



1;