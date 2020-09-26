package LANraragi::Model::Upload;

use strict;
use warnings;
use utf8;

use Redis;
use File::Basename;
use File::Find qw(find);
use File::Copy qw(move);
use Encode;

use LANraragi::Utils::Database qw(invalidate_cache compute_id);
use LANraragi::Utils::Logging qw(get_logger);

use LANraragi::Model::Config;
use LANraragi::Model::Plugins;

# Handle files uploaded by the user, or downloaded from remote endpoints.

# Process a file. Argument is the filepath, preferably in a temp directory,
# as we'll copy it to the content folder and delete the original at the end.
# Also does autoplugin if enabled.
#
# Returns a status value and message.
sub handle_incoming_file {

    my $tempfile = shift;
    my ( $filename, $dirs, $suffix ) = fileparse( $tempfile, qr/\.[^.]*/ );
    $filename = $filename . $suffix;
    my $logger = get_logger( "File Upload/Download", "lanraragi" );

    # Compute an ID here
    my $id = compute_id($tempfile);
    $logger->debug("ID of uploaded file is $id");

    # Future home of the file
    my $userdir     = LANraragi::Model::Config->get_userdir;
    my $output_file = $userdir . '/' . $filename;

    #Check if the ID is already in the database, and
    #that the file it references still exists on the filesystem
    my $redis  = LANraragi::Model::Config->get_redis();
    my $isdupe = $redis->exists($id) && -e $redis->hget( $id, "file" );

    # Stop here if file is a dupe.
    if ( -e $output_file || $isdupe ) {

        # Trash temporary file
        unlink $tempfile;

        # The file already exists
        my $msg =
          $isdupe
          ? "This file already exists in the Library."
          : "A file with the same name is present in the Library.";

        return ( 0, $id, $msg );
    }

    # Add the file to the database ourselves so Shinobu doesn't do it
    # This allows autoplugin to be ran ASAP.
    LANraragi::Utils::Database::add_archive_to_redis( $id, $output_file, $redis );
    $redis->quit();

    # Invalidate search cache ourselves, Shinobu won't do it since the file is already in the database
    invalidate_cache();

    # Move the file to the content folder.
    # Move to a .tmp first in case copy to the content folder takes a while...
    move( $tempfile, $output_file . ".upload" );

    # Then rename inside the content folder itself to proc Shinobu.
    move( $output_file . ".upload", $output_file );

    unless ( -e $output_file ) {
        return ( 0, $id, "The file couldn't be moved to your content folder!" );
    }

    if ( LANraragi::Model::Config->enable_autotag ) {
        $logger->debug("Running autoplugin on newly upload file $id...");
        my ( $succ, $fail, $addedtags ) = LANraragi::Model::Plugins::exec_enabled_plugins_on_file($id);
        return ( 1, $id, "$succ Plugins used successfully, $fail Plugins failed, $addedtags tags added." );
    }

    return ( 1, $id, "File added successfully!" );
}

# Download the given URL, using the given Mojo::UserAgent object.
# This downloads the URL to a temporaryfolder and returns the full path to the downloaded file.
sub download_url {

    my ( $ua, $url ) = shift;
    my $logger = get_logger( "File Upload/Download", "lanraragi" );

    # Download to a temp folder
    $logger->info("Downloading URL $url...This will take some time.");

    my $tempdir      = tempdir();
    my $tx           = $ua->max_redirects(5)->get($url);
    my $content_disp = $tx->result->headers->content_disposition;
    my $filename     = "placeholder.zip";                           #placeholder;

    $logger->debug("Content-Disposition Header: $content_disp");
    if ( $content_disp =~ /.*filename=\"(.*)\".*/gim ) {
        $filename = $1;
    }

    $logger->debug("Filename: $filename");
    $tx->result->save_to("$tempdir\/$filename");

    # Update $tempfile to the exact reference created by the host filesystem
    # This is done by finding the first (and only) file in $tempdir.
    my $tempfile = "";
    find(
        sub {
            return if -d $_;
            $tempfile = $File::Find::name;
            $filename = $_;
        },
        $tempdir
    );

    return "$tempdir\/$filename";
}

1;
