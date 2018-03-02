package LANraragi::Controller::Plugins;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Encode;

use LANraragi::Model::Utils;
use LANraragi::Model::Config;
use LANraragi::Model::Plugins;

# This action will render a template
sub index {

	my $self = shift;
	my $redis = $self->LRR_CONF->get_redis;

	#Build plugin listing 
	my @plugins = LANraragi::Model::Plugins::plugins;

	#Plugin list is an array of hashes
	my @pluginlist = ();

	foreach my $plugin (@plugins) {

	    my %pluginfo = $plugin->plugin_info();

	    my $namespace = $pluginfo{namespace};
        my $namerds = "LRR_PLUGIN_".uc($namespace);

        my $checked = $redis->hget($namerds,"enabled");
        my $arg = $redis->hget($namerds,"customarg"); 

        $pluginfo{enabled} = $checked;
        $pluginfo{customarg} = $arg;

		push @pluginlist, \%pluginfo;

	}

	$redis->quit();

	$self->render(template => "plugins",
		            title => $self->LRR_CONF->get_htmltitle,
		            plugins => \@pluginlist,
		            cssdrop => LANraragi::Model::Utils::generate_themes
		            );

}

sub save_config {

	my $self = shift;
	my $redis = $self->LRR_CONF->get_redis;

	#For every existing plugin, check if we received a matching parameter, and update its settings.
	my @plugins = LANraragi::Model::Plugins::plugins;

	#Plugin list is an array of hashes
	my @pluginlist = ();
	my $success = 1;
	my $errormess = "";

	eval {
		foreach my $plugin (@plugins) {

		    my %pluginfo = $plugin->plugin_info();
		    my $namespace = $pluginfo{namespace};
	        my $namerds = "LRR_PLUGIN_".uc($namespace);

		    my $enabled = (scalar $self->req->param($namespace) ? '1' : '0');
		    my $arg = $self->req->param($namespace."_CFG");

		    $redis->hset($namerds,"enabled", $enabled);

		    $redis->hset($namerds,"customarg", $arg);

		}
	};

	if ($@) {
		$success = 0;
		$errormess = $@;
	}

	$self->render(json => {
					operation => "plugins", 
					success => $success, 
					message => $errormess
					});
}


1;