package LANraragi::Plugin::Scripts::FavtagMigration;

use strict;
use warnings;

use LANraragi::Utils::Logging qw(get_logger);
use LANraragi::Model::Category;

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "Migrate Favorite Tags",
        type        => "script",
        namespace   => "favtagmigration",
        author      => "Difegue",
        version     => "1.0",
        description => "Migrate your favorite tags from LANraragi 0.6.x to Dynamic Categories in the new 0.7.0 system.",
    );

}

# Mandatory function to be implemented by your script
sub run_script {
    shift;
    my $lrr_info = shift;
    my $logger   = get_logger( "Favtag Migration", "plugins" );
    my $redis    = LANraragi::Model::Config->get_redis;

    my $migrated = 0;
    my @created_categories;

    for ( my $i = 1; $i < 6; $i++ ) {

        if ( $redis->hexists( "LRR_CONFIG", "fav" . $i ) ) {
            my $favtag = $redis->hget( "LRR_CONFIG", "fav" . $i );

            if ( $favtag ne "" ) {
                $logger->info("Migrating favtag $i: $favtag");
                $migrated++;
                my $cat = LANraragi::Model::Category::create_category( $favtag, $favtag, 0, "" );
                $logger->info("Category created: $cat");
                push @created_categories, $cat;
            }

            # Delete old favtag
            $logger->info("Deleting key fav$i from settings...");
            $redis->hdel( "LRR_CONFIG", "fav" . $i );
        }

    }

    return (
        migrated_favtags   => $migrated,
        created_categories => \@created_categories
    );

}

1;
