package LANraragi::Controller::Stats;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Encode;

use LANraragi::Model::Utils;
use LANraragi::Model::Config;

# This action will render a template
sub index {
  	my $self = shift;

	my $t; 
	my @tags;
	my %tagcloud;

	#Login to Redis and get all hashes
	my $redis = &getRedisConnection();

	#64-character long keys only => Archive IDs 
	my @keys = $redis->keys( '????????????????????????????????????????????????????????????????' ); 
	my $archivecount = scalar @keys;

	#Iterate on hashes to get their tags
	foreach my $id (@keys)
	{
		if ($redis->hexists($id,"tags")) 
			{
				$t = $redis->hget($id,"tags");
				$t = decode_utf8($t);
				
				#Split tags by comma
				@tags = split(/,\s?/, $t);

				foreach my $t (@tags) {

				  #Just in case
				  &removeSpaceF($t);

				  #Increment value of tag if it's already in the result hash, create it otherwise
				  if (exists($tagcloud{$t}))
				  	{ $tagcloud{$t}++; }
				  else
				  	{ $tagcloud{$t} = 1;}

				}

			}
	}

	#When we're done going through tags, go through the tagCloud hash and build a JSON
	my $tagsjson = "[";

	@tags = keys %tagcloud;
	my $tagcount = scalar @tags;

	for my $t (@tags) {

		$tagsjson .= "{text: '$t', weight: ".$tagcloud{$t}."},";
	}

	$tagsjson.="]";

	#Get size of archive folder 
	my $dirname = &get_userdir;
	my $size = 0;

	for my $filename (glob("$dirname/*")) {
	    next unless -f $filename;
	    $size += -s _;
	}

	$size = int($size/1073741824*100)/100;

	$self->render(template => "templates/stats.tmpl",
			        title => &get_htmltitle,
			        cssdrop => &printCssDropdown(0),
			        tagcloud => $tagsjson,
			        tagcount => $tagcount,
			        archivecount => $archivecount,
			        arcsize => $size
			        );
}

1;
