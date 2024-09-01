package LANraragi::Model::Plugins;

use v5.36;
use experimental 'try';

use strict;
use warnings;
use utf8;
use feature 'fc';

use Redis;
use Encode;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::UserAgent;
use Data::Dumper;

use LANraragi::Utils::String   qw(trim);
use LANraragi::Utils::Database qw(set_tags set_title set_summary);
use LANraragi::Utils::Archive  qw(extract_thumbnail);
use LANraragi::Utils::Logging  qw(get_logger);
use LANraragi::Utils::Tags     qw(rewrite_tags split_tags_to_array);

# Sub used by Auto-Plugin.
sub exec_enabled_plugins_on_file {

    my $id     = shift;
    my $logger = get_logger( "Auto-Plugin", "lanraragi" );

    $logger->info("Executing enabled metadata plugins on archive with id $id.");

    my $successes = 0;
    my $failures  = 0;
    my $addedtags = 0;
    my $newtitle  = "";

    my @plugins = LANraragi::Utils::Plugins::get_enabled_plugins("metadata");

    # If the regex plugin is in the list, make sure it's ran first.
    # TODO: Make plugin exec order configurable
    foreach my $plugin (@plugins) {
        if ( $plugin->{namespace} eq "regexplugin" ) {
            my $regex_plugin = $plugin;

            # Remove element from array
            @plugins = grep { $_->{namespace} ne "regexplugin" } @plugins;
            unshift @plugins, $regex_plugin;
            last;
        }
    }

    foreach my $pluginfo (@plugins) {
        my $name   = $pluginfo->{namespace};
        my @args   = LANraragi::Utils::Plugins::get_plugin_parameters($name);
        my $plugin = LANraragi::Utils::Plugins::get_plugin($name);
        my %plugin_result;

        my %pluginfo = $plugin->plugin_info();

        %plugin_result = exec_metadata_plugin( $plugin, $id, "", @args );

        if ( exists $plugin_result{error} ) {
            $failures++;
            $logger->error( $plugin_result{error} );
            next;
        }

        $successes++;

        #If the plugin exec returned metadata, add it
        set_tags( $id, $plugin_result{new_tags}, 1 );

        # Sum up all the added tags for later reporting.
        # This doesn't take into account tags that are added twice
        # (e.g by different plugins), but since this is more meant to show
        # if the plugins added any data at all it's fine.
        my @added_tags = split( ',', $plugin_result{new_tags} );
        $addedtags += @added_tags;

        if ( exists $plugin_result{title} ) {
            set_title( $id, $plugin_result{title} );

            $newtitle = $plugin_result{title};
            $logger->debug("Changing title to $newtitle. (Will do nothing if title is blank)");
        }

        if ( exists $plugin_result{summary} ) {
            set_summary( $id, $plugin_result{summary} );
            $logger->debug("Summary has been changed.");    # don't put the new summary in logs, it can be huge
        }
    }

    return ( $successes, $failures, $addedtags, $newtitle );
}

# Unlike the two other methods, exec_login_plugin takes a plugin name and does the Redis lookup itself.
# Might be worth consolidating this later.
sub exec_login_plugin {
    my $plugname = shift;
    my $ua       = Mojo::UserAgent->new;
    my $logger   = get_logger( "Plugin System", "lanraragi" );

    if ($plugname) {
        $logger->debug("Calling matching login plugin $plugname.");
        my $loginplugin = LANraragi::Utils::Plugins::get_plugin($plugname);
        my @loginargs   = LANraragi::Utils::Plugins::get_plugin_parameters($plugname);

        my $loggedinua = $loginplugin->do_login(@loginargs);

        if ( ref($loggedinua) eq "Mojo::UserAgent" ) {
            return $loggedinua;
        } else {
            $logger->error("Plugin did not return a Mojo::UserAgent object!");
        }

    } else {
        $logger->debug("No login plugin specified, returning empty UserAgent.");
    }

    return $ua;
}

sub exec_script_plugin {

    my ( $plugin, $input, @settings ) = @_;

    no warnings 'experimental::try';

    try {
        my %pluginfo = $plugin->plugin_info();
        my $ua       = exec_login_plugin( $pluginfo{login_from} );

        # Bundle all the potentially interesting info in a hash
        my %infohash = (
            user_agent    => $ua,
            oneshot_param => $input
        );

        # Scripts don't have any predefined metadata in their spec so they're just ran as-is.
        # They can return whatever the heck they want in their hash as well, they'll just be shown as-is in the API output.
        return $plugin->run_script( \%infohash, @settings );
    } catch ($e) {
        return ( error => $e );
    }
}

sub exec_download_plugin {

    my ( $plugin, $input, @settings ) = @_;
    my $logger = get_logger( "Plugin System", "lanraragi" );

    my %pluginfo = $plugin->plugin_info();
    my $ua       = exec_login_plugin( $pluginfo{login_from} );

    # Bundle all the potentially interesting info in a hash
    my %infohash = (
        user_agent => $ua,
        url        => $input
    );

    # Downloader plugins take an URL, and return...another URL, which we can download through the user-agent.
    my %result = $plugin->provide_url( \%infohash, @settings );

    if ( exists $result{error} ) {
        $logger->info( "Downloader plugin failed to provide an URL, aborting now. Error: " . $result{error} );
        return \%result;
    }

    if ( exists $result{download_url} ) {

        # Add the result URL to the infohash and return that.
        $infohash{download_url} = $result{download_url};
        return \%infohash;
    }

    return ( error => "Plugin ran to completion but didn't provide a final URL for us to download." );
}

# Execute a specified plugin on a file, described through its Redis ID.
sub exec_metadata_plugin {

    my ( $plugin, $id, $oneshotarg, @args ) = @_;

    no warnings 'experimental::try';

    my $logger = get_logger( "Plugin System", "lanraragi" );

    if ( !$id ) {
        return ( error => "Tried to call a metadata plugin without providing an id." );
    }

    my $redis = LANraragi::Model::Config->get_redis;
    my %hash  = $redis->hgetall($id);

    my ( $name, $title, $tags, $file, $thumbhash ) = @hash{qw(name title tags file thumbhash)};

    ( $_ = LANraragi::Utils::Database::redis_decode($_) ) for ( $name, $title, $tags );

    # If the thumbnail hash is empty or undefined, we'll generate it here.
    unless ( length $thumbhash ) {
        $logger->info("Thumbnail hash invalid, regenerating.");
        my $thumbdir = LANraragi::Model::Config->get_thumbdir;
        $thumbhash = "";

        try {
            extract_thumbnail( $thumbdir, $id, 0, 1 );
            $thumbhash = $redis->hget( $id, "thumbhash" );
            $thumbhash = LANraragi::Utils::Database::redis_decode($thumbhash);
        } catch ($e) {
            $logger->warn("Error building thumbnail: $e");
        }
    }
    $redis->quit();

    my %returnhash;
    try {
        # Hand it off to the plugin here.
        # If the plugin requires a login, execute that first to get a UserAgent
        my %pluginfo = $plugin->plugin_info();
        my $ua       = exec_login_plugin( $pluginfo{login_from} );

        # Bundle all the potentially interesting info in a hash
        my %infohash = (
            archive_id     => $id,
            archive_title  => $title,
            existing_tags  => $tags,
            thumbnail_hash => $thumbhash,
            file_path      => $file,
            user_agent     => $ua,
            oneshot_param  => $oneshotarg
        );

        my %newmetadata;

        %newmetadata = $plugin->get_tags( \%infohash, @args );

        # TODO: remove this block after changing all the metadata plugins
        #Error checking
        if ( exists $newmetadata{error} ) {

            #Return the hash as-is.
            #It already has an "error" key, which will be read by the client.
            #No need for more processing.
            return %newmetadata;
        }

        my @tagarray = split_tags_to_array( $newmetadata{tags} );
        my $newtags  = "";

        # Process new metadata.
        if ( LANraragi::Model::Config->enable_tagrules ) {
            $logger->info("Applying tag rules...");
            my @rules = LANraragi::Utils::Database::get_computed_tagrules();
            @tagarray = rewrite_tags( \@tagarray, \@rules );
        }

        foreach my $tagtoadd (@tagarray) {

            # Only proceed if the tag isn't already in redis
            unless ( index( uc($tags), uc($tagtoadd) ) != -1 ) {
                $newtags .= " $tagtoadd,";
            }
        }

        # Strip last comma and return processed tags in a hash
        chop($newtags);
        %returnhash = ( new_tags => $newtags );

        # Indicate a title change, if the plugin reports one
        if ( exists $newmetadata{title} && LANraragi::Model::Config->can_replacetitles ) {
            my $newtitle = $newmetadata{title};
            $newtitle = trim($newtitle);
            $returnhash{title} = $newtitle;
        }

        # Include updated summary data in response
        if ( exists $newmetadata{summary} ) {
            $returnhash{summary} = $newmetadata{summary};
        }

    } catch ($e) {
        return ( error => $e );
    }

    return %returnhash;
}

1;
