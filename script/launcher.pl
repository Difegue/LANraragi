#!/usr/bin/perl

use strict;
use warnings;
use Cwd;

use Mojo::Base -strict;
use Mojo::Server::Morbo;
use Mojo::Server::Hypnotoad;
use Mojo::Util qw(extract_usage getopt);

getopt
  'm|morbo'      => \my $morbo,
  'f|foreground' => \$ENV{HYPNOTOAD_FOREGROUND},
  'h|help'       => \my $help,
  'v|verbose'    => \$ENV{MORBO_VERBOSE};

die extract_usage if $help || !(my $app = shift || $ENV{HYPNOTOAD_APP});

my @listen;
if ($ENV{LRR_NETWORK}) {
    @listen = [$ENV{LRR_NETWORK}];
} else {
    @listen = ["http://*:3000"];
}

my $backend;
if ($morbo) {
    $backend = Mojo::Server::Morbo->new;
    $ENV{MOJO_MODE} = "development";
    $backend->daemon->listen(@listen);
} else {
    $backend = Mojo::Server::Hypnotoad->new;
    $backend->prefork->listen(@listen);
}

$backend->run($app);
exit;

=encoding utf8

=head1 NAME

LRR launcher using either morbo or hypnotoad. Morbo always starts in dev mode.
To change the listen port, use the LRR_NETWORK environment variable.

=head1 SYNOPSIS

  Usage: perl launcher.pl [OPTIONS] lanraragi

  Options:
    -m, --morbo        Use morbo instead of hypnotoad
    -f, --foreground   Keep manager process in foreground (hypnotoad)
    -v, --verbose      Print details about what files changed to
                       STDOUT (morbo)
    -h, --help         Show this message

=head1 DESCRIPTION

Start L<Mojolicious> and L<Mojolicious::Lite> applications with the
L<Hypnotoad|Mojo::Server::Hypnotoad> web server.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<https://mojolicious.org>.

=cut