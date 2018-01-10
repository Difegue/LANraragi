package LANraragi::Controller::Config;
use Mojo::Base 'Mojolicious::Controller';

use LANraragi::Model::Utils;

#Functions for reading the configuration settings off the database... 
#And a few extra things I didn't port to the DB because nearly no-one is going to modify those anyway. 
use Switch;
use Redis;
use Encode;
use File::Basename;
use Redis;
use Authen::Passphrase::BlowfishCrypt;

my $self = shift;
my $config = $self->plugin('Config');

#Address and port of your redis instance.
sub get_redisad { return $config->{redis_address} };

#Database that'll be used by LANraragi. Redis databases are numbered, default is 0.
sub get_redisdb { return $config->{redis_database} };

#Default CSS file to load.
sub get_style { return $config->{default_theme} };


#getRedisConnection
#Create a redis object with the parameters defined at the start of this file and return it
sub getRedisConnection
 {
 	#Default redis server location is localhost:6379. 
	#Auto-reconnect on, one attempt every 100ms up to 2 seconds. Die after that.
 	my $redis = Redis->new(server => &get_redisad, 
						reconnect => 100,
						every     => 3000);

 	#Database switch if it's not 0
 	if (&get_redisdb != 0)
 		{ $redis -> select(&get_redisdb); }

 	return $redis;
 }


#getRedisParameter(parameter, default)
#Gets a parameter from the Redis database. If it doesn't exist, we return the default given as a second parameter.
sub getRedisParameter
 {
	my $param = $_[0]; 
	my $default = $_[1];

	my $redis = Redis->new(server => &get_redisad, 
							reconnect => 100,
							every     => 3000);

	if ($redis->hexists("LRR_CONFIG",$param)) 
		{ 
			my $value = decode_utf8($redis->hget("LRR_CONFIG",$param));

			unless ($value =~ /^\s*$/ ) #failsafe against blank config values
				{ return $value; }
		}
	
	return $default; 
 }

#Functions that return the config variables stored in Redis, or default values if they don't exist. Descriptions for each one of these can be found in the web configuration page.
sub get_htmltitle { return encode('utf-8',&getRedisParameter("htmltitle", "LANraragi")) }; #enforcing unicode to make sure it doesn't fuck up the templates by appearing in some other encoding
sub get_motd { return encode('utf-8',&getRedisParameter("motd", "Welcome to this Library running LANraragi !")) };
sub get_dirname  { return &getRedisParameter("dirname", "./content") };
sub get_pagesize { return &getRedisParameter("pagesize", "100") };
sub get_readorder { return &getRedisParameter("readorder", "0") };
sub enable_pass { return &getRedisParameter("enablepass", "1") };
sub get_password { return &getRedisParameter("password", '{CRYPT}$2a$08$4AcMwwkGXnWtFTOLuw/hduQlRdqWQIBzX3UuKn.M1qTFX5R4CALxy') }; #bcrypt hash for "kamimamita"
sub get_tagblacklist { return &getRedisParameter("blacklist", "already uploaded, translated, english, russian, chinese, portuguese, french") };


# Render the configuration page
sub render {

	$self->render(template => "templates/config.tmpl",
		            motd => &get_motd,
		            dirname => &get_dirname,
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

	my $redis = &getRedisConnection();

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
