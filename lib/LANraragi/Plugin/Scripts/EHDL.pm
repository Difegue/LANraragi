package LANraragi::Plugin::Scripts::EHDL;

use strict;
use warnings;
no warnings 'uninitialized';

use Mojo::UserAgent;
use File::Temp qw/ tempfile tempdir /;
use File::Copy;
use File::Find;
use File::Basename;

use LANraragi::Utils::Logging qw(get_logger);
use LANraragi::Utils::Database qw(invalidate_cache);
use LANraragi::Model::Search;

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name       => "[PREVIEW] E*Hentai Downloader",
        type       => "script",
        namespace  => "ehdl",
        login_from => "ehlogin",
        author     => "Difegue",
        version    => "0.1",
        description =>
          "Downloads the given e*hentai URL and adds it to LANraragi.<br>This script serves as a preview to a potential feature. Might be buggy! Requires login details in the E-H Plugin to be filled out.",
        oneshot_arg => "URL to download."
    );

}

# Mandatory function to be implemented by your script
sub run_script {
    shift;
    my $lrr_info = shift;
    my $logger   = get_logger( "EH Downloader(Preview)", "plugins" );

    # Only info we need is the URL to DL
    my $url     = $lrr_info->{oneshot_param};
    my $gID     = "";
    my $gToken  = "";
    my $archKey = "";
    my $domain  = ( $url =~ /.*exhentai\.org/gi ) ? 'https://exhentai.org' : 'https://e-hentai.org';

    $logger->debug($url);
    if ( $url =~ /.*\/g\/([0-9]*)\/([0-z]*)\/*.*/ ) {
        $gID    = $1;
        $gToken = $2;
    } else {
        return ( error => "Not a valid E-H URL!" );
    }

    $logger->debug("gID: $gID, gToken: $gToken");

    # The API can give us archiver keys, but they seem to be invalid...
    # Which means it's time for some ol' DOM parsing.
    my $response = $lrr_info->{user_agent}->max_redirects(5)->get($url)->result;
    my $content  = $response->body;
    my $dom      = Mojo::DOM->new($content);

    eval {
        # Archiver key is stuck in an onclick in the "Archive Download" link.
        my $onclick = $dom->at(".g2")->at("a")->attr('onclick');
        if ( $onclick =~ /.*or=(.*)'.*/gim ) {
            $archKey = $1;
        }
    };

    if ( $archKey eq "" ) {
        return ( error => "Couldn't retrieve archiver key for gID $gID gToken $gToken" );
    }

    # Use archiver key in archiver.php
    #https://exhentai.org/archiver.php?gid=1638076&token=817f55f6fd&or=441617--08433a31606bc6c730e260c7fcbb2e71699949ce
    my $archiverurl = "$domain\/archiver.php?gid=$gID&token=$gToken&or=$archKey";
    $logger->info("Archiver URL: $archiverurl");

    # Do a quick GET to check for potential errors
    my $archiverHtml = $lrr_info->{user_agent}->max_redirects(5)->get($archiverurl)->result->body;
    if ( index( $archiverHtml, "Invalid archiver key" ) != -1 ) {
        return ( error => "Invalid archiver key. ($archiverurl)" );
    }
    if ( index( $archiverHtml, "This page requires you to log on." ) != -1 ) {
        return ( error => "Invalid E*Hentai login credentials. Please make sure the login plugin has proper settings set." );
    }

    # We only use original downloads, so we POST directly to the archiver form with dltype="org"
    # and dlcheck ="Download+Original+Archive"
    my $response = $lrr_info->{user_agent}->max_redirects(5)->post(
        $archiverurl => form => {
            dltype  => 'org',
            dlcheck => 'Download+Original+Archive'
        }
    )->result;

    my $content = $response->body;
    $logger->debug("/archiver.php result: $content");

    my $finalURL = "";
    eval {
        # Parse that to get the final URL
        if ( $content =~ /.*document.location = "(.*)".*/gim ) {
            $finalURL = $1;
            $logger->info("Final URL obtained: $finalURL");
        }
    };

    if ( $finalURL eq "" ) {
        return ( error => "Couldn't proceed with an original size download: <pre>$content</pre>" );
    }

    # Append start=1 to get an URL that automatically triggers the download.
    # A proper download plugin would end here.
    $finalURL .= "?start=1";

    ########
    # Download to a temp folder (code below lifted wholesale from Controller/Upload.pm)
    my $tempdir = tempdir();
    $logger->info("Downloading...This will take some time.");

    my $tx           = $lrr_info->{user_agent}->max_redirects(5)->get($finalURL);
    my $content_disp = $tx->result->headers->content_disposition;
    my $filename     = "$gID-$gToken.zip";                                          #placeholder;

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

    # Compute an ID here
    my $id = LANraragi::Utils::Database::compute_id($tempfile);
    $logger->debug("ID of uploaded file is $id");

    # Future home of the file
    my $output_file = LANraragi::Model::Config->get_userdir . '/' . $filename;

    #Check if the ID is already in the database, and
    #that the file it references still exists on the filesystem
    my $redis  = LANraragi::Model::Config->get_redis();
    my $isdupe = $redis->exists($id) && -e $redis->hget( $id, "file" );

    if ( -e $output_file || $isdupe ) {

        # Trash temporary file
        unlink $tempfile;

        # The file already exists
        return ( error => "File $tempfile already exists in library." );

    } else {

        # Add the file to the database ourselves so Shinobu doesn't do it
        # This allows autoplugin to be ran ASAP.
        LANraragi::Utils::Database::add_archive_to_redis( $id, $output_file, $redis );

        # Invalidate search cache ourselves, Shinobu won't do it since the file is already in the database
        invalidate_cache();

        # Move the file to the content folder.
        # Move to a .tmp first in case copy to the content folder takes a while...
        move( $tempfile, $output_file . ".upload" );

        # Then rename inside the content folder itself to proc Shinobu.
        move( $output_file . ".upload", $output_file );

        unless ( -e $output_file ) {
            return ( error => "File couldn't be moved to content folder!" );
        }

    }

    # All done!
    return (
        result_id => $id,
        filename  => $output_file
    );

}

1;
