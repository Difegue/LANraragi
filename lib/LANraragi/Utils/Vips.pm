package LANraragi::Utils::Vips;


use v5.36;

use strict;
use warnings;

use FFI::Platypus;
use FFI::Platypus::Buffer qw( buffer_to_scalar );
use FFI::CheckLib qw( find_lib );

our $VIPS_LOADED = 0;
my @vips_libs = find_lib( lib => [ 'vips', 'vips-42' ] );
my $lib_path;

if (@vips_libs) {
    $VIPS_LOADED = 1;
    $lib_path = $vips_libs[0];
} else {
    warn "Could not find libvips. Some functions will not be available.\n";
    $lib_path = undef;
}

# Class-level FFI object
our $FFI_HANDLE = FFI::Platypus->new(
    api => 1,
    lib => $lib_path,
);


# Define custom types
$FFI_HANDLE->type('opaque' => 'VipsImage');
$FFI_HANDLE->type('opaque' => 'GObject');

if ($VIPS_LOADED) {
    # Attach libvips functions
    $FFI_HANDLE->attach( vips_init => ['string'] => 'int' );
    $FFI_HANDLE->attach( vips_error_buffer => [] => 'string' );
    $FFI_HANDLE->attach( vips_error_clear => [] => 'void' );
    $FFI_HANDLE->attach( vips_image_new_from_file => ['string', 'opaque'] => 'VipsImage' );
    $FFI_HANDLE->attach( vips_resize => ['VipsImage', 'VipsImage*', 'double', 'opaque'] => 'int' );
    $FFI_HANDLE->attach( vips_jpegsave => ['VipsImage', 'string', 'opaque'] => 'int' );
    $FFI_HANDLE->attach( vips_image_write_to_buffer => ['VipsImage', 'string', 'opaque*', 'size_t*', 'string', 'int', 'opaque'] => 'int' );
    $FFI_HANDLE->attach( g_object_unref => ['GObject'] => 'void' );
    $FFI_HANDLE->attach( g_free => ['opaque'] => 'void' );
    $FFI_HANDLE->attach( vips_image_new_from_buffer => ['string', 'size_t', 'string', 'opaque'] => 'VipsImage' );
    $FFI_HANDLE->attach( vips_image_get_width => ['VipsImage'] => 'int' );
    $FFI_HANDLE->attach( vips_image_get_height => ['VipsImage'] => 'int' );
    $FFI_HANDLE->attach( vips_image_get_bands => ['VipsImage'] => 'int' );
    $FFI_HANDLE->attach( vips_black => ['VipsImage*', 'int', 'int', 'opaque'] => 'int' );
    $FFI_HANDLE->attach( vips_crop => ['VipsImage', 'VipsImage*', 'int', 'int', 'int', 'int', 'opaque'] => 'int' );
    $FFI_HANDLE->attach( vips_colourspace => ['VipsImage', 'VipsImage*', 'int', 'opaque'] => 'int' );
    $FFI_HANDLE->attach( vips_insert => ['VipsImage', 'VipsImage', 'VipsImage*', 'int', 'int', 'opaque'] => 'int' );
    $FFI_HANDLE->attach( vips_pngsave => ['VipsImage', 'string', 'opaque'] => 'int' );
    $FFI_HANDLE->attach( vips_thumbnail_buffer => ['string', 'uint64', 'VipsImage*', 'int', 'string', 'int', 'string', 'int', 'opaque'] => 'int' );
} else {
    # Dummy functions if libvips is not loaded
    *vips_init = sub { die "libvips is not loaded. Cannot call vips_init." };
    *vips_error_buffer = sub { die "libvips is not loaded. Cannot call vips_error_buffer." };
    *vips_error_clear = sub { die "libvips is not loaded. Cannot call vips_error_clear." };
    *vips_image_new_from_file = sub { die "libvips is not loaded. Cannot call vips_image_new_from_file." };
    *vips_jpegsave = sub { die "libvips is not loaded. Cannot call vips_jpegsave." };
    *vips_image_write_to_buffer = sub { die "libvips is not loaded. Cannot call vips_image_write_to_buffer." };
    *g_object_unref = sub { die "libvips is not loaded. Cannot call g_object_unref." };
    *g_free = sub { die "libvips is not loaded. Cannot call g_free." };
    *vips_image_new_from_buffer = sub { die "libvips is not loaded. Cannot call vips_image_new_from_buffer." };
    *vips_image_get_width = sub { die "libvips is not loaded. Cannot call vips_image_get_width." };
    *vips_image_get_height = sub { die "libvips is not loaded. Cannot call vips_image_get_height." };
    *vips_image_get_bands = sub { die "libvips is not loaded. Cannot call vips_image_get_bands." };
    *vips_black = sub { die "libvips is not loaded. Cannot call vips_black." };
    *vips_crop = sub { die "libvips is not loaded. Cannot call vips_crop." };
    *vips_colourspace = sub { die "libvips is not loaded. Cannot call vips_colourspace." };
    *vips_insert = sub { die "libvips is not loaded. Cannot call vips_insert." };
    *vips_pngsave = sub { die "libvips is not loaded. Cannot call vips_pngsave." };
    *vips_thumbnail_buffer_plain = sub { die "libvips is not loaded. Cannot call vips_thumbnail_buffer_plain." };
    *vips_thumbnail_buffer = sub { die "libvips is not loaded. Cannot call vips_thumbnail_buffer." };
}

# Define VipsInterpretation enum values
use constant VIPS_INTERPRETATION_GREY16 => 12; # VIPS_INTERPRETATION_GREY16
use constant VIPS_INTERPRETATION_B_W => 17; # VIPS_INTERPRETATION_B_W
use constant VIPS_SIZE_FORCE => 3; # VIPS_SIZE_FORCE
use constant VIPS_ALIGN_CENTRE => 0; # VIPS_ALIGN_CENTRE
use constant VIPS_INTERESTING_CENTRE => 1;

my $initialized = 0;



sub init ($program_name) {
    if (!$VIPS_LOADED) {
        warn "libvips is not loaded. Cannot initialize Vips.\n";
        return 0; # Indicate failure
    }
    if (!$initialized) {
        my $ret = vips_init($program_name);
        if ($ret != 0) {
            my $error = error_buffer();
            clear_error();
            die "Error initializing libvips: $error";
        }
        $initialized = 1;
    }
    return 1;
}

sub error_buffer () {
    return vips_error_buffer();
}

sub clear_error () {
    vips_error_clear();
}

sub new_from_file ($filename) {
    my $image = vips_image_new_from_file($filename, undef);
    if (!$image) {
        my $error = error_buffer();
        clear_error();
        die "Error creating image from file: $error";
    }
    return $image;
}

sub new_from_buffer ($buffer) {
    my $image = vips_image_new_from_buffer($buffer, length($buffer), "", undef);
    if (!$image) {
        my $error = error_buffer();
        clear_error();
        die "Error creating image from buffer: $error";
    }
    return $image;
}

sub width ($image) {
    return vips_image_get_width($image);
}

sub height ($image) {
    return vips_image_get_height($image);
}

sub bands ($image) {
    return vips_image_get_bands($image);
}

sub black ($width, $height) {
    my $out;
    my $ret = vips_black(\$out, $width, $height, undef);
    if ($ret != 0) {
        my $error = error_buffer();
        clear_error();
        die "Error creating black image: $error";
    }
    return $out;
}

# Resize the image in $buffer, ignoring aspect ratio
sub stretch_resize($buffer, $target_width, $target_height) {
    my $out;
    my $stretchRet = vips_thumbnail_buffer($buffer, length($buffer), \$out, $target_width, "height", int($target_height), "size", VIPS_SIZE_FORCE, undef);
    if ($stretchRet != 0) {
        my $error = error_buffer();
        clear_error();
        die "Error stretching image: $error";
    }
    return $out;
}

# Resize the image in $buffer, respecting aspect ratio and not cropping
sub fit_resize($buffer, $target_width, $target_height) {
    my $out;
    my $fitRet = vips_thumbnail_buffer($buffer, length($buffer), \$out, $target_width, "height", int($target_height), undef);
    if ($fitRet != 0) {
        my $error = error_buffer();
        clear_error();
        die "Error resizing image for fit: $error";
    }
    return $out;
}

# Resize the image, respecting aspect ratio and cropping if needed (focus on center)
sub cover_resize($buffer, $target_width, $target_height) {
    my $out;
    my $func = $FFI_HANDLE->function( 'vips_thumbnail_buffer' => ['string', 'uint64', 'VipsImage*', 'int', 'string', 'int', 'string', 'int', 'opaque'] => 'int' );

    my $ret = $func->call($buffer, length($buffer), \$out, $target_width, 'height', $target_height, 'crop', VIPS_INTERESTING_CENTRE, undef);
    if ($ret != 0) {
        my $error = error_buffer();
        clear_error();
        die "Error resizing image to width: $error";
    }
    return $out;
}

# Resize the image, respecting aspect ratio
sub resize_to_width($buffer, $target_width) {
    my $out;
    my $func = $FFI_HANDLE->function( 'vips_thumbnail_buffer' => ['string', 'uint64', 'VipsImage*', 'int', 'opaque'] => 'int' );

    my $ret = $func->call($buffer, length($buffer), \$out, $target_width, undef);
    if ($ret != 0) {
        my $error = error_buffer();
        clear_error();
        die "Error resizing image to width: $error";
    }
    return $out;
}

sub crop ($image, $left, $top, $width, $height) {
    my $out;
    my $ret = vips_crop($image, \$out, $left, $top, $width, $height, undef);
    if ($ret != 0) {
        my $error = error_buffer();
        clear_error();
        die "Error cropping image: $error";
    }
    return $out;
}

sub grayscale ($image) {
    my $out;
    my $ret = vips_colourspace($image, \$out, VIPS_INTERPRETATION_GREY16, undef);
    if ($ret != 0) {
        my $error = error_buffer();
        clear_error();
        die "Error converting to grayscale: $error";
    }
    return $out;
}

sub jpegsave ($image, $filename) {
    my $c_filename = "$filename\0";
    my $ret = vips_jpegsave($image, $c_filename, undef);
    if ($ret != 0) {
        my $error = error_buffer();
        clear_error();
        die "Error saving JPEG: $error";
    }
    return 1;
}

sub pngsave ($image, $filename) {
    my $c_filename = "$filename\0";
    my $ret = vips_pngsave($image, $c_filename, undef);
    if ($ret != 0) {
        my $error = error_buffer();
        clear_error();
        die "Error saving PNG: $error";
    }
    return 1;
}

sub write_to_buffer ($image, $format, $quality) {
    my $buf;
    my $len;
    my $ret;
    $ret = vips_image_write_to_buffer($image, $format, \$buf, \$len, "Q", $quality, undef);
    if ($ret == 0) {
        my $image_data = buffer_to_scalar($buf, $len);
        g_free($buf);
        return $image_data;
    } else {
        my $error = error_buffer();
        clear_error();
        die "Error writing to buffer: $error";
    }
}

sub unref_image ($image) {
    if (defined $image) {
        g_object_unref($image);
    }
}

sub is_vips_loaded () {
    return $VIPS_LOADED;
}

1;
