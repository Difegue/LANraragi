package LANraragi::Model::Setup;
use strict;
use warnings;
use utf8;

use LANraragi::Model::Config qw(get_redis_config);
use LANraragi::Utils::Logging qw(get_logger);
use LANraragi::Model::Category;

use Exporter 'import';
our @EXPORT_OK = qw(first_install_actions);

# first_install_actions()
# Setup tasks for first-time installations. New installs are checked by confirming updated
# user settings. On first installation, create default 'Favorites' category link it to the bookmark
# button. Returns 1 if is first-time installation, else 0.
sub first_install_actions {
    my $redis = LANraragi::Model::Config::get_redis_config();
    my $logger = get_logger( "Config", "lanraragi" );
    unless ( $redis->hexists('LRR_CONFIG', 'htmltitle') ) {
        $logger->info("First-time installation detected!");
        $redis->hset('LRR_CONFIG', 'htmltitle', 'LANraragi');

        $logger->debug("Creating first category...");
        my $default_category_id = LANraragi::Model::Category::create_category("🔖 Favorites", "", 0, "");
        LANraragi::Model::Category::update_bookmark_link($default_category_id);
        $logger->info("Created default Favorites category.");
        $redis->quit();
        return 1;
    }
    $redis->quit();
    return 0;
}

1;
