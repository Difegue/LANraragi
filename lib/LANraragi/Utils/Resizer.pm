package LANraragi::Utils::Resizer;

use v5.36;

use strict;
use warnings;
use utf8;

use LANraragi::Utils::ImageMagickResizer;
use LANraragi::Utils::VipsResizer;
use LANraragi::Utils::Logging qw(get_logger);

use Exporter 'import';
our @EXPORT_OK = qw(get_resizer);

our $resizer = undef;

sub get_resizer
{
    if (defined $resizer) {
        return $resizer;
    }

    my $logger = get_logger("Reader", "lanraragi");
    $logger->info("Initializing resizer");

    if (LANraragi::Utils::Vips::is_vips_loaded) {
        return LANraragi::Utils::VipsResizer->new;
    }
    return LANraragi::Utils::ImageMagickResizer->new;
}

1;
