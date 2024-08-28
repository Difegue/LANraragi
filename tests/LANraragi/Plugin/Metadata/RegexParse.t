use strict;
use warnings;
use utf8;

use Cwd qw( getcwd );

use Test::More;

my $cwd     = getcwd();
require "$cwd/tests/mocks.pl";

use_ok('LANraragi::Plugin::Metadata::RegexParse');

note("testing basic example");
{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::RegexParse::get_plugin_logger        = sub { return get_logger_mock(); };

    my %get_tags_params = ( file_path => "/poopoo/peepee/(Release) [Artist] TITLE (Series) [Language].arj" );

    my %response = LANraragi::Plugin::Metadata::RegexParse::get_tags( "", \%get_tags_params );
    is( $response{title}, "TITLE",  "Title was misparsed" );
    is( $response{tags},  "event:Release, artist:Artist, series:Series, language:Language", "Wrong tags received" );
}

done_testing();