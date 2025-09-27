package LANraragi::Utils::ImageMagickResizer;

use v5.36;
use experimental 'try';

use strict;
use warnings;
use utf8;

use LANraragi::Utils::Logging qw(get_logger);

sub new {
    my $class = shift;

    my $self = {
        logger => get_logger("ImageMagick", "lanraragi"),
    };

    return bless $self, $class;
}

sub resize_page($self, $content, $quality, $format) {
    my $img = undef;

    no warnings 'experimental::try';

    $self->{logger}->trace("ImageMagick resize_page");

    try {
        require Image::Magick;
        $img = Image::Magick->new;

        # For JPEG, the size option (or jpeg:size option) provides a hint to the JPEG decoder
        # that it can reduce the size on-the-fly during decoding. This saves memory because
        # it never has to allocate memory for the full-sized image
        $img->Set( option => 'jpeg:size=1064x' );

        $img->BlobToImage($content);

        my ( $origw, $origh ) = $img->Get( 'width', 'height' );
        if ( $origw > 1064 ) {
            $img->Resize( geometry => '1064x' );
        }

        # Set format to jpeg and quality
        return $img->ImageToBlob(magick => $format, quality => $quality);
    } catch ($e) {

        # Magick is unavailable, do nothing
        $self->{logger}->debug("ImageMagick is not available , skipping image resizing: $e");
    }
}

sub resize_thumbnail($self, $content, $quality, $use_hq, $format) {

    $self->{logger}->trace("ImageMagick resize_thumbnail");

    no warnings 'experimental::try';
    my $img = undef;
    try {
        require Image::Magick;
        $img = Image::Magick->new;

        # For JPEG, the size option (or jpeg:size option) provides a hint to the JPEG decoder
        # that it can reduce the size on-the-fly during decoding. This saves memory because
        # it never has to allocate memory for the full-sized image
        if ( $format eq 'jpg' ) {
            $img->Set( option => 'jpeg:size=500x' );
        }

        $img->BlobToImage($content);

        # Only use the first frame (relevant for animated gif/webp/whatever)
        $img = $img->[0];

        # The "-scale" resize operator is a simplified, faster form of the resize command.
        if ($use_hq) {
            $img->Scale( geometry => '500x1000' );
        } else {    # Sample is very fast due to not applying filters.
            $img->Sample( geometry => '500x1000' );
        }

        # Set format to jpeg and quality
        return $img->ImageToBlob(magick => $format, quality => $quality);
    } catch ($e) {

        # Magick is unavailable, do nothing
        $self->{logger}->debug("ImageMagick is not available , skipping image resizing: $e");
    } finally {
        if (defined($img)) {
            undef $img;
        }
    }
}

1;
