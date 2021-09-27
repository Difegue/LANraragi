package LANraragi::Plugin::Scripts::BlacklistMigrate;

use strict;
use warnings;
no warnings 'uninitialized';

use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::Database qw(save_computed_tagrules);
use LANraragi::Utils::Tags qw(tags_rules_to_array restore_CRLF);
use LANraragi::Utils::Generic qw(remove_spaces);
use Mojo::JSON qw(encode_json);
use LANraragi::Model::Config;

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "Blacklist Migration",
        type        => "script",
        namespace   => "blist2rule",
        author      => "Difegue",
        version     => "1.0",
        description => "Migrate your blacklist from LANraragi < 0.8.0 databases to the new Tag Rules system."
    );

}

# Mandatory function to be implemented by your script
sub run_script {
    shift;
    my $lrr_info = shift;    # Global info hash

    my $logger = get_plugin_logger();
    my $redis  = LANraragi::Model::Config->get_redis;

    my $blist = LANraragi::Model::Config::get_redis_conf( "blacklist", undef );
    my $rules = LANraragi::Model::Config::get_redis_conf( "tagrules",
        "-already uploaded;-forbidden content;-incomplete;-ongoing;-complete;-various;-digital;-translated;-russian;-chinese;-portuguese;-french;-spanish;-italian;-vietnamese;-german;-indonesian"
    );

    unless ($blist) {
        $logger->info("No blacklist in config, nothing to migrate!");
        return ( status => "Nothing to migrate" );
    }

    $logger->debug("Blacklist is $blist");
    $logger->debug("Rules are $rules");
    my @blacklist = split( ',', $blist );    # array-ize the blacklist string
    my $migrated = 0;

    # Parse the blacklist and add matching tag rules.
    foreach my $tag (@blacklist) {

        remove_spaces($tag);
        if ( index( uc($rules), uc($tag) ) == -1 ) {
            $logger->debug("Adding rule -$tag");
            $rules = $rules . ";-$tag";
            $migrated++;
        }
    }

    # Save rules and recompute them
    $redis->hset( "LRR_CONFIG", "tagrules", $rules );
    $redis->hdel( "LRR_CONFIG", "blacklist" );

    my @computed_tagrules = tags_rules_to_array( restore_CRLF($rules) );
    $logger->debug( "Saving computed tag rules : " . encode_json( \@computed_tagrules ) );
    save_computed_tagrules( \@computed_tagrules );

    return ( migrated_tags => $migrated );
}

1;
