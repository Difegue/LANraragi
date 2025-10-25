package LANraragi::Utils::Redis;

use v5.36;

use strict;
use warnings;
use utf8;

use Encode qw(decode_utf8 encode_utf8);
use Unicode::Normalize qw(NFC);

# Don't import anything from LANraragi here, this is used by Config and thus cycles are likely


use Exporter 'import';
our @EXPORT_OK = qw(redis_encode redis_decode);

# Normalize the string to Unicode NFC, then layer on redis_encode for Redis-safe serialization.
sub redis_encode ($data) {

    my $NFC_data = NFC($data);
    return encode_utf8($NFC_data);
}

# Final Solution to the Unicode glitches -- Eval'd double-decode for data obtained from Redis.
# This should be a one size fits-all function.
sub redis_decode ($data) {

    # Setting FB_CROAK tells encode to die instantly if it encounters any errors.
    # Without this setting, it typically tries to replace characters... which might already be valid UTF8!
    eval { $data = decode_utf8( $data, Encode::FB_CROAK ) };

    # Do another UTF-8 decode just in case the data was double-encoded
    eval { $data = decode_utf8( $data, Encode::FB_CROAK ) };

    return $data;
}

1;
