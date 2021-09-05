package LANraragi;

use local::lib;

use open ':std', ':encoding(UTF-8)';

use Mojo::Base 'Mojolicious';
use Mojo::File;
use Mojo::JSON qw(decode_json encode_json);
use Storable;
use Sys::Hostname;
use Config;

use LANraragi::Utils::Generic qw(start_shinobu start_minion);
use LANraragi::Utils::Logging qw(get_logger);
use LANraragi::Utils::Plugins qw(get_plugins);
use LANraragi::Utils::Database qw(invalidate_cache);
use LANraragi::Utils::TempFolder qw(get_temp);
use LANraragi::Utils::Routing;
use LANraragi::Utils::Minion;

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

    # Use the hostname and osname for a sorta-unique set of secrets.
    $self->secrets( [ hostname(), $Config{"osname"}, 'oshino' ] );
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

    #Check if a Redis server is running on the provided address/port
    eval { $self->LRR_CONF->get_redis->ping(); };
    if ($@) {
        say "(╯・_>・）╯︵ ┻━┻";
        say "It appears your Redis database is currently not running.";
        say "The program will cease functioning now.";
        die;
    }

    my $devmode;

    # Catch Redis errors on our first connection. This is useful in case of temporary LOADING errors,
    # Where Redis lets us send commands but doesn't necessarily reply to them properly.
    # (https://github.com/redis/redis/issues/4624)
    while (1) {
        eval { $devmode = $self->LRR_CONF->enable_devmode; };

        last unless ($@);

        say "Redis error encountered: $@";
        say "Trying again in 2 seconds...";
        sleep 2;
    }

    # Enable AOF saving on the Redis server.
    # This allows us to start creating an aof file using existing RDB snapshot data.
    # Later LRR releases will then be able to set appendonly directly in redis.conf without fearing data loss.
    say "Enabling AOF on Redis... This might take a while.";
    $self->LRR_CONF->get_redis->config_set( "appendonly", "yes" );

    if ($devmode) {
        $self->mode('development');
        $self->LRR_LOGGER->info("LANraragi $version (re-)started. (Debug Mode)");

        #Tell the mojo logger to print to stdout as well
        $self->log->on(
            message => sub {
                my ( $time, $level, @lines ) = @_;

                print "[Mojolicious] ";
                print $lines[0];
                print "\n";
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
    shutdown_from_pid( get_temp . "/minion.pid" );

    my $miniondb = $self->LRR_CONF->get_redisad . "/" . $self->LRR_CONF->get_miniondb;
    say "Minion will use the Redis database at $miniondb";
    $self->plugin( 'Minion' => { Redis => "redis://$miniondb" } );
    $self->LRR_LOGGER->info("Successfully connected to Minion database.");
    $self->minion->missing_after(5);    # Clean up older workers after 5 seconds of unavailability

    LANraragi::Utils::Minion::add_tasks( $self->minion );
    $self->LRR_LOGGER->debug("Registered tasks with Minion.");

    # Warm search cache
    # /!\ Enqueuing tasks must be done either before starting the worker, or once the IOLoop is started!
    # Anything else can cause weird database lockups.
    $self->minion->enqueue('warm_cache');
    $self->minion->enqueue('build_stat_hashes');

    # Start a Minion worker in a subprocess
    start_minion($self);

    # Start File Watcher
    shutdown_from_pid( get_temp . "/shinobu.pid" );
    start_shinobu($self);

    # Hook to SIGTERM to cleanly kill minion+shinobu on server shutdown
    # As this is executed during before_dispatch, this code won't work if you SIGTERM without loading a single page!
    # (https://stackoverflow.com/questions/60814220/how-to-manage-myself-sigint-and-sigterm-signals)
    $self->hook(
        before_dispatch => sub {
            state $unused = add_sigint_handler();
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

1;
