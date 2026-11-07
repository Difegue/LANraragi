package LANraragi::Utils::Database;

use strict;
use warnings;
use utf8;

use feature qw(signatures);
no warnings 'experimental::signatures';

use Digest::SHA qw(sha256_hex);
use Mojo::JSON  qw(decode_json);
use Encode;
use File::Basename;
use Redis;
use Cwd;
use Unicode::Normalize;
use List::Util      qw(max);
use List::MoreUtils qw(uniq);
use Time::HiRes     qw(time);

use LANraragi::Utils::Generic qw(flat);
use LANraragi::Utils::String  qw(trim trim_CRLF trim_url);
use LANraragi::Utils::Tags    qw(unflat_tagrules tags_rules_to_array restore_CRLF join_tags_to_string split_tags_to_array );
use LANraragi::Utils::Archive qw(get_filelist);
use LANraragi::Utils::Logging qw(get_logger);
use LANraragi::Utils::Path    qw(create_path open_path_or_die date_modified get_archive_path);

use LANraragi::Model::Config;

# Copy of LANraragi::Model::Search::natural_key — duplicated here to avoid
# circular dependency (Search.pm -> Archive.pm -> Database.pm -> Search.pm).
# This is a pure function with no external deps, kept in sync manually.
sub natural_key ($str) {

    my $pre = lc($str);
    $pre =~ s/\W+//s;

    my $key = '';
    my $pos = 0;

    while ( length $pre ) {
        if ( $pre =~ s/^(\d+)//s ) {
            my $n = $1;
            $n =~ s/^0+//s;
            $n = '0' if $n eq '';
            my $len = sprintf( '%08d', length $n );
            $key .= ( $pos == 0 ? "\x01\x00" : "\x02" ) . $len . $n;
        } else {
            $pre =~ s/^(.)//s;
            $key .= ( $pos == 0 ? "\x02" : "\x01" ) . $1;
        }
        $pos++;
    }

    if ( $pos == 0 ) {
        $key = "\x01\x01";
    }

    $key .= "\x00" . $str;

    return $key;
}

# Functions for interacting with the DB Model.
use Exporter 'import';
our @EXPORT_OK = qw(
  invalidate_cache compute_id change_archive_id set_tags set_title set_summary set_isnew get_computed_tagrules save_computed_tagrules get_tankoubons_by_file update_indexes rebuild_title_sort_index rebuild_nsindex
  get_archive get_archive_json get_archive_json_multi get_tags get_arcsize add_arcsize add_pagecount add_timestamp_tag add_archive_to_redis
  redis_decode redis_encode
);

# Creates a DB entry for a file path with the given ID.
# This function doesn't actually require the file to exist at its given location.
sub add_archive_to_redis ( $id, $file, $redis, $redis_search ) {

    my $logger = get_logger( "Archive", "lanraragi" );
    my ( $name, $path, $suffix ) = fileparse( $file, qr/\.[^.]*/ );

    # Initialize Redis hash for the added file
    $logger->debug("Pushing to redis on ID $id:");
    $logger->debug("File Name: $name");
    $logger->debug("Filesystem Path: $file");

    $redis->hset( $id, "name",    LANraragi::Utils::Redis::redis_encode($name) );
    $redis->hset( $id, "tags",    "" );
    $redis->hset( $id, "summary", "" );

    if ( defined($file) && -e $file ) {
        $redis->hset( $id, "arcsize", -s $file );
    }

    # Don't encode filenames.
    $redis->hset( $id, "file", $file );

    # Set title so that index is updated
    # Throw a decode in there just in case the filename is already UTF8
    set_title( $id, LANraragi::Utils::Redis::redis_decode($name) );

    # New archives can't be in a tank, so add them to the search set by default
    $redis_search->sadd( "LRR_TANKGROUPED", $id );

    # New file in collection, so this flag is set.
    set_isnew( $id, "true" );

    return $name;
}

# Updates the DB entry for the given ID to reflect the new ID.
# This is used in case the file changes substantially and its hash becomes different.
sub change_archive_id ( $old_id, $new_id ) {

    my $logger = get_logger( "Archive", "lanraragi" );
    my $redis  = LANraragi::Model::Config->get_redis;

    $logger->debug("Changing ID $old_id to $new_id");

    if ( $redis->exists($old_id) ) {
        $redis->rename( $old_id, $new_id );
    }

    # Update archive size
    my $file = get_archive_path( $redis, $new_id );
    $redis->hset( $new_id, "arcsize", -s $file );
    $redis->quit;

    # Update categories that contain the ID.
    $logger->debug("Updating categories that contained $old_id to $new_id.");
    my @categories = LANraragi::Model::Category::get_categories_containing_archive($old_id);

    foreach my $cat (@categories) {
        my $catid = %{$cat}{"id"};
        $logger->warn("Updating category $catid");
        LANraragi::Model::Category::remove_from_category( $catid, $old_id );
        LANraragi::Model::Category::add_to_category( $catid, $new_id );
    }

    # Update tanks that contain the ID
    $logger->debug("Updating tankoubons that contained $old_id to $new_id.");
    my @tanks = LANraragi::Model::Tankoubon::get_tankoubons_containing_archive($old_id);

    foreach my $tank (@tanks) {
        $logger->warn("Updating tankoubon $tank");
        LANraragi::Model::Tankoubon::remove_from_tankoubon( $tank, $old_id );
        LANraragi::Model::Tankoubon::add_to_tankoubon( $tank, $new_id );
    }
}

# Adds a timestamp tag to the given ID.
sub add_timestamp_tag ( $redis, $id ) {

    my $logger = get_logger( "Archive", "lanraragi" );

    # Initialize tags to the current date if the matching pref is enabled
    if ( LANraragi::Model::Config->enable_dateadded eq "1" ) {

        $logger->debug("Adding timestamp tag...");
        my $date;

        if ( LANraragi::Model::Config->use_lastmodified eq "1" ) {
            $logger->debug("Using file date");
            $date = date_modified( get_archive_path( $redis, $id ) );
        } else {
            $logger->debug("Using current date");
            $date = time();
        }

        set_tags( $id, "date_added:$date", 1 );
    }
}

# Calculates and adds pagecount to the given ID.
sub add_pagecount ( $redis, $id ) {

    my $logger = get_logger( "Archive", "lanraragi" );

    my $file   = get_archive_path( $redis, $id );
    my @images = get_filelist( $file, $id );
    $redis->hset( $id, "pagecount", scalar @images );
}

# Retrieves the archive's info as hash (empty if not found)
sub get_archive ($id) {
    my $redis = LANraragi::Model::Config->get_redis;
    my %hash  = $redis->hgetall($id);
    $redis->quit();
    return %hash;
}

# Builds a JSON object for an archive registered in the database and returns it.
# If you need to get many JSONs at once, use the multi variant.
sub get_archive_json ( $redis, $id ) {

    my $arcdata;

    eval {
        #Extra check in case we've been given a bogus ID
        die unless $redis->exists($id);

        if ( $id =~ /^TANK/ ) {

            $arcdata = build_tank_json($id);
        } else {
            my %hash = $redis->hgetall($id);
            $arcdata = build_json( $id, \%hash );
        }
    };

    return $arcdata;
}

# Uses Redis' MULTI to get an archive JSON for each ID.
sub get_archive_json_multi (@ids) {

    return () unless @ids;

    my $redis = LANraragi::Model::Config->get_redis;
    my $logger = get_logger( "Archive", "lanraragi" );

    # Separate Tank IDs from regular archive IDs
    my @archive_ids;
    my @tank_ids;
    for my $id (@ids) {
        if ( $id =~ /^TANK/ ) {
            push @tank_ids, $id;
        } else {
            push @archive_ids, $id;
        }
    }

    my @archives;

    # --- Batch-fetch regular archives via MULTI/EXEC (single round-trip) ---
    if (@archive_ids) {
        my $start_time = time();

        $redis->multi;
        for my $id (@archive_ids) {
            $redis->hgetall($id);
        }
        my @multi_results = $redis->exec;

        my $fetch_time = time() - $start_time;
        $logger->debug("[PERF] get_archive_json_multi: fetched " . scalar(@archive_ids) . " archives from Redis in ${fetch_time}s");

        # Build JSON objects, skipping per-item file existence checks for batch operations
        my $build_start = time();
        my $skipped = 0;
        for my $j (0 .. $#archive_ids) {
            my $id = $archive_ids[$j];
            my $fields = $multi_results[$j];

            next unless $fields && @$fields;

            # HGETALL returns flat array: [field1, val1, field2, val2, ...]
            my %hash;
            for (my $k = 0; $k < scalar @$fields; $k += 2) {
                $hash{$fields->[$k]} = $fields->[$k + 1];
            }

            # Skip file existence check in batch mode — avoids 80k+ disk stats
            my $arcdata = build_json( $id, \%hash, 1 );
            if ($arcdata) {
                push @archives, $arcdata;
            } else {
                $skipped++;
            }
        }

        my $build_time = time() - $build_start;
        $logger->debug("[PERF] get_archive_json_multi: built " . scalar(@archives) . " JSON objects ($skipped skipped) in ${build_time}s");
    }

    # --- Handle Tank IDs (unchanged logic) ---
    for my $tank_id (@tank_ids) {
        my $arcdata = build_tank_json($tank_id);
        push @archives, $arcdata if $arcdata;
    }

    $redis->quit;
    return @archives;
}

sub get_tags ($id) {
    my %archive_info = get_archive($id);
    return "" if ( !%archive_info );
    return $archive_info{tags};
}

# Internal function for building an archive JSON.
# Pass $skip_filecheck = 1 for batch operations to skip per-item disk stat.
sub build_json ( $id, $hashref, $skip_filecheck = 0 ) {

    # Grab all metadata from the hash
    my ( $name, $title, $tags, $summary, $file, $isnew, $progress, $pagecount, $lastreadtime, $arcsize, $toc ) =
      @{$hashref}{qw(name title tags summary file isnew progress pagecount lastreadtime arcsize toc)};

    $file = create_path($file);

    # Return undef if the file doesn't exist.
    # In batch mode ($skip_filecheck), trust the DB — Shinobu validates files and
    # clean_database removes stale entries. Per-item stat on 80k+ archives is the #1 bottleneck.
    return unless defined($file);
    return unless ( $skip_filecheck || -e $file );

    # Parameters have been obtained, let's decode them.
    ( $_ = LANraragi::Utils::Redis::redis_decode($_) ) for ( $name, $title, $tags, $summary );

    my @chapters = ();

    if ( defined $toc ) {
        eval { $toc = decode_json($toc) };

        if ( my $decode_error = $@ ) {
            get_logger( "Archive", "lanraragi" )->error("Failed to parse ToC JSON for archive $id: $decode_error");
            $toc = undef;
        }
        if ( defined $toc && ref($toc) eq 'HASH' ) {
            foreach my $page ( keys %$toc ) {
                push @chapters, { page => $page + 0, name => $toc->{$page} };
            }
        } elsif ( defined $toc ) {
            get_logger( "Archive", "lanraragi" )->error("ToC is not a hash: $toc");
        }

        # Sort chapters by page number
        @chapters = sort { $a->{page} <=> $b->{page} } @chapters;
    }

    # Workaround if title was incorrectly parsed as blank
    if ( !defined($title) || $title =~ /^\s*$/ ) {
        $title = $name;
    }

    my $arcdata = {
        arcid        => $id,
        title        => $title,
        filename     => $name,
        tags         => $tags // "",
        summary      => $summary,
        isnew        => $isnew ? $isnew : "false",
        extension    => lc( ( split( /\./, $file ) )[-1] ),
        progress     => $progress     ? int($progress)     : 0,
        pagecount    => $pagecount    ? int($pagecount)    : 0,
        lastreadtime => $lastreadtime ? int($lastreadtime) : 0,
        size         => $arcsize      ? int($arcsize)      : 0,
        toc          => \@chapters
    };

    return $arcdata;
}

# Ditto for Tank IDs.
sub build_tank_json ($id) {
    my %tank = LANraragi::Model::Tankoubon::get_tankoubon( $id, 1 );

    # Aggregate data of all archives in the tank
    my $aggregate_names     = "";
    my $aggregate_isnew     = 0;
    my $aggregate_pagecount = 0;
    my $latest_readtime     = 0;
    my $aggregate_size      = 0;

    my @archive_tag_strings;
    foreach my $archive_info ( @{ $tank{full_data} } ) {
        push @archive_tag_strings, %$archive_info{tags} // "";
        $aggregate_names .= %$archive_info{title} . ",";
        $aggregate_isnew     = $aggregate_isnew || (%$archive_info{isnew} eq "true");
        $aggregate_pagecount = $aggregate_pagecount + %$archive_info{pagecount};
        $aggregate_size      = $aggregate_size + %$archive_info{size};
        $latest_readtime     = max( $latest_readtime, %$archive_info{lastreadtime} // 0);
    }

    chop $aggregate_names;

    # Get unified tagset using shared function
    my $tagset = LANraragi::Model::Tankoubon::get_tank_unified_tags( $id, \@archive_tag_strings );
    my $deduped_tags = join( ",", @{ $tagset->{own_tags} }, @{ $tagset->{imputed_tags} } );

    my $arcdata = {
        arcid         => $id,
        title         => $tank{name},
        filename      => "",
        tags          => $deduped_tags,
        summary       => "Tankoubon containing: $aggregate_names",
        isnew         => $aggregate_isnew ? "true" : "false",
        extension     => ".tank",
        progress      => $tank{progress} || 0,
        pagecount     => $aggregate_pagecount,
        lastreadtime  => $latest_readtime,
        size          => $aggregate_size,
        archive_count => scalar @{ $tank{archives} }
    };

    return $arcdata;
}

# drop_database()
# Drops the entire database. Hella dangerous
# TODO: Might be worth it to add versions that only do flushdb on certain databases like the config/archive data one?
sub drop_database {
    my $redis = LANraragi::Model::Config->get_redis;

    $redis->flushall();
    $redis->quit;
}

# clean_database()
# Remove entries from the database that don't have a matching archive on the filesystem.
# Returns the number of entries deleted/unlinked.
sub clean_database {
    my $redis        = LANraragi::Model::Config->get_redis;
    my $redis_config = LANraragi::Model::Config->get_redis_config;
    my $logger       = get_logger( "Archive", "lanraragi" );

    eval {
        # Save an autobackup somewhere before cleaning
        my $outfile = getcwd() . "/autobackup.json";
        $logger->info("Saving automatic backup to $outfile");
        open( my $fh, '>', $outfile );
        print $fh LANraragi::Model::Backup::build_backup_JSON();
        close $fh;
    };

    if ($@) {
        $logger->warn("Unable to open a file to save backup before cleaning database! $@");
    }

    # Get the filemap for ID checks later down the line
    my @filemapids = $redis_config->exists("LRR_FILEMAP") ? $redis_config->hvals("LRR_FILEMAP") : ();
    my %filemap    = map { $_ => 1 } @filemapids;

    #40-character long keys only => Archive IDs
    my @keys = $redis->keys('????????????????????????????????????????');

    my $deleted_arcs  = 0;
    my $unlinked_arcs = 0;

    foreach my $id (@keys) {

        # Check if the DB entry is correct
        eval { $redis->hgetall($id); };

        if ($@) {
            LANraragi::Model::Archive::delete_archive($id);
            $deleted_arcs++;
            next;
        }

        # Check if the linked file exists
        my $file = get_archive_path( $redis, $id );
        unless ( -e $file ) {
            LANraragi::Model::Archive::delete_archive($id);
            $deleted_arcs++;
            next;
        }

        # If the linked file exists, check if its ID is in the filemap
        unless ( $file eq "" || exists $filemap{$id} ) {
            $logger->warn("File exists but its ID is no longer $id!");
            $logger->warn("Trying to find its new ID in the Shinobu filemap...");

            if ( $redis_config->hexists( "LRR_FILEMAP", $file ) ) {
                my $newid = $redis_config->hget( "LRR_FILEMAP", $file );
                $logger->warn("Found $newid in the filemap! Changing ID from $id to it.");

                if ( $redis->exists($newid) ) {
                    $logger->warn("ID $newid already exists in the database! Unlinking old ID.");
                    $redis->hset( $id, "file", "" );
                } else {
                    change_archive_id( $id, $newid );
                    $redis_config->hset( "LRR_FILEMAP", $file, $newid );
                }

            } else {
                $logger->warn("File $file not found in the filemap! Removing file reference in the database entry for $id.");
                $redis->hset( $id, "file", "" );
                $unlinked_arcs++;
            }

        }
    }

    $redis->quit;
    $redis_config->quit;
    return ( $deleted_arcs, $unlinked_arcs );
}

sub set_title ( $id, $newtitle ) {

    my $redis        = LANraragi::Model::Config->get_redis;
    my $redis_search = LANraragi::Model::Config->get_redis_search;

    if ( $newtitle ne "" ) {

        # Remove old title from search set
        if ( $redis->hexists( $id, "title" ) ) {
            my $oldtitle = lc( LANraragi::Utils::Redis::redis_decode( $redis->hget( $id, "title" ) ) );
            $oldtitle = trim($oldtitle);
            $oldtitle = trim_CRLF($oldtitle);
            $oldtitle = LANraragi::Utils::Redis::redis_encode($oldtitle);
            $redis_search->zrem( "LRR_TITLES", "$oldtitle\0$id" );
        }

        # Set actual title in metadata DB
        $redis->hset( $id, "title", LANraragi::Utils::Redis::redis_encode($newtitle) );

        # Set title/ID key in search set
        $newtitle = lc($newtitle);
        $newtitle = trim($newtitle);
        $newtitle = trim_CRLF($newtitle);
        $newtitle = LANraragi::Utils::Redis::redis_encode($newtitle);
        $redis_search->zadd( "LRR_TITLES", 0, "$newtitle\0$id" );

        # Invalidate the precomputed title sort index — it will be rebuilt lazily on next search
        $redis_search->del("LRR_SORTED_title");
    }
    $redis->quit;
    $redis_search->quit;
}

# Rebuild the precomputed title sort index (LRR_SORTED_title).
# Stores a naturally-sorted list of IDs as a Redis List for O(1) retrieval.
# Called lazily on first title-sorted search, or explicitly during cache warmup.
sub rebuild_title_sort_index {

    my $redis_search = LANraragi::Model::Config->get_redis_search;
    my $logger       = get_logger( "Search", "lanraragi" );

    my $start = time();
    $logger->info("Rebuilding title sort index...");

    # Get all title\x00id entries, sorted by natural_key
    my @entries = $redis_search->zrangebylex( "LRR_TITLES", "-", "+" );
    $logger->info("Title sort index: fetched " . scalar(@entries) . " entries from LRR_TITLES");
    my @sorted_ids = map  { $_->[0] }
                     sort { $a->[1] cmp $b->[1] }
                     map  {
                         # Extract the title part (before \x00) for natural_key computation
                         my $title = substr($_, 0, index($_, "\x00"));
                         my $id    = substr($_, index($_, "\x00") + 1);
                         [ $id, natural_key($title) ]
                     }
                     @entries;

    # Store as a Redis list (delete old, then RPUSH all)
    $redis_search->del("LRR_SORTED_title");
    $redis_search->rpush( "LRR_SORTED_title", @sorted_ids ) if @sorted_ids;

    my $elapsed = sprintf( "%.2f", time() - $start );
    $logger->info("Title sort index rebuilt: " . scalar(@sorted_ids) . " archives in ${elapsed}s");

    $redis_search->quit;
    return scalar(@sorted_ids);
}

# Rebuild all NSINDEX_* namespace secondary indexes for fuzzy tag search (P1-B).
# Scans every archive's tags and rebuilds NSINDEX_<namespace>: sets from scratch.
# Called lazily on startup if indexes are missing, or explicitly during cache warmup.
sub rebuild_nsindex {

    my $logger       = get_logger( "Search", "lanraragi" );
    my $redis        = LANraragi::Model::Config->get_redis;
    my $redis_search = LANraragi::Model::Config->get_redis_search;

    my $start = time();
    $logger->info("Rebuilding NSINDEX_* namespace indexes...");

    # Get all archive IDs
    my @ids = $redis->keys('????????????????????????????????????????');

    # Delete all existing NSINDEX_* keys
    my @old_nskeys = $redis_search->keys('NSINDEX_*');
    if (@old_nskeys) {
        $redis_search->del(@old_nskeys);
    }

    # Batch-fetch tags via MULTI/EXEC
    my $batch_size = 1000;
    my %ns_counts;
    my $processed = 0;

    for ( my $i = 0 ; $i < scalar @ids ; $i += $batch_size ) {
        my $end = $i + $batch_size - 1;
        $end = $#ids if $end > $#ids;
        my @batch = @ids[ $i .. $end ];

        $redis->multi;
        $redis->hget( $_, "tags" ) for @batch;
        my @results = $redis->exec;

        for my $j ( 0 .. $#batch ) {
            my $id   = $batch[$j];
            my $tags = $results[$j];
            next unless defined $tags;

            $tags = LANraragi::Utils::Redis::redis_decode($tags);
            my @tag_list = split( /,\s?/, $tags );

            foreach my $tag (@tag_list) {
                $tag = lc($tag);
                if ( $tag =~ /^([^:]+):/ ) {
                    my $ns = $1 . ":";
                    # Redis module requires octet strings
                    my $ns_key = LANraragi::Utils::Redis::redis_encode("NSINDEX_" . $ns);
                    $redis_search->sadd( $ns_key, $id );
                    $ns_counts{$ns}++;
                }
            }
        }

        $processed += scalar(@batch);
        if ( $processed % 10000 == 0 || $processed == scalar @ids ) {
            $logger->info("NSINDEX rebuild progress: $processed / " . scalar(@ids) . " archives");
        }
    }

    my $elapsed = sprintf( "%.2f", time() - $start );
    $logger->info("NSINDEX_* rebuilt: " . scalar(keys %ns_counts) . " namespaces, $processed archives in ${elapsed}s");

    $redis->quit;
    $redis_search->quit;
    return scalar( keys %ns_counts );
}

# Set $tags for the archive with id $id.
# Set $append to 1 if you want to append the tags instead of replacing them.
sub set_tags ( $id, $newtags, $append = 0 ) {

    my $redis   = LANraragi::Model::Config->get_redis;
    my $oldtags = $redis->hget( $id, "tags" );
    $oldtags = LANraragi::Utils::Redis::redis_decode($oldtags);
    my $original_oldtags = $oldtags // "";

    if ($append) {

        # If the new tags are empty, don't do anything
        unless ( length $newtags ) { return; }

        if ($oldtags) {
            $oldtags = trim($oldtags);

            if ( $oldtags ne "" ) {
                $newtags = $oldtags . "," . $newtags;
            }
        }
    }

    $newtags = join_tags_to_string( uniq( split_tags_to_array($newtags) ) );

    # Update sets depending on the added/removed tags
    update_indexes( $id, $oldtags, $newtags );

    $redis->hset( $id, "tags", LANraragi::Utils::Redis::redis_encode($newtags) );
    $redis->quit;

    # Update imputed indexes for any tanks containing this archive
    foreach my $tank_id ( LANraragi::Model::Tankoubon::get_tankoubons_containing_archive($id) ) {
        LANraragi::Model::Tankoubon::update_tank_imputed_indexes( $tank_id, [ split_tags_to_array($original_oldtags) ] );
    }

    invalidate_cache();
}

sub set_summary ( $id, $summary ) {

    my $redis = LANraragi::Model::Config->get_redis;
    $redis->hset( $id, "summary", LANraragi::Utils::Redis::redis_encode($summary) );
    $redis->quit;
}

# Set $isnew for the archive with id $id.
sub set_isnew ( $id, $isnew ) {

    my $redis        = LANraragi::Model::Config->get_redis;
    my $redis_search = LANraragi::Model::Config->get_redis_search;

    # Just set isnew for the provided ID.
    my $newval = $isnew ne "false" ? "true" : "false";

    $redis->hset( $id, "isnew", $newval );

    if ( $newval eq "true" ) {
        $redis_search->sadd( "LRR_NEW", $id );
    } else {
        $redis_search->srem( "LRR_NEW", $id );
    }

    $redis_search->quit;
    $redis->quit;

    invalidate_cache();
}

# Splits both old and new tags, and:
# Removes the ID from all sets of the old tags
# Adds it back to all sets of the new tags.
sub update_indexes ( $id, $oldtags, $newtags ) {

    my $is_tank = ( $id =~ /^TANK/ );
    my $redis   = LANraragi::Model::Config->get_redis_search;
    $redis->multi;

    my @oldtags  = split( /,\s?/, $oldtags // "" );
    my @newtags  = split( /,\s?/, $newtags // "" );
    my $has_tags = 0;

    foreach my $tag (@oldtags) {

        unless ($is_tank) {
            if ( $tag =~ /source:(.*)/i ) {
                my $url = trim_url($1);
                $redis->hdel( "LRR_URLMAP", $url );
            }
        }

        # Tag is lowercased here to avoid redundancy/dupes
        $tag = LANraragi::Utils::Redis::redis_encode( lc($tag) );

        # Update tag index and stats for the tag
        $redis->srem( "INDEX_" . $tag, $id );
        $redis->zincrby( "LRR_STATS", -1, $tag );

        # P1-B: Update namespace secondary index for fuzzy tag search
        # e.g. tag "female:big_breasts" -> NSINDEX_female:
        if ( $tag =~ /^([^:]+):/ ) {
            my $ns = $1 . ":";
            $redis->srem( "NSINDEX_" . $ns, $id );
        }
    }

    foreach my $tag (@newtags) {

        # The following are basic and therefore don't count as "tagged"
        $has_tags = 1 unless $tag =~ /(artist|parody|series|language|event|group|date_added|timestamp|source):.*/;

        unless ($is_tank) {
            # If the tag is a source: tag, add it to the URL index
            if ( $tag =~ /source:(.*)/i ) {
                my $url = trim_url($1);
                $redis->hset( "LRR_URLMAP", $url, $id );
            }
        }

        $tag = LANraragi::Utils::Redis::redis_encode( lc($tag) );

        # Update tag index and stats for the tag
        $redis->sadd( "INDEX_" . $tag, $id );
        $redis->zincrby( "LRR_STATS", 1, $tag );

        # P1-B: Update namespace secondary index for fuzzy tag search
        if ( $tag =~ /^([^:]+):/ ) {
            my $ns = $1 . ":";
            $redis->sadd( "NSINDEX_" . $ns, $id );
        }
    }

    # Add or remove the ID from the untagged list (not applicable to tanks)
    unless ($is_tank) {
        if ($has_tags) {
            $redis->srem( "LRR_UNTAGGED", $id );
        } else {
            $redis->sadd( "LRR_UNTAGGED", $id );
        }
    }

    $redis->exec;
    $redis->quit;
}

# This function is used for all ID computation in LRR.
# Takes the path to the file as an argument.
sub compute_id ($file) {

    #Read the first 512 KBs only (allows for faster disk speeds )
    open_path_or_die( my $handle, '<:raw', $file );
    my $data;
    my $len = read $handle, $data, 512000;
    close $handle;

    #Compute a SHA-1 hash of this data
    my $ctx = Digest::SHA->new(1);
    $ctx->add($data);
    my $digest = $ctx->hexdigest;

    if ( $digest eq "da39a3ee5e6b4b0d3255bfef95601890afd80709" ) {
        die "Computed ID is for a null value, invalid source file.";
    }

    return $digest;

}

# Bust the current search cache key in Redis.
# Add "1" as a parameter to rebuild stat hashes as well. (Use with caution!)
sub invalidate_cache ( $rebuild_indexes = 0 ) {

    my $redis = LANraragi::Model::Config->get_redis_search;
    $redis->del("LRR_SEARCHCACHE");
    $redis->del("LRR_ARCLIST_CACHE");
    $redis->del("LRR_SORTED_title");
    $redis->hset( "LRR_SEARCHCACHE", "created", time );
    $redis->quit();

    if ($rebuild_indexes) {
        LANraragi::Model::Config->get_minion->enqueue( build_stat_hashes => [] => { priority => 3 } );
    }
}

sub save_computed_tagrules ($tagrules) {

    my $redis = LANraragi::Model::Config->get_redis_config;
    $redis->del("LRR_TAGRULES");

    if (@$tagrules) {
        my @flat         = reverse flat(@$tagrules);
        my @encoded_flat = map { LANraragi::Utils::Redis::redis_encode($_) } @flat;
        $redis->lpush( "LRR_TAGRULES", @encoded_flat );
    }

    $redis->quit();
    return;
}

sub get_computed_tagrules {
    my @tagrules;

    my $redis = LANraragi::Model::Config->get_redis_config;

    if ( $redis->exists("LRR_TAGRULES") ) {
        my @flattened_rules = $redis->lrange( "LRR_TAGRULES", 0, -1 );
        my @decoded_rules   = map { LANraragi::Utils::Redis::redis_decode($_) } @flattened_rules;
        @tagrules = unflat_tagrules( \@decoded_rules );
    } else {
        @tagrules = tags_rules_to_array( restore_CRLF( LANraragi::Model::Config->get_tagrules ) );
        $redis->lpush( "LRR_TAGRULES", reverse flat(@tagrules) ) if (@tagrules);
    }

    $redis->quit();
    return @tagrules;
}

sub add_arcsize ( $redis, $id ) {
    my $file = get_archive_path( $redis, $id );
    $redis->hset( $id, "arcsize", -s $file );
}

sub get_arcsize ( $redis, $id ) {
    return $redis->hget( $id, "arcsize" );
}

# DEPRECATED - Please use LANraragi::Utils::Redis::redis_decode instead, this function will be removed at some point
sub redis_encode ($data) {
    return LANraragi::Utils::Redis::redis_encode($data);
}

# DEPRECATED - Please use LANraragi::Utils::Redis::redis_decode instead, this function will be removed at some point
sub redis_decode ($data) {
    return LANraragi::Utils::Redis::redis_decode($data);
}

1;
