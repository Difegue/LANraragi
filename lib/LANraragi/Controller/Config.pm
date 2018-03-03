package LANraragi::Controller::Config;
use Mojo::Base 'Mojolicious::Controller';

use Encode;

use LANraragi::Model::Utils;
use LANraragi::Model::Config;

use Authen::Passphrase::BlowfishCrypt;

# Render the configuration page
sub index {

	my $self = shift;
	my $size = 0;
	find(sub { $size += -s if -f }, "./public/temp");

	$self->render(template => "config",
		            motd => $self->LRR_CONF->get_motd,
		            dirname => $self->LRR_CONF->get_userdir,
		            pagesize => $self->LRR_CONF->get_pagesize,
		            readorder => $self->LRR_CONF->get_readorder,
		            enablepass => $self->LRR_CONF->enable_pass,
		            password => $self->LRR_CONF->get_password,
		            blacklist => $self->LRR_CONF->get_tagblacklist,
		            title => $self->LRR_CONF->get_htmltitle,
		            tempmaxsize => $self->LRR_CONF->get_tempmaxsize,
		            autotag => $self->LRR_CONF->enable_autotag,
		            devmode => $self->LRR_CONF->enable_devmode,
		            cssdrop => LANraragi::Model::Utils::generate_themes,
		            tempsize => int($size/1048576*100)/100
			      );
}

# Save the given parameters to the Redis config
sub save_config {

	my $self = shift;
	my $redis = $self->LRR_CONF->get_redis();

	my $success = 1;
	my $errormess = "";
	
	my %confhash = (
		htmltitle => scalar $self->req->param('htmltitle'),
		motd => scalar $self->req->param('motd'),
		dirname => scalar $self->req->param('dirname'),
		pagesize => scalar $self->req->param('pagesize'),
		blacklist => scalar $self->req->param('blacklist'),
		readorder => (scalar $self->req->param('readorder') ? '1' : '0'), #for checkboxes, we check if the parameter exists in the POST to return either 1 or 0.
		enablepass => (scalar $self->req->param('enablepass') ? '1' : '0'),
		autotag => (scalar $self->req->param('autotag') ? '1' : '0'),
		devmode => (scalar $self->req->param('devmode') ? '1' : '0'),
		tempmaxsize => scalar $self->req->param('tempmaxsize')
	);
	
	#only add newpassword field as password if enablepass = 1
	if ($self->req->param('enablepass'))
		{ 

			#hash password with authen
			my $password = $self->req->param('newpassword');

			if ($password ne "") {
				my $ppr = Authen::Passphrase::BlowfishCrypt->new(
				    cost        => 8,
				    salt_random => 1,
				    passphrase  => $password,
				);

				my $pass_hashed = $ppr->as_rfc2307;
				$confhash{password} = $pass_hashed; 
			}
		}


	#Verifications.
	if ($self->req->param('newpassword') ne $self->req->param('newpassword2')) #Password check
		{ 
			$success = 0;
		 	$errormess = "Mismatched passwords.";
		}

	if ($confhash{pagesize} =~ /\D+/ ) #Numbers only in fields w. numbers
		{
			$success = 0;
			$errormess = "Invalid characters.";
		}

	#Did all the checks pass ?
	if ($success)
	{
		#clean up the user's inputs for non-toggle options and encode for redis insertion
		foreach my $key (keys %confhash) 
			{ 
				LANraragi::Model::Utils::remove_spaces($confhash{$key}); 
				encode_utf8($confhash{$key});
			}

		#for all keys of the hash, add them to the redis config hash with the matching keys.
		$redis->hset("LRR_CONFIG", $_, $confhash{$_}, sub {}) for keys %confhash;
		$redis->wait_all_responses;
	}

	$self->render(json => {
					operation => "config", 
					success => $success, 
					message => $errormess
					});

}

1;
