package LANraragi;

use local::lib;
use open ':std', ':encoding(UTF-8)';
use Mojo::Base 'Mojolicious';

use LANraragi::Model::Config;
use LANraragi::Model::Plugins;


# This method will run once at server start
sub startup {
  my $self = shift;

  say "";
  say "";
  say "ｷﾀ━━━━━━(ﾟ∀ﾟ)━━━━━━!!!!!";
  say "LANraragi (re-)started.";
  say "";

  # Load configuration from hash returned by "lrr.conf"
  my $config = $self->plugin('Config', {file => 'lrr.conf'});

  #Helper so controllers can reach the app's Redis DB quickly (they still need to declare use Model::Config)
  $self->helper(LRR_CONF => sub { LANraragi::Model::Config:: });

  #Plugin listing
  my @plugins = LANraragi::Model::Plugins::plugins;
  foreach my $plugin (@plugins) {

    my %pluginfo = $plugin->plugin_info();
    my $name = $pluginfo{name};
    say "Plugin Loaded: ".$name;
  }

  #Check if a Redis server is running on the provided address/port
  $self->LRR_CONF->get_redis;

  $self->secrets($config->{secrets});

  $self->plugin('RenderFile');

  # Set Template::Toolkit as default renderer so we can use the LRR templates
  $self->plugin('TemplateToolkit');
  $self->renderer->default_handler('tt2');

  #Remove upload limit
  $self->max_request_size(0);

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('index#index');
  $r->get('/index')->to('index#index');
  $r->get('/random')->to('index#random_archive');

  $r->get('/login')->to('login#index');
  $r->post('/login')->to('login#check');

  $r->get('/reader')->to('reader#index');

  $r->post('/api/add_archive')->to('api#add_archive');
  $r->get('/api/thumbnail')->to('api#generate_thumbnail');
  $r->get('/api/servefile')->to('api#serve_file');

  $r->get('/stats')->to('stats#index');

  #Those routes are only accessible if user is logged in
  my $logged_in = $r->under('/')->to('login#logged_in');
  $logged_in->get('/config')->to('config#index');
  $logged_in->post('/config')->to('config#save_config');

  $logged_in->get('/edit')->to('edit#index');
  $logged_in->post('/edit')->to('edit#save_metadata');
  $logged_in->delete('/edit')->to('edit#delete_archive');

  $logged_in->get('/backup')->to('backup#index');
  $logged_in->post('/backup')->to('backup#restore');

  #$logged_in->get('/tags')->to('tags#index');
  #$logged_in->post('/tags')->to('tags#process_archive');

  $logged_in->get('/upload')->to('upload#index');
  $logged_in->post('/upload')->to('upload#process_upload');

  $logged_in->post('/api/tags')->to('api#fetch_tags');
  $logged_in->get('/api/cleantemp')->to('api#clean_tempfolder');

  $r->get('/logout')->to('login#logout');

}

1;
