use strict;
use warnings;
use utf8;
use Data::Dumper;

use Test::More;
use Test::Deep;

BEGIN { use_ok('LANraragi::Utils::String'); }

note('testing trim...');
{
    my $input    = "";
    my $expected = "";
    my $result   = LANraragi::Utils::String::trim($input);

    is( $result, $expected, "Empty string should result in empty string" );
}

{
    my $input    = "already trimmed";
    my $expected = "already trimmed";
    my $result   = LANraragi::Utils::String::trim($input);

    is( $result, $expected, "Pre-trimmed should do nothing" );
}

{
    my $input    = " trim everything   ";
    my $expected = "trim everything";
    my $result   = LANraragi::Utils::String::trim($input);

    is( $result, $expected,             "Trim should trim" );
    is( $input,  " trim everything   ", "Trim doesn't modify the input variable" );
}

note('testing title cleanup...');
{
    my $input    = "(C83) [Tetsubou Shounen (Natsushi)] So hold my hand one more time [English] [Yuri-ism Project]";
    my $expected = "So hold my hand one more time";
    my $result   = LANraragi::Utils::String::clean_title($input);

    is( $result, $expected, "Remove leading/trailing junk" );
}

note('testing string similarity detection...');
{
    is( LANraragi::Utils::String::most_similar( "orange", ( "door hinge", "sporange" ) ), 1,     "Simple case" );
    is( LANraragi::Utils::String::most_similar( "orange", () ),                           undef, "Empty set" );
}

note('testing trim_crlf...');
{
    is( LANraragi::Utils::String::trim_CRLF( undef ), undef, "Undef should return undef");
    is( LANraragi::Utils::String::trim_CRLF( "a\nb" ), "ab", "newline should go bye");
}

done_testing();

