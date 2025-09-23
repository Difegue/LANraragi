package LANraragi::Utils::Path;

use strict;
use warnings;
use utf8;
use feature qw(say signatures);
no warnings 'experimental::signatures';

use Encode;
use Config;

use constant IS_UNIX => ( $Config{osname} ne 'MSWin32' );

use Exporter 'import';
our @EXPORT_OK = qw(create_path open_path date_modified compat_path unlink_path);

BEGIN {
    if ( !IS_UNIX ) {
        require Win32::LongPath;
        require Win32::LongPath::Path;
        require Win32::FileSystemHelper;
    }
}

sub create_path($file) {
    if ( IS_UNIX ) {
        return $file;
    } else {
        return Win32::LongPath::Path->new( $file );
    }
}

sub open_path {
    if ( IS_UNIX ) {
        return CORE::open( $_[0], $_[1], $_[2] );
    } else {
        return Win32::LongPath::openL( \$_[0], $_[1], decode_utf8( $_[2] ) );
    }
}

sub date_modified($file) {
    if ( IS_UNIX ) {
        return ( CORE::stat( $file) )[9]; #9 is the unix time stamp for date modified.
    } else {
        return Win32::LongPath::statL( decode_utf8( $file ) )->{mtime};
    }
}

sub compat_path($file) {
    if ( !IS_UNIX ) {
        if ( length($file) >= 260 ) {
            $file = Win32::FileSystemHelper::get_short_path($file);
        }
    }
    return $file;
}

sub unlink_path($file) {
    if ( IS_UNIX ) {
        return unlink $file;
    } else {
        return Win32::LongPath::unlinkL( decode_utf8( $file ) );
    }
}

1;
