use strict;
use warnings;
use utf8;
use Cwd;

use Mojo::Base 'Mojolicious';

use Test::More;
use Test::Mojo;
use Test::MockObject;
use Data::Dumper;

use Template;
use Mojo::File;

use LANraragi::Model::Config;
use LANraragi::Model::Opds;
use LANraragi::Model::Stats;

# Mock Redis
my $cwd     = getcwd;
my $SAMPLES = "$cwd/tests/samples";
require $cwd . "/tests/mocks.pl";
setup_redis_mock();

# Build search hashes
LANraragi::Model::Stats::build_stat_hashes();

# Mock basic mojo stuff used by the opds call
my $mojo = Test::MockObject->new();
$mojo->mock( 'LRR_CONF',    sub { LANraragi::Model::Config:: } );
$mojo->mock( 'LRR_VERSION', sub { return "9.9.9" } );
$mojo->mock( 'LRR_VERNAME', sub { return "I Can't Give Everything Away" } );
$mojo->mock(
    'req',
    sub {
        return Test::MockObject->new()->mock( 'param', sub { return "" } );
    }
);
$mojo->mock(
    'render_to_string',
    sub {
        shift;
        my %vars = @_;

        #print Dumper \%vars;

        # Use the OG Template::Toolkit here since we don't instantiate mojo
        my $tt = Template->new( { INCLUDE_PATH => $cwd . "/templates" } ) || die "$Template::ERROR\n";
        my $output;

        # this mocks the Mojo url_for helper function, which is now
        # used in the templates
        $vars{c} = {
            url_for => sub { return $_[0]; }
        };
        $tt->process( $vars{template} . ".html.tt2", \%vars, \$output ) || die $tt->error(), "\n";
        return $output;
    }
);

my $expected_opds = ( Mojo::File->new("$SAMPLES/opds/opds_sample.xml")->slurp );

# Generate a new OPDS Catalog and compare it against our sample
my $opds_result = LANraragi::Model::Opds::generate_opds_catalog($mojo);

# Compare without whitespace
$opds_result =~ s/\s//g;
$expected_opds =~ s/\s//g;
is( $opds_result, $expected_opds, "OPDS API Test" );

done_testing();
