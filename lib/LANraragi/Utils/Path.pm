package LANraragi::Utils::Path;

use strict;
use warnings;
use utf8;
use feature qw(say signatures);
no warnings 'experimental::signatures';

use Encode;
use Config;
use File::Find;
use POSIX qw(strerror);

use constant IS_UNIX => ( $Config{osname} ne 'MSWin32' );

use Exporter 'import';
our @EXPORT_OK = qw(create_path create_path_or_die open_path open_path_or_die date_modified compat_path unlink_path find_path);

BEGIN {
    if ( !IS_UNIX ) {
        require Win32::LongPath;
        require Win32::LongPath::Path;
        require Win32::LongPath::Find;
        require Win32::FileSystemHelper;
    }
}

sub create_path( $file ) {
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

sub open_path_or_die {
    my $file = $_[2];
    return 1 if open_path( $_[0], $_[1], $file );
    die "Failed to open $file: " . _file_error_msg($file);
}

sub date_modified( $file ) {
    if ( IS_UNIX ) {
        return ( CORE::stat( $file) )[9]; #9 is the unix time stamp for date modified.
    } else {
        return Win32::LongPath::statL( decode_utf8( $file ) )->{mtime};
    }
}

sub compat_path( $file ) {
    if ( !IS_UNIX ) {
        if ( length($file) >= 260 ) {
            $file = Win32::FileSystemHelper::get_short_path( $file );
        }
    }
    return $file;
}

sub unlink_path( $file ) {
    if ( IS_UNIX ) {
        return unlink $file;
    } else {
        return Win32::LongPath::unlinkL( decode_utf8( $file ) );
    }
}

sub find_path( $wanted, $path ) {
    if ( IS_UNIX ) {
        find(
            {   wanted => $wanted,
                no_chdir    => 1,
                follow_fast => 1
            },
            $path
        );
    } else {
        my @files = Win32::LongPath::Find::find( decode_utf8( Win32::FileSystemHelper::get_full_path( $path ) ) );
        foreach my $file (@files) {
            $_ = encode_utf8( $file );
            { $wanted->(); };
        }
    }
}

# Build the error message for a failed file operation containing details about the file's properties
# including any hidden Windows-side errors.
# Usage: die "Failed operation for $file: " . _file_error_msg($file);
sub _file_error_msg {
    my ( $file ) = @_;

    my $errno_num       = 0 + $!;
    my $errno_str       = strerror($errno_num);
    my $winerr_num;
    my $winerr_str;

    if ( !IS_UNIX ) {
        # This fetches the value of GetLastError() on Win32 as per perldoc: https://perldoc.perl.org/variables/$%5EE
        $winerr_num     = 0 + $^E;
        $winerr_str     = "$^E";
    }

    my $exists          = -e $file ? 'yes' : 'no';
    my $readable        = -r $file ? 'yes' : 'no';
    my $size            = -e $file ? (-s _) : 'NA';

    my $err = "(exists:$exists; readable:$readable; size:$size) (errno $errno_num: $errno_str)";

    if ( !IS_UNIX ) {
        $err .= " (win32 errno $winerr_num: $winerr_str)";
    }

    return $err;
}

1;
