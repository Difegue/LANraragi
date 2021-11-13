use strict;
use warnings;
use utf8;
use Cwd;

use Mojo::Base 'Mojolicious';

use Test::More tests => 1;
use Test::Mojo;
use Test::MockObject;
use Mojo::JSON qw(decode_json encode_json);
use Data::Dumper;

use Template;
use Mojo::File;

use LANraragi::Model::Config;
use LANraragi::Model::Archive;

# Mock Redis
my $cwd     = getcwd;
my $SAMPLES = "$cwd/tests/samples";
require $cwd . "/tests/mocks.pl";
setup_redis_mock();

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

        $tt->process( $vars{template} . ".html.tt2", \%vars, \$output ) || die $tt->error(), "\n";
        return $output;
    }
);

my $expected_opds = ( Mojo::File->new("$SAMPLES/opds/opds_sample.xml")->slurp );

# Generate a new OPDS Catalog and compare it against our sample
my $opds_result = LANraragi::Model::Archive::generate_opds_catalog($mojo);
is( $opds_result, $expected_opds, "OPDS API Test" );
