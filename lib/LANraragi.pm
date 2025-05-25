package LANraragi;

use local::lib;

use open ':std', ':encoding(UTF-8)';

use Mojo::Base 'Mojolicious';
use Mojo::File;
use Mojo::JSON qw(decode_json encode_json);
use Storable;
use Sys::Hostname;
use Config;

use LANraragi::Utils::Generic    qw(start_shinobu start_minion);
use LANraragi::Utils::Logging    qw(get_logger get_logdir);
use LANraragi::Utils::Plugins    qw(get_plugins);
use LANraragi::Utils::TempFolder qw(get_temp);
use LANraragi::Utils::Routing;
use LANraragi::Utils::Minion;
use LANraragi::Utils::I18N;
use LANraragi::Utils::I18NInitializer;

use LANraragi::Model::Search;
use LANraragi::Model::Config;

# This method will run once at server start
sub startup {
    my $self = shift;

    say "";
    say "";
    say "ｷﾀ━━━━━━(ﾟ∀ﾟ)━━━━━━!!!!!";

    # Load package.json to get version/vername/description
    my $packagejson = decode_json( Mojo::File->new('package.json')->slurp );

    my $version = $packagejson->{version};
    my $vername = $packagejson->{version_name};
    my $descstr = $packagejson->{description};

    my $secret          = "";
    my $secretfile_path = get_temp . "/oshino";
    if ( -e $secretfile_path ) {
        $secret = Mojo::File->new($secretfile_path)->slurp;
    } else {

        # Generate a random string as the secret and store it in a file
        $secret .= sprintf( "%x", rand 16 ) for 1 .. 8;
        Mojo::File->new($secretfile_path)->spew($secret);
    }

    # Use the hostname alongside the random secret
    $self->secrets( [ $secret . hostname() ] );
    $self->plugin('RenderFile');

    # Set Template::Toolkit as default renderer so we can use the LRR templates
    $self->plugin('TemplateToolkit');
    $self->renderer->default_handler('tt2');

    #Remove upload limit
    $self->max_request_size(0);

    #Helper so controllers can reach the app's Redis DB quickly
    #(they still need to declare use Model::Config)
    $self->helper( LRR_CONF    => sub { LANraragi::Model::Config:: } );
    $self->helper( LRR_VERSION => sub { return $version; } );
    $self->helper( LRR_VERNAME => sub { return $vername; } );
    $self->helper( LRR_DESC    => sub { return $descstr; } );

    #Helper to build logger objects quickly
    $self->helper(
        LRR_LOGGER => sub {
            return get_logger( "LANraragi", "lanraragi" );
        }
    );

    # for some reason I can't call the one under LRR_CONF from the
    # templates, so create a separate helper here
    my $prefix = $self->LRR_CONF->get_baseurl();
    $self->helper( LRR_BASEURL => sub { return $prefix } );

    #Check if a Redis server is running on the provided address/port
    eval { $self->LRR_CONF->get_redis->ping(); };
    if ($@) {
        say "(╯・_>・）╯︵ ┻━┻";
        say "It appears your Redis database is currently not running.";
        say "The program will cease functioning now.";
        die;
    }

    # Catch Redis errors on our first connection. This is useful in case of temporary LOADING errors,
    # Where Redis lets us send commands but doesn't necessarily reply to them properly.
    # (https://github.com/redis/redis/issues/4624)
    while (1) {
        eval { $self->LRR_CONF->get_redis->keys('*') };

        last unless ($@);

        say "Redis error encountered: $@";
        say "Trying again in 2 seconds...";
        sleep 2;
    }

    # Initialize cache
    LANraragi::Utils::PageCache::initialize();

    # Load i18n
    LANraragi::Utils::I18NInitializer::initialize($self);

    # Check old settings and migrate them if needed
    if ( $self->LRR_CONF->get_redis->keys('LRR_*') ) {
        say "Migrating old settings to new format...";
        migrate_old_settings($self);
    }

    if ( $self->LRR_CONF->enable_devmode ) {
        $self->mode('development');
        $self->LRR_LOGGER->info("LANraragi $version (re-)started. (Debug Mode)");

        my $logpath = get_logdir . "/mojo.log";

        #Tell the mojo logger to log to file
        $self->log->on(
            message => sub {
                my ( $time, $level, @lines ) = @_;

                open( my $fh, '>>', $logpath )
                  or die "Could not open file '$logpath' $!";

                my $l1 = $lines[0] // "";
                my $l2 = $lines[1] // "";
                print $fh "[Mojolicious] $l1 $l2 \n";
                close $fh;
            }
        );

    } else {
        $self->mode('production');
        $self->LRR_LOGGER->info("LANraragi $version started. (Production Mode)");
    }

    #Plugin listing
    my @plugins = get_plugins("metadata");
    foreach my $pluginfo (@plugins) {
        my $name = $pluginfo->{name};
        $self->LRR_LOGGER->info( "Plugin Detected: " . $name );
    }

    @plugins = get_plugins("script");
    foreach my $pluginfo (@plugins) {
        my $name = $pluginfo->{name};
        $self->LRR_LOGGER->info( "Script Detected: " . $name );
    }

    @plugins = get_plugins("download");
    foreach my $pluginfo (@plugins) {
        my $name = $pluginfo->{name};
        $self->LRR_LOGGER->info( "Downloader Detected: " . $name );
    }

    # Enable Minion capabilities in the app
    if ( $Config{osname} ne 'MSWin32') {
        shutdown_from_pid( get_temp . "/minion.pid" );
    }

    my $miniondb      = $self->LRR_CONF->get_redisad . "/" . $self->LRR_CONF->get_miniondb;
    my $redispassword = $self->LRR_CONF->get_redispassword;

    # If the password is non-empty, add the required delimiters
    if ($redispassword) { $redispassword = "x:" . $redispassword . "@"; }

    say "Minion will use the Redis database at $miniondb";
    $self->plugin( 'Minion' => { Redis => "redis://$redispassword$miniondb" } );
    $self->LRR_LOGGER->info("Successfully connected to Minion database.");
    $self->minion->missing_after(5);    # Clean up older workers after 5 seconds of unavailability

    LANraragi::Utils::Minion::add_tasks( $self->minion );
    $self->LRR_LOGGER->debug("Registered tasks with Minion.");

    # Rebuild stat hashes
    # /!\ Enqueuing tasks must be done either before starting the worker, or once the IOLoop is started!
    # Anything else can cause weird database lockups.
    $self->minion->enqueue('build_stat_hashes');

    # Start a Minion worker in a subprocess
    if ( $Config{osname} ne 'MSWin32') {
        start_minion($self);
    } else {
        # my $numcpus = Sys::CpuAffinity::getNumCpus();
        # for my $num ( 1 .. $numcpus ) {
        #     start_minion($self);
        # }
        start_minion($self);
    }

    # Start File Watcher
    if ( $Config{osname} ne 'MSWin32') {
        shutdown_from_pid( get_temp . "/shinobu.pid" );
    }
    start_shinobu($self);

    # Check if this is a first-time installation.
    LANraragi::Model::Config::first_install_actions();

    # Hook to SIGTERM to cleanly kill minion+shinobu on server shutdown
    # As this is executed during before_dispatch, this code won't work if you SIGTERM without loading a single page!
    # (https://stackoverflow.com/questions/60814220/how-to-manage-myself-sigint-and-sigterm-signals)
    $self->hook(
        before_dispatch => sub {
            my $c = shift;
            if ( $Config{osname} ne 'MSWin32') {
                state $unused = add_sigint_handler();
            }

            my $prefix = $self->LRR_BASEURL;
            if ($prefix) {
                if ( !$prefix =~ m|^/[^"]*[^/"]$| ) {
                    say "Warning: configured URL prefix '$prefix' invalid, ignoring";

                    # if prefix is invalid, then set it to empty for the cookie
                    $prefix = "";
                } else {
                    $c->req->url->base->path($prefix);
                }
            }

            # SameSite=Lax is the default behavior here; I set it
            # explicitly to get rid of a warning in the browser
            $c->cookie( "lrr_baseurl" => $prefix, { samesite => "lax" } );
        }
    );

    LANraragi::Utils::Routing::apply_routes($self);
    $self->LRR_LOGGER->info("Routing done! Ready to receive requests.");
}

sub shutdown_from_pid {
    my $file = shift;

    if ( -e $file && eval { retrieve($file); } ) {

        # Deserialize process
        my $oldproc = ${ retrieve($file) };
        my $pid     = $oldproc->pid;

        say "Killing process $pid from $file";
        $oldproc->kill();
        unlink($file);
    }
}

sub add_sigint_handler {
    my $old_int = $SIG{INT};
    $SIG{INT} = sub {
        shutdown_from_pid( get_temp . "/shinobu.pid" );
        shutdown_from_pid( get_temp . "/minion.pid" );

        \&$old_int;    # Calling the old handler to cleanly exit the server
    }
}

sub migrate_old_settings {
    my $self = shift;

    # Grab all LRR_* keys from LRR_CONF->get_redis and move them to the config DB
    my $redis     = $self->LRR_CONF->get_redis;
    my $config_db = $self->LRR_CONF->get_configdb;
    my @keys      = $redis->keys('LRR_*');

    foreach my $key (@keys) {
        say "Migrating $key to database $config_db";
        $redis->move( $key, $config_db );
    }

}

1;
