package LANraragi::Utils::RotatingLog;

use strict;
use warnings;
use utf8;

use Fcntl qw(:flock O_CREAT O_RDWR);
use Compress::Zlib;
use Config;

use Mojo::Base 'Mojo::Log';
use Mojo::File;

use constant IS_UNIX => ( $Config{osname} ne 'MSWin32' );

BEGIN {
    if ( !IS_UNIX ) {
        require Win32API::File;
    }
}

has 'logfile';
has 'tempdir';  # Where to store lockfiles
has 'lockpid';  # Track which PID opened the current lock file handle.

has counter => sub { 0 }; # number of logs emitted

# max number of archived logfiles to retain for log rotation (defaults to 7 files).
has retention_count => sub {
    my $count = 0 + ($ENV{LRR_LOGROTATE_FILES} // 7);
    die "retention_count must be positive" if $count < 1;
    return $count;
};

# max size of logfile (in bytes) before triggering rotation on next scan (defaults to 1 MB, min. 1kB).
has max_rotation_size => sub {
    my $size = 0 + ($ENV{LRR_LOGROTATE_SIZE} // 1048576);
    die "max_rotation_size must be greater than 1kb (1024)" if $size < 1024;
    return $size;
};

# Logfile lock path
has lockpath => sub {
    my $self        = shift;
    my $path        = $self->path;
    my $mf          = Mojo::File->new($path);
    my $base        = $mf->basename;
    my $lockpath    = $self->tempdir . "/$base.lock";
    return $lockpath;
};

# File handle for logger's lock file
has lockfh => sub {
    my $self = shift;
    my $lockpath = $self->lockpath;
    open( my $fh, '>>', $lockpath ) or die "Could not open lockfile '$lockpath': $!";
    $self->lockpid($$);
    return $fh;
};

# override: https://docs.mojolicious.org/Mojo/Log#handle
has handle => sub {
    my $self = shift;
    my $path = $self->path;
    my $fh;
    eval {
        $fh = get_handle($path);
        1;
    } or die "Could not open logfile '$path': $@";
    return $fh;
};

# https://perldoc.perl.org/perlobj#Destructors
# Clean everything up when logger is gone
sub DESTROY {
    my $self = shift;
    eval { close $self->lockfh } if defined $self->{lockfh};
    eval { close $self->handle } if defined $self->{handle};
}

# override: https://docs.mojolicious.org/Mojo/Log#append
# Includes logic which checks every 1k lines whether to rotate logs.
sub append {
    my ($self, $msg) = @_;

    $self->counter( $self->counter+1 );

    ensure_lock($self);
    my $path   = $self->path;
    my $lockfh = $self->lockfh;

    # Acquire shared lock to serialize with rotation EX lock.
    flock( $lockfh, LOCK_SH ) or die "Failed to acquire shared log lock: $!";

    my $ret;
    eval {
        # Refresh handle if inode changed due to rotation from another process
        refresh_logger_handle($self);

        # every 1k lines, check size of path for log rotation
        if ( $self->counter % 1000 == 0 ) {
            maybe_rotate($self);
        }

        $ret = $self->SUPER::append($msg);
    };
    my $error = $@;
    flock( $lockfh, LOCK_UN );
    die $error if $error;

    return $ret;
}

# override: https://docs.mojolicious.org/Mojo/Log#new
# Inherits Mojo::Log to provide guarded log rotation during `new` and `append`.
sub new {
    my $self = shift->SUPER::new(@_);

    ensure_lock($self);
    my $path    = $self->path;
    my $logfile = $self->logfile;

    my $lockfh  = $self->lockfh;
    maybe_rotate($self);

    # handle logpath existence cases.
    # case 1 (logfile DNE):     create new logfile under exclusive lock
    # case 2 (logfile exist):   no action needed, just get the logfile handle
    if ( !-e $path && flock( $lockfh, LOCK_EX | LOCK_NB ) ) {
        my $logfile_create_error;
        eval {
            # Re-check inside lock in case another process created the file
            $self->handle;
            1;
        };
        $logfile_create_error = $@;
        flock( $lockfh, LOCK_UN );
        die $logfile_create_error if $logfile_create_error;

    } else {
        eval {
            $self->handle;
            1;
        };

        my $logfile_exist_error = $@;
        die $logfile_exist_error if $logfile_exist_error;
    }

    return $self;
}

# Rotate logfiles if conditions met, otherwise do nothing.
sub maybe_rotate {
    my $self    = shift;
    my $path    = $self->path;
    my $lockfh  = $self->lockfh;

    ensure_lock($self);
    # Try to acquire a file lock between two rotation condition checks.
    if ( should_rotate($self, $path) ) {
        # unlock-then-lock to upgrade from shared to exclusive lock; 
        # "Converting a lock (shared to exclusive, or vice versa) is not guaranteed to be atomic"
        # - https://man7.org/linux/man-pages/man2/flock.2.html
        flock( $lockfh, LOCK_UN );
        if ( !flock( $lockfh, LOCK_EX | LOCK_NB ) ) {
            # Another process is rotating, skip rotation attempt
            # Re-acquire shared lock and continue
            flock( $lockfh, LOCK_SH ) or die "Failed to re-acquire shared log lock (1): $!";
            return;
        }

        my $rotation_error;
        if ( should_rotate($self, $path) ) {
            my $logfile = $self->logfile;
            eval {
                # rotate_under_lock( $self );
                rotate_files( $path, $self->retention_count );
                delete $self->{handle};
                $self->handle;
                1;
            } or do {
                my $lockpath = $self->lockpath;
                $rotation_error = "Failed to rotate logs during append-time under lock $lockpath: $@";
            };
            die $rotation_error if $rotation_error;
        }

        # Downgrade back to SH for the write
        flock( $lockfh, LOCK_UN );
        if ( $rotation_error ) {
            flock( $lockfh, LOCK_SH ) or die "Failed to re-acquire shared log lock (2): $!";
            die $rotation_error;
        }
        flock( $lockfh, LOCK_SH ) or die "Failed to re-acquire shared log lock (3): $!";
    }
}

sub should_rotate {
    my $self = shift;
    my $path = $self->path;
    return -e $path && -s $path > $self->max_rotation_size;
}

# Do logfile rotation.
sub rotate_files {
    my $logpath         = shift;
    my $retention_count = shift;

    # say "Rotating logpath $logpath";

    # Based on Logfile::Rotate
    # Rotate existing logs
    for ( my $i = $retention_count; $i > 1; $i-- ) {
        my $j = $i - 1;
        my $next = "$logpath.$i.gz";
        my $prev = "$logpath.$j.gz";
        if ( -r $prev && -f $prev ) {
            rename( $prev, $next ) or die "error: rename failed: ($prev,$next): $!";
        }
    }

    # Move current logs to tempfile to stop new writes to it
    my $tmp = "$logpath.rotate";
    unlink $tmp if -e $tmp;
    rename( $logpath, $tmp ) or die "error: could not detach $logpath to $tmp: $!";

    # Gzip the detached tempfile
    my $gz = gzopen( "$logpath.1.gz", "wb" ) or die "error: could not gzopen $logpath.1.gz: $!";
    open( my $handle, '<', $tmp ) or die "Couldn't open $tmp: $!";
    my $buffer;
    $gz->gzwrite($buffer) while read( $handle, $buffer, 4096 ) > 0;
    $gz->gzclose();
    close $handle;
    unlink $tmp or die "error: could not delete $tmp: $!";
}


# Refresh a logger's cached handle to prevent stale handles pointing to missing files.
sub refresh_logger_handle {
    my $logger = shift;

    if ( IS_UNIX ) {
        my $path            = $logger->path;
        my $cached_inode    = ( stat( $logger->handle ) )[1];
        my $path_inode      = ( stat( $path ) )[1];
        if ( !defined $cached_inode || !defined $path_inode || $cached_inode != $path_inode ) {
            close($logger->handle) if defined $logger->{handle};
            open( my $fh, '>>', $path ) or die "Could not open logfile '$path': $!";
            $logger->handle($fh);
        }
    } else {
        my $fh = get_win32_fh( $logger->path );
        eval { close $logger->handle } if defined $logger->{handle};
        $logger->handle($fh);
    }
}

# Ensure each process owns its lock file handle after a fork.
# If two workers have the same fd of a lock, then both of them can control the file.
# After a fork, children of a process inherit the same open file description, even if they belong
# to a different PID.
# "Locks created by flock() are associated with an open file description (see open(2))."
# - https://man7.org/linux/man-pages/man2/flock.2.html
sub ensure_lock {
    my $self = shift;
    if ( !defined $self->{lockfh} || !defined $self->{lockpid} || $self->{lockpid} != $$ ) {
        eval { close $self->{lockfh} } if defined $self->{lockfh};
        my $lockpath = $self->lockpath;
        open( my $fh, '>>', $lockpath ) or die "Could not open lockfile '$lockpath': $!";
        $self->lockfh($fh);
        $self->lockpid($$);
    }
}

sub get_handle {
    my $path = shift;
    # STDERR
    return \*STDERR unless $path;

    # File
    my $fh;
    if ( !IS_UNIX ) {
        $fh = get_win32_fh($path);
        return $fh if $fh;
    }

    # Fallback with default UTF-8 handle.
    $fh = Mojo::File->new($path)->open('>>');
    $fh->binmode(':encoding(UTF-8)');
    return $fh;
}

# Get perl file handler via Win32 native file handle of a logfile.
# https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilew
# https://perldoc.perl.org/Win32API::File#CreateFile
# https://perldoc.perl.org/Win32API::File#OsFHandleOpen
sub get_win32_fh {
    my $sPath    = shift;
    my $uAccess  = Win32API::File::FILE_APPEND_DATA();
    my $uShare   = Win32API::File::FILE_SHARE_READ()
        | Win32API::File::FILE_SHARE_WRITE()
        | Win32API::File::FILE_SHARE_DELETE();
    my $pSecAttr = [];
    my $uCreate  = Win32API::File::OPEN_ALWAYS();
    my $uFlags   = 0;
    my $hModel   = [];
    my $h = Win32API::File::CreateFile( $sPath, $uAccess, $uShare, $pSecAttr, $uCreate, $uFlags, $hModel )
        or die "CreateFile failed for $sPath; win32 says: $^E; errno: $!";

    local *FH;

    Win32API::File::OsFHandleOpen( *FH, $h, "w" ) or die "OsFHandleOpen failed for $sPath; $!";
    binmode *FH, ':encoding(UTF-8)';
    return *FH;
}

1;
