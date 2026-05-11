package LANraragi::Model::Backup;

use strict;
use warnings;
use utf8;

use Redis;
use Mojo::JSON qw(decode_json encode_json);

use LANraragi::Model::Category;
use LANraragi::Model::Tankoubon;
use LANraragi::Utils::String   qw(trim_CRLF);
use LANraragi::Utils::Database qw(invalidate_cache set_title set_tags set_summary);
use LANraragi::Utils::Logging  qw(get_logger);
use LANraragi::Utils::Redis    qw(redis_decode redis_encode);

#build_backup_JSON($job)
#Goes through the Redis archive IDs and builds a JSON string containing their metadata.
#If $job is provided (Minion job), progress will be reported via job notes.
sub build_backup_JSON {
    my ($job)  = @_;
    my $redis  = LANraragi::Model::Config->get_redis;
    my $logger = get_logger( "Backup/Restore", "lanraragi" );

    # Basic structure of the backup object
    my %backup = (
        categories => [],
        archives   => []
    );

    # Backup categories first
    my @cats       = $redis->keys('SET_??????????');
    my $cat_count  = 0;
    my $total_cats = scalar @cats;

    # Parse the category list and add them to JSON.
    foreach my $key (@cats) {

        # Use an eval block in case decode_json fails. This'll drop the category from the backup,
        # But it's probably dinged anyways...
        eval {
            my %data = $redis->hgetall($key);
            my ( $name, $search, $archives ) = @data{qw(name search archives)};

            # redis-decode the name, and the search terms if they exist
            ( $_ = redis_decode($_) ) for ( $name, $search );

            my %category = (
                catid    => $key,
                name     => $name,
                search   => $search,
                archives => decode_json($archives)
            );

            push @{ $backup{categories} }, \%category;
        };

        $logger->trace("Backing up category $key: $@");
        $cat_count++;

        # Report progress if job is provided
        if ($job) {
            $job->note(
                categories_processed => $cat_count,
                total_categories     => $total_cats,
                status               => "Processing categories..."
            );
        }
    }

    # Backup tanks
    my ( $total, $filtered, @tanks ) = LANraragi::Model::Tankoubon::get_tankoubon_list(-1);
    my $tank_count  = 0;
    my $total_tanks = scalar @tanks;

    foreach my $tank (@tanks) {

        my $tank_id       = %$tank{id};
        my $tank_title    = %$tank{name};
        my $tank_summary  = %$tank{summary} // "";
        my $tank_tags     = %$tank{tags}    // "";
        my @tank_archives = @{ %$tank{archives} };

        my %tank = (
            tankid   => $tank_id,
            name     => $tank_title,
            summary  => $tank_summary,
            tags     => $tank_tags,
            archives => \@tank_archives
        );

        push @{ $backup{tankoubons} }, \%tank;
        $tank_count++;

        # Report progress if job is provided
        if ($job) {
            $job->note(
                categories_processed => $cat_count,
                total_categories     => $total_cats,
                tankoubons_processed => $tank_count,
                total_tankoubons     => $total_tanks,
                status               => "Processing tankoubons..."
            );
        }
    }

    # Backup stamps
    my @stamp_ids = $redis->keys('STAMPS_*');

    foreach my $stamp_id (@stamp_ids) {
        eval {
            my %stamp_hash = $redis->hgetall($stamp_id);
            my ( $content, $position, $archive_id ) = @stamp_hash{qw(content position archive_id)};

            ( $_ = redis_decode($_) ) for ( $content, $position, $archive_id );
            ( $_ = trim_CRLF($_) )    for ( $content, $position, $archive_id );

            my %stamp = (
                stamp_id    => $stamp_id,
                content     => $content,
                position    => $position,
                archive_id  => $archive_id
            );

            push @{ $backup{stamps} }, \%stamp;
        };

        $logger->trace("Backing up stamp $stamp_id: $@");
    }

    # Backup archives themselves next
    my @keys       = $redis->keys('????????????????????????????????????????');    #40-character long keys only => Archive IDs
    my $arc_count  = 0;
    my $total_arcs = scalar @keys;

    # Parse the archive list and add them to JSON.
    foreach my $id (@keys) {

        eval {
            my %hash = $redis->hgetall($id);
            my ( $name, $title, $tags, $summary, $thumbhash, $stamps ) = @hash{qw(name title tags summary thumbhash stamps)};

            ( $_ = redis_decode($_) ) for ( $name, $title, $tags, $summary );
            ( $_ = trim_CRLF($_) )    for ( $name, $title, $tags, $summary );

            # Backup all user-generated metadata, alongside the unique ID.
            my %arc = (
                arcid     => $id,
                title     => $title,
                tags      => $tags,
                summary   => $summary,
                thumbhash => $thumbhash,
                filename  => $name,
                stamps    => $stamps
            );

            push @{ $backup{archives} }, \%arc;
        };

        $logger->trace("Backing up archive $id: $@");
        $arc_count++;

        # Report progress every 100 archives if job is provided
        if ( $job && $arc_count % 100 == 0 ) {
            $job->note(
                categories_processed => $cat_count,
                total_categories     => $total_cats,
                tankoubons_processed => $tank_count,
                total_tankoubons     => $total_tanks,
                archives_processed   => $arc_count,
                total_archives       => $total_arcs,
                status               => "Processing archives..."
            );
        }

    }

    # Final progress update
    if ($job) {
        $job->note(
            categories_processed => $cat_count,
            total_categories     => $total_cats,
            tankoubons_processed => $tank_count,
            total_tankoubons     => $total_tanks,
            archives_processed   => $arc_count,
            total_archives       => $total_arcs,
            status               => "Finalizing backup..."
        );
    }

    $redis->quit();
    return encode_json \%backup;

}

#restore_from_JSON(backupJSON, $job)
#Restores metadata from a JSON to the Redis archive, for existing IDs.
#If $job is provided (Minion job), progress will be reported via job notes.
sub restore_from_JSON {
    my ( $json_data, $job ) = @_;
    my $redis  = LANraragi::Model::Config->get_redis;
    my $logger = get_logger( "Backup/Restore", "lanraragi" );
    my $json   = decode_json($json_data);

    $logger->info("Received a JSON backup to restore.");

    # Clean the database before restoring from JSON
    LANraragi::Utils::Database::clean_database();

    my $cat_count   = 0;
    my $total_cats  = scalar @{ $json->{categories} };
    my $tank_count  = 0;
    my $total_tanks = $json->{tankoubons} ? scalar @{ $json->{tankoubons} } : 0;
    my $arc_count   = 0;
    my $total_arcs  = scalar @{ $json->{archives} };

    foreach my $category ( @{ $json->{categories} } ) {

        my $cat_id = $category->{"catid"};
        $logger->info("Restoring Category $cat_id...");

        my $name     = redis_encode( $category->{"name"} );
        my $search   = redis_encode( $category->{"search"} );
        my @archives = @{ $category->{"archives"} };

        LANraragi::Model::Category::create_category( $name, $search, 0, $cat_id );

        # Explicitly set "new category" values to avoid them being absent from the DB entry
        # (which likely breaks a bunch of things)
        $redis->hset( $cat_id, "archives", "[]" );

        foreach my $arcid (@archives) {
            LANraragi::Model::Category::add_to_category( $cat_id, $arcid );
        }

        $cat_count++;

        # Report progress if job is provided
        if ($job) {
            $job->note(
                categories_processed => $cat_count,
                total_categories     => $total_cats,
                status               => "Restoring categories..."
            );
        }
    }

    foreach my $tank ( @{ $json->{tankoubons} } ) {

        my $tank_id = $tank->{"tankid"};
        $logger->info("Restoring Tankoubon $tank_id...");

        my $name     = redis_encode( $tank->{"name"} );
        my $summary  = $tank->{"summary"} // "";
        my $tags     = $tank->{"tags"}    // "";
        my @archives = @{ $tank->{"archives"} };

        LANraragi::Model::Tankoubon::create_tankoubon( $name, $tank_id );

        # Restore summary and tags if present
        if ( $summary ne "" ) {
            LANraragi::Model::Tankoubon::update_metadata( $tank_id, undef, $summary, undef );
        }
        if ( $tags ne "" ) {
            LANraragi::Model::Tankoubon::set_tank_tags( $tank_id, $tags );
        }

        # Backups use the same data structure as tank updates, so we can just pass the data object as-is.
        LANraragi::Model::Tankoubon::update_archive_list( $tank_id, $tank );

        $tank_count++;

        # Report progress if job is provided
        if ($job) {
            $job->note(
                categories_processed => $cat_count,
                total_categories     => $total_cats,
                tankoubons_processed => $tank_count,
                total_tankoubons     => $total_tanks,
                status               => "Restoring tankoubons..."
            );
        }
    }

    foreach my $archive ( @{ $json->{archives} } ) {
        my $id = $archive->{"arcid"};

        #If the archive exists, restore metadata.
        if ( $redis->exists($id) ) {

            $logger->info("Restoring metadata for Archive $id...");
            my $thumbhash = redis_encode( $archive->{"thumbhash"} );

            set_title( $id, $archive->{"title"} );
            set_tags( $id, $archive->{"tags"} );
            set_summary( $id, $archive->{"summary"} );

            if (   $redis->hexists( $id, "thumbhash" )
                && $redis->hget( $id, "thumbhash" ) ne "" ) {
                $redis->hset( $id, "thumbhash", $thumbhash );
            }

            if ( defined $archive->{"stamps"} ) {
                my $stamps = redis_encode( $archive->{"stamps"} );
                $redis->hset( $id, "stamps", $stamps );
            } else {
                $redis->hset( $id, "stamps", "[]" );
            }

        }
    }

    foreach my $stamp ( @{ $json->{stamps} } ) {
        my $stamp_id = $stamp->{"stamp_id"};

        my $content = $stamp->{"content"};
        my $position = $stamp->{"position"};
        my $archive_id = $stamp->{"archive_id"};

        #If the archive exists, restore metadata.
        if ( $redis->exists($archive_id) ) {

            ( $_ = redis_encode($_) ) for ( $content, $position, $archive_id );

            $redis->hset( $stamp_id, "content", $content);
            $redis->hset( $stamp_id, "position", $position);
            $redis->hset( $stamp_id, "archive_id", $archive_id);
        }

        $arc_count++;

        # Report progress periodically (every 100 archives) if job is provided
        if ( $job && $arc_count % 100 == 0 ) {
            $job->note(
                categories_processed => $cat_count,
                total_categories     => $total_cats,
                tankoubons_processed => $tank_count,
                total_tankoubons     => $total_tanks,
                archives_processed   => $arc_count,
                total_archives       => $total_arcs,
                status               => "Restoring archives..."
            );
        }
    }

    # Final progress update
    if ($job) {
        $job->note(
            categories_processed => $cat_count,
            total_categories     => $total_cats,
            tankoubons_processed => $tank_count,
            total_tankoubons     => $total_tanks,
            archives_processed   => $arc_count,
            total_archives       => $total_arcs,
            status               => "Finalizing restore..."
        );
    }

    # Force a refresh
    invalidate_cache();
    $redis->quit();
}

1;
