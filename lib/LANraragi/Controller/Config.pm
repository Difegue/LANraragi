package LANraragi::Controller::Config;
use Mojo::Base 'Mojolicious::Controller';

use LANraragi::Model::Utils;
use LANraragi::Model::Config;

use Authen::Passphrase::BlowfishCrypt;

# Render the configuration page
sub index {

	$self->render(template => "templates/config.tmpl",
		            motd => &get_motd,
		            dirname => &get_userdir,
		            pagesize => &get_pagesize,
		            readorder => &get_readorder,
		            enablepass => &enable_pass,
		            password => &get_password,
		            blacklist => &get_tagblacklist,
		            title => &get_htmltitle,
		            cssdrop => &printCssDropdown(0)
			      );
}

# Save the given parameters to the Redis config
sub save_config {

	my $redis = &get_redis();

	my $success = 1;
	my $errormess = "";
	
	my %confhash = (
		htmltitle => scalar $self->param('htmltitle'),
		motd => scalar $self->param('motd'),
		dirname => scalar $self->param('dirname'),
		pagesize => scalar $self->param('pagesize'),
		blacklist => scalar $self->param('blacklist'),
		readorder => (scalar $self->param('readorder') ? '1' : '0'), #for checkboxes, we check if the parameter exists in the POST to return either 1 or 0.
		enablepass => (scalar $self->param('enablepass') ? '1' : '0'),
	);
	
	#only add newpassword field as password if enablepass = 1
	if ($self->param('enablepass'))
		{ 

			#hash password with authen
			my $password = $self->param('newpassword');
			my $ppr = Authen::Passphrase::BlowfishCrypt->new(
			    cost        => 8,
			    salt_random => 1,
			    passphrase  => $password,
			);

			my $pass_hashed = $ppr->as_rfc2307;
			$confhash{password} = $pass_hashed; 

		}


	#Verifications.
	if ($self->param('newpassword') ne $self->param('newpassword2')) #Password check
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
				removeSpaceF($confhash{$key}); 
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
