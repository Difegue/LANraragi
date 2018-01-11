package LANraragi;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Load configuration from hash returned by "my_app.conf"
  plugin Config => {file => 'lrr.conf'};
  my $config = $self->plugin('Config');

  $self->secrets($config->{secrets});

  # Documentation browser under "/perldoc"
  $self->plugin('PODRenderer') if $config->{perldoc};

  #Config model has access to $app so it can use the Config plugin
  $app->plugin('Model', {namespaces => ['LANraragi::Model::Config']});

  # Set Template::Toolkit as default renderer so we can use the LRR templates
  $self->plugin('TemplateToolkit');
  $self->renderer->default_handler('tt2');

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('index#render');
  $r->get('/random')->to('index#random_archive');

  $r->get('/login')->to('login#render');
  $r->post('/login')->to('login#check');

  $r->get('/reader')->to('reader#render');

  $r->get('/api/thumbnail')->to('api#generate_thumbnail');


  $r->get('/stats')->to('stats#render');

  #Those routes are only accessible if user is logged in
  my $logged_in = $r->under('/config')->to('login#logged_in');
  $logged_in->get('/config')->to('config#render');
  $logged_in->post('/config')->to('config#save_config');

  $logged_in->get('/edit')->to('edit#render');
  $logged_in->post('/edit')->to('edit#save_metadata');
  $logged_in->delete('/edit')->to('edit#delete_archive');

  $logged_in->get('/backup')->to('backup#render');
  $logged_in->post('/backup')->to('backup#restore');

  $logged_in->get('/tags')->to('tags#render');
  $logged_in->post('/tags')->to('tags#process_archive');

  $logged_in->get('/upload')->to('upload#render');
  $logged_in->post('/upload')->to('upload#process_upload');

  $logged_in->get('/api/add_archive')->to('api#add_archive');
  $logged_in->get('/api/tags')->to('api#fetch_tags');

  $r->get('/logout')->to('login#logout');

}

1;
