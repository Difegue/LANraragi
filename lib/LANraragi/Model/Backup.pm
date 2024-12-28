package LANraragi::Model::Backup;

use strict;
use warnings;
use utf8;

use Redis;
use Mojo::JSON qw(decode_json encode_json);

use LANraragi::Model::Category;
use LANraragi::Model::Tankoubon;
use LANraragi::Utils::Database;
use LANraragi::Utils::String   qw(trim_CRLF);
use LANraragi::Utils::Database qw(redis_encode redis_decode invalidate_cache set_title set_tags set_summary);
use LANraragi::Utils::Logging  qw(get_logger);

#build_backup_JSON()
#Goes through the Redis archive IDs and builds a JSON string containing their metadata.
sub build_backup_JSON {
    my $redis  = LANraragi::Model::Config->get_redis;
    my $logger = get_logger( "Backup/Restore", "lanraragi" );

    # Basic structure of the backup object
    my %backup = (
        categories => [],
        archives   => []
    );

    # Backup categories first
    my @cats = $redis->keys('SET_??????????');

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

    }

    # Backup tanks
    my ( $total, $filtered, @tanks ) = LANraragi::Model::Tankoubon::get_tankoubon_list(-1);
    foreach my $tank (@tanks) {

        my $tank_id       = %$tank{id};
        my $tank_title    = %$tank{name};
        my @tank_archives = @{ %$tank{archives} };

        my %tank = (
            tankid   => $tank_id,
            name     => $tank_title,
            archives => \@tank_archives
        );

        push @{ $backup{tankoubons} }, \%tank;
    }

    # Backup archives themselves next
    my @keys = $redis->keys('????????????????????????????????????????');    #40-character long keys only => Archive IDs

    # Parse the archive list and add them to JSON.
    foreach my $id (@keys) {

        eval {
            my %hash = $redis->hgetall($id);
            my ( $name, $title, $tags, $summary, $thumbhash ) = @hash{qw(name title tags summary thumbhash)};

            ( $_ = redis_decode($_) ) for ( $name, $title, $tags, $summary );
            ( $_ = trim_CRLF($_) )    for ( $name, $title, $tags, $summary );

            # Backup all user-generated metadata, alongside the unique ID.
            my %arc = (
                arcid     => $id,
                title     => $title,
                tags      => $tags,
                summary   => $summary,
                thumbhash => $thumbhash,
                filename  => $name
            );

            push @{ $backup{archives} }, \%arc;
        };

        $logger->trace("Backing up archive $id: $@");

    }

    $redis->quit();
    return encode_json \%backup;

}

#restore_from_JSON(backupJSON)
#Restores metadata from a JSON to the Redis archive, for existing IDs.
sub restore_from_JSON {
    my $redis  = LANraragi::Model::Config->get_redis;
    my $logger = get_logger( "Backup/Restore", "lanraragi" );
    my $json   = decode_json( $_[0] );

    $logger->info("Received a JSON backup to restore.");

    # Clean the database before restoring from JSON
    LANraragi::Utils::Database::clean_database();

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
    }

    foreach my $tank ( @{ $json->{tankoubons} } ) {

        my $tank_id = $tank->{"tankid"};
        $logger->info("Restoring Tankoubon $tank_id...");

        my $name     = redis_encode( $tank->{"name"} );
        my @archives = @{ $tank->{"archives"} };

        LANraragi::Model::Tankoubon::create_tankoubon( $name, $tank_id );

        # Backups use the same data structure as tank updates, so we can just pass the data object as-is.
        LANraragi::Model::Tankoubon::update_archive_list( $tank_id, $tank );
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

        }
    }

    # Force a refresh
    invalidate_cache();
    $redis->quit();
}

1;
