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

  # Set Template::Toolkit as default renderer so we can use the LRR templates
  $self->plugin('TemplateToolkit');
  $self->renderer->default_handler('tt2');

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('example#welcome');

  $r->get('/login')->to('login#render');
  $r->post('/login')->to('login#check');

  #Config routes, only if user is logged in
  my $logged_in = $r->under('/config')->to('login#logged_in');
  $logged_in->get('/config')->to('config#render_config');
  $logged_in->post('/config')->to('config#save_config');

  $r->get('/logout')->to('login#logout');

}

1;
