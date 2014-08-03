#!/usr/bin/perl
# example perl code, this may not actually run without tweaking, especially on Windows
# Taken from https://gist.github.com/eqhmcow/5389877.
# This code is licensed under the GNU General Public License 2.
 
use strict;
use warnings;

 
#IO::Uncompress::Unzip works great to process zip files; but, it doesn't include a routine to actually
#extract an entire zip file.
#Other modules like Archive::Zip include their own unzip routines, which aren't as robust as IO::Uncompress::Unzip;
#eg. they don't work on zip64 archive files.
#So, the following is code to actually use IO::Uncompress::Unzip to extract a zip file.

 
use File::Spec::Functions qw(splitpath);
use IO::File;
use IO::Uncompress::Unzip qw($UnzipError);
use File::Path qw(mkpath);
 
# example code to call unzip:
unzip(shift);
 
=head2 unzip
 
Extract a zip file, using IO::Uncompress::Unzip.
 
Arguments: file to extract, destination path
 
unzip('stuff.zip', '/tmp/unzipped');
 
=cut
 
sub unzip {
my ($file, $dest) = @_;
 
die 'Need a file argument' unless defined $file;
$dest = "." unless defined $dest;
 
my $u = IO::Uncompress::Unzip->new($file)
or die "Cannot open $file: $UnzipError";
 
my $status;
for ($status = 1; $status > 0; $status = $u->nextStream()) {
my $header = $u->getHeaderInfo();
my (undef, $path, $name) = splitpath($header->{Name});
my $destdir = "$dest/$path";
 
unless (-d $destdir) {
mkpath($destdir) or die "Couldn't mkdir $destdir: $!";
}
 
if ($name =~ m!/$!) {
last if $status < 0;
next;
}
 
my $destfile = "$dest/$path/$name";
my $buff;
my $fh = IO::File->new($destfile, "w")
or die "Couldn't write to $destfile: $!";
while (($status = $u->read($buff)) > 0) {
$fh->write($buff);
}
$fh->close();
my $stored_time = $header->{'Time'};
utime ($stored_time, $stored_time, $destfile)
or die "Couldn't touch $destfile: $!";
}
 
die "Error processing $file: $!\n"
if $status < 0 ;
 
return;
}
 
1;