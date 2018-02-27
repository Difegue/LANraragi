package LANraragi;

use local::lib;
use open ':std', ':encoding(UTF-8)';
use Mojo::Base 'Mojolicious';

use Mojo::IOLoop::ProcBackground;

use LANraragi::Model::Config;
use LANraragi::Model::Plugins;


# This method will run once at server start
sub startup {
  my $self = shift;

  # Load configuration from hash returned by "lrr.conf"
  my $config = $self->plugin('Config', {file => 'lrr.conf'});
  my $version = $config->{version};

  say "";
  say "";
  say "ｷﾀ━━━━━━(ﾟ∀ﾟ)━━━━━━!!!!!";

  $self->secrets($config->{secrets});
  $self->plugin('RenderFile');

  # Set Template::Toolkit as default renderer so we can use the LRR templates
  $self->plugin('TemplateToolkit');
  $self->renderer->default_handler('tt2');

  #Remove upload limit
  $self->max_request_size(0);

  #Helper so controllers can reach the app's Redis DB quickly (they still need to declare use Model::Config)
  $self->helper(LRR_CONF => sub { LANraragi::Model::Config:: });
  #Second helper to build logger objects quickly
  $self->helper(LRR_LOGGER => sub {return LANraragi::Model::Utils::get_logger("LANraragi","lanraragi")} );

  my $devmode =  $self->LRR_CONF->enable_devmode;

  if ($devmode) {
    $self->mode('development');
    $self->LRR_LOGGER->info("LANraragi $version (re-)started. (Debug Mode)");

    #Tell the mojo logger to print to stdout as well

    $self->log->on(message => sub {
      my ($time, $level, @lines) = @_;

      print "[Mojolicious] "; 
      print $lines[0];
      print "\n";
    });

  } else {
    $self->mode('production');
    $self->LRR_LOGGER->info("LANraragi $version started. (Production Mode)");
  }

  #Plugin listing
  my @plugins = LANraragi::Model::Plugins::plugins;
  foreach my $plugin (@plugins) {

    my %pluginfo = $plugin->plugin_info();
    my $name = $pluginfo{name};
    $self->LRR_LOGGER->info("Plugin Detected: ".$name);
  }

  #Check if a Redis server is running on the provided address/port
  $self->LRR_CONF->get_redis;

  #Delete the lockfile if we're not in devmode
  if (-e "./shinobu-lock" && $devmode == 0) {
    unlink("./shinobu-lock");
  }

  #Start Background worker if there's no lockfile present
  unless (-e "./shinobu-lock" && $devmode) {
    my $proc = $self->stash->{shinobu} = Mojo::IOLoop::ProcBackground->new;

    #Create lockfile to prevent spawn of other background processes
    open(FILE, ">shinobu-lock") || die("cannot open file: " . $!);
    close(FILE); 

    # When the process terminates, we get this event
    $proc->on(dead => sub {
        my ($proc) = @_;
        my $pid = $proc->proc->pid;
        $self->LRR_LOGGER->info("Shinobu Background Worker terminated. (PID was $pid)");

        #Delete lockfile
        unlink("./shinobu-lock");
    });

    $proc->run([$^X, "./lib/Shinobu.pm"]);

  } else { 
    $self->LRR_LOGGER->info("Lockfile present in debug mode - Background worker not respawned.");
    $self->LRR_LOGGER->warn("Delete the shinobu-lock file if you just started LANraragi.");
  }

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('index#index');
  $r->get('/index')->to('index#index');
  $r->get('/random')->to('index#random_archive');

  $r->get('/login')->to('login#index');
  $r->post('/login')->to('login#check');

  $r->get('/reader')->to('reader#index');

  $r->get('/api/thumbnail')->to('api#serve_thumbnail');
  $r->get('/api/servefile')->to('api#serve_file');

  $r->get('/stats')->to('stats#index');

  #Those routes are only accessible if user is logged in
  my $logged_in = $r->under('/')->to('login#logged_in');
  $logged_in->get('/config')->to('config#index');
  $logged_in->post('/config')->to('config#save_config');

  $logged_in->get('/config/plugins')->to('plugins#index');
  $logged_in->post('/config/plugins')->to('plugins#save_config');

  $logged_in->get('/edit')->to('edit#index');
  $logged_in->post('/edit')->to('edit#save_metadata');
  $logged_in->delete('/edit')->to('edit#delete_archive');

  $logged_in->get('/backup')->to('backup#index');
  $logged_in->post('/backup')->to('backup#restore');

  $logged_in->get('/upload')->to('upload#index');
  $logged_in->post('/upload')->to('upload#process_upload');

  $logged_in->post('/api/use_plugin')->to('api#use_plugin');
  $logged_in->post('/api/use_all_plugins')->to('api#use_enabled_plugins');
  $logged_in->get('/api/cleantemp')->to('api#clean_tempfolder');
  $logged_in->get('/api/discard_cache')->to('api#force_refresh');

  $logged_in->get('/logs')->to('logging#index');
  $logged_in->get('/logs/general')->to('logging#print_general');
  $logged_in->get('/logs/plugins')->to('logging#print_plugins');
  $logged_in->get('/logs/mojo')->to('logging#print_mojo');

  $r->get('/logout')->to('login#logout');

}

1;
