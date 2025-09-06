package LANraragi::Utils::VipsResizer;

use v5.36;

use strict;
use warnings;
use utf8;

use LANraragi::Utils::Vips qw(new_from_buffer init);
use LANraragi::Utils::Logging qw(get_logger);

sub new {
    my $class = shift;

    my $self = {
        logger => get_logger("VIPS", "lanraragi"),
    };
    LANraragi::Utils::Vips::init("LANraragi");

    return bless $self, $class;
}

sub resize_page($self, $content, $quality, $format) {
    $self->{logger}->trace("Resizing page");
    my $img = LANraragi::Utils::Vips::resize_to_width($content, 1064);

    # Set format to jpeg and quality
    return LANraragi::Utils::Vips::write_to_buffer($img, ".$format", $quality);
}

sub resize_thumbnail($self, $content, $quality, $use_hq, $format) {
    $self->{logger}->trace("VIPS: Resizing page");
    my $img = LANraragi::Utils::Vips::fit_resize($content, 500, 1000);

    return LANraragi::Utils::Vips::write_to_buffer($img, ".$format", $quality);
}


1;
