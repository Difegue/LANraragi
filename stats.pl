#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use Redis;
use Encode;
use Template;

require 'functions/functions_config.pl';
require 'functions/functions_generic.pl';

my $qstats = new CGI;
my $tt  = Template->new({
        INCLUDE_PATH => "templates",
        #ENCODING => 'utf8' 
    });


my $t; 
my @tags;
my %tagcloud;

#Login to Redis and get all hashes
my $redis = Redis->new(server => &get_redisad, 
						reconnect => 100,
						every     => 3000);

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
my $dirname = &get_dirname;
my $size = 0;

for my $filename (glob("$dirname/*")) {
    next unless -f $filename;
    $size += -s _;
}

$size = int($size/1073741824*100)/100;

#Regular HTML printout
print $qstats->header(-type    => 'text/html',
           	-charset => 'utf-8');

my $out;

$tt->process(
    "stats.tmpl",
    {
        title => &get_htmltitle,
        cssdrop => &printCssDropdown(0),
        tagcloud => $tagsjson,
        tagcount => $tagcount,
        archivecount => $archivecount,
        arcsize => $size
    },
    \$out,
) or die $tt->error;

print $out;

