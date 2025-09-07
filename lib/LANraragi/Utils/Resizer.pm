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

sub get_resizer() {
    state $resizer = resizer_factory();
    return $resizer;
}

sub resizer_factory
{
    my $logger = get_logger("Reader", "lanraragi");
    $logger->debug("Initializing resizer");

    if (LANraragi::Utils::Vips::is_vips_loaded) {
        return LANraragi::Utils::VipsResizer->new;
    }
    return LANraragi::Utils::ImageMagickResizer->new;
}

1;
