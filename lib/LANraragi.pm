package LANraragi;

use local::lib;

use open ':std', ':encoding(UTF-8)';

use Mojo::Base 'Mojolicious';
use Mojo::File;
use Mojo::JSON qw(decode_json encode_json);
use Storable;

use LANraragi::Utils::Generic;
use LANraragi::Utils::Plugins;
use LANraragi::Utils::Logging qw(get_logger);

use LANraragi::Model::Config;
use LANraragi::Model::Search;

# This method will run once at server start
sub startup {
    my $self = shift;

    say "";
    say "";
    say "ｷﾀ━━━━━━(ﾟ∀ﾟ)━━━━━━!!!!!";

    # Load configuration from hash returned by "lrr.conf"
    my $config = $self->plugin( 'Config', { file => 'lrr.conf' } );

    # Load package.json to get version/vername
    my $packagejson = decode_json(Mojo::File->new('package.json')->slurp);
    
    my $version = $packagejson->{version};
    my $vername = $packagejson->{version_name};

    $self->secrets( $config->{secrets} );
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
        exit;
    }

    my $devmode = $self->LRR_CONF->enable_devmode;

    if ($devmode) {
        $self->mode('development');
        $self->LRR_LOGGER->info(
            "LANraragi $version (re-)started. (Debug Mode)");

        #Tell the mojo logger to print to stdout as well
        $self->log->on(
            message => sub {
                my ( $time, $level, @lines ) = @_;

                print "[Mojolicious] ";
                print $lines[0];
                print "\n";
            }
        );
    }
    else {
        $self->mode('production');
        $self->LRR_LOGGER->info(
            "LANraragi $version started. (Production Mode)");
    }

    #Plugin listing
    my @plugins = LANraragi::Utils::Plugins::get_plugins("metadata");
    foreach my $pluginfo (@plugins) {
        my $name = $pluginfo->{name};
        $self->LRR_LOGGER->info( "Plugin Detected: " . $name );
    }

    #Start Background worker
    if ( -e "./.shinobu-pid" && eval { retrieve("./.shinobu-pid"); }) {

        # Deserialize process
        my $proc = ${retrieve("./.shinobu-pid")};
        my $pid  = $proc->pid;

        $self->LRR_LOGGER->info(
            "Terminating previous Shinobu Worker if it exists... (PID is $pid)"
        );
        $proc->kill();  
    }

    my $proc = LANraragi::Utils::Generic::start_shinobu();
    $self->LRR_LOGGER->debug(
        "Shinobu Worker new PID is " . $proc->pid );

    LANraragi::Utils::Routing::apply_routes($self);
    $self->LRR_LOGGER->info("Routing done! Ready to receive requests.");

    # Warm search cache
    $self->LRR_LOGGER->info("Warming up search cache...");
    LANraragi::Model::Search::do_search("","",0,"title","asc", 0, 0);
    $self->LRR_LOGGER->info("Done!");
}

1;
