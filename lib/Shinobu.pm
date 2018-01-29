package Shinobu;

use strict;
use warnings;
use utf8;
use feature qw(say);

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../lib"; }
use Mojolicious;
use LANraragi::Model::Config;

sub run_worker_loop {

	my $interval = LANraragi::Model::Config::get_interval;

	say ("Shinobu Background Worker started -- Running every $interval seconds.");

	while (1) {

		my $test = LANraragi::Model::Config::get_redisad;
		say ("Redis Address is $test");



		sleep($interval);
	}

}

__PACKAGE__->run_worker_loop unless caller;

1;