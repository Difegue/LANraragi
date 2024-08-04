package LANraragi::Utils::Constants;

use strict;
use warnings;
use utf8;
no warnings 'experimental';

use Exporter 'import';
our @EXPORT_OK = qw(%TANK_METADATA);


our %TANK_METADATA = (
        "name", 0,
        "summary", -1,
        "thumbhash", -2,
        "tags", -3,
        "alias", -4
    );

1;