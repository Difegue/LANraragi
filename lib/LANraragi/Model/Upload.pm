package LANraragi::Model::Upload;

use v5.36;

use strict;
use warnings;

use Redis;
use URI::Escape;
use File::Basename;
use File::Temp qw(tempdir);
use File::Find qw(find);
use File::Copy qw(move);

use LANraragi::Utils::Archive  qw(extract_thumbnail);
use LANraragi::Utils::Database qw(invalidate_cache compute_id set_title set_summary);
use LANraragi::Utils::Logging  qw(get_logger);
use LANraragi::Utils::Database qw(redis_encode);
use LANraragi::Utils::Generic  qw(is_archive get_bytelength);
use LANraragi::Utils::String   qw(trim trim_CRLF trim_url);

use LANraragi::Model::Config;
use LANraragi::Model::Plugins;
use LANraragi::Model::Category;

# Handle files uploaded by the user, or downloaded from remote endpoints.

# Process a file.
# First argument is the filepath, preferably in a temp directory,
# as we'll copy it to the content folder and delete the original at the end.
#
# The file will be added to a category, if its ID is specified.
# You can also specify tags to add to the metadata for the processed file before autoplugin is ran. (if it's enabled)
#
# Returns an HTTP status code, the ID and title of the file, and a status message.
sub handle_incoming_file ( $tempfile, $catid, $tags, $title, $summary ) {

    my ( $filename, $dirs, $suffix ) = fileparse( $tempfile, qr/\.[^.]*/ );
    $filename = $filename . $suffix;
    my $logger = get_logger( "File Upload/Download", "lanraragi" );

    # Check if file is an archive
    unless ( is_archive($filename) ) {
        $logger->debug("$filename is not an archive, halting upload process.");
        return ( 415, "deadbeef", $filename, "Unsupported File Extension ($filename)" );
    }

    # Compute an ID here
    my $id = compute_id($tempfile);
    $logger->debug("ID of uploaded file $filename is $id");

    # Future home of the file
    my $userdir     = LANraragi::Model::Config->get_userdir;
    my $output_file = $userdir . '/' . $filename;

    #Check if the ID is already in the database, and
    #that the file it references still exists on the filesystem
    my $redis        = LANraragi::Model::Config->get_redis;
    my $redis_search = LANraragi::Model::Config->get_redis_search;
    my $replace_dupe = LANraragi::Model::Config->get_replacedupe;
    my $isdupe       = $redis->exists($id) && -e $redis->hget( $id, "file" );

    # Stop here if file is a dupe and replacement is turned off.
    if ( ( -e $output_file || $isdupe ) && !$replace_dupe ) {

        # Trash temporary file
        unlink $tempfile;

        # The file already exists
        my $suffix = " Enable replace duplicated archive in config to replace old ones.";
        my $msg =
          $isdupe
          ? "This file already exists in the Library." . $suffix
          : "A file with the same name is present in the Library." . $suffix;

        return ( 409, $id, $filename, $msg );
    }

    # If we are replacing an existing one, just remove the old one first.
    if ($replace_dupe) {
        $logger->debug("Delete archive $id before replacing it.");
        LANraragi::Model::Archive::delete_archive($id);
    }

    # Add the file to the database ourselves so Shinobu doesn't do it
    # This allows autoplugin to be ran ASAP.
    my $name = LANraragi::Utils::Database::add_archive_to_redis( $id, $output_file, $output_file, $redis, $redis_search );

    # If additional tags were given to the sub, add them now.
    if ($tags) {
        $redis->hset( $id, "tags", redis_encode($tags) );

        # Check for a source: tag, and if it exists amend the urlmap by hand.
        # This is faster than queueing a full recalculation job.
        my @tags = split( /,\s?/, $tags );

        foreach my $t (@tags) {
            $t = trim($t);
            $t = trim_CRLF($t);

            # If the tag is a source: tag, add it to the URL index
            if ( $t =~ /source:(.*)/i ) {
                my $url = $1;
                $logger->debug("Adding $url as an URL for $id");
                trim_url($url);
                $logger->debug("Trimmed: $url");

                # No need to encode the value, as URLs are already encoded by design
                $redis_search->hset( "LRR_URLMAP", $url, $id );
            }
        }
    }

    # Set title
    if ($title) {
        set_title( $id, $title );
    }

    # Set summary
    if ($summary) {
        set_summary( $id, $summary );
    }

    # Move the file to the content folder.
    # Move to a .upload first in case copy to the content folder takes a while...
    move( $tempfile, $output_file . ".upload" )
      or return ( 500, $id, $name, "The file couldn't be moved to your content folder: $!" );

    # Then rename inside the content folder itself to proc Shinobu's filemap update.
    move( $output_file . ".upload", $output_file )
      or return ( 500, $id, $name, "The file couldn't be renamed in your content folder: $!" );

    # If the move didn't signal an error, but still doesn't exist, something is quite spooky indeed!
    # Really funky permissions that prevents viewing folder contents?
    unless ( -e $output_file ) {
        return ( 500, $id, $name, "The file couldn't be moved to your content folder!" );
    }

    # Now that the file has been copied, we can add the timestamp tag and calculate pagecount.
    # (The file being physically present is necessary in case last modified time is used)
    LANraragi::Utils::Database::add_timestamp_tag( $redis, $id );
    LANraragi::Utils::Database::add_pagecount( $redis, $id );
    LANraragi::Utils::Database::add_arcsize( $redis, $id );
    $redis->quit();
    $redis_search->quit();

    # Generate thumbnail
    my $thumbdir = LANraragi::Model::Config->get_thumbdir;
    extract_thumbnail( $thumbdir, $id, 1, 1, 1 );

    $logger->debug("Running autoplugin on newly uploaded file $id...");

    my ( $succ, $fail, $addedtags, $newtitle ) = LANraragi::Model::Plugins::exec_enabled_plugins_on_file($id);
    my $successmsg = "$succ Plugins used successfully, $fail Plugins failed, $addedtags tags added. ";

    if ( $newtitle ne "" ) {
        $name = $newtitle;
    }

    if ($catid) {
        $logger->debug("Adding uploaded file to category $catid");

        my ( $catsucc, $caterr ) = LANraragi::Model::Category::add_to_category( $catid, $id );
        if ($catsucc) {
            my %category = LANraragi::Model::Category::get_category($catid);
            my $catname  = $category{name};
            $successmsg .= "Added to Category '$catname'!";
        } else {
            $successmsg .= "Couldn't add to Category: $caterr";
        }
    }

    # Invalidate search cache ourselves, Shinobu won't do it since the file is already in the database
    invalidate_cache();

    return ( 200, $id, $name, $successmsg );
}

# Download the given URL, using the given Mojo::UserAgent object.
# This downloads the URL to a temporaryfolder and returns the full path to the downloaded file.
sub download_url ( $url, $ua ) {

    my $logger = get_logger( "File Upload/Download", "lanraragi" );

    # Download to a temp folder
    die "Not a proper URL" unless $url;
    $logger->info("Downloading URL $url...This will take some time.");

    my $tempdir = tempdir();

    # Download the URL, with 5 maximum redirects and unlimited response size.
    my $filename = "Not_an_archive";
    my ( $tx, $content_disp );

    my $attempts = 0;

    while ( !$content_disp && $attempts < 5 ) {
        $tx           = $ua->max_response_size(0)->max_redirects(5)->get($url);
        $content_disp = $tx->result->headers->content_disposition;

        unless ($content_disp) {
            $logger->warn("No valid Content-Disposition header received, waiting and retrying... (attempt $attempts / 5)");
            $logger->debug( "Result of this attempt: " . $tx->result->body );
            sleep 1;
            $attempts++;
        }
    }

    if ( !$content_disp ) {
        die( "No valid Content-Disposition header received after 5 attempts, aborting. (Last result: " . $tx->result->body . ")" );
    }

    $logger->debug("Content-Disposition Header: $content_disp");
    if ( $content_disp =~ /.*filename=\"(.*)\".*/gim ) {
        $filename = $1;
    } elsif ( $content_disp =~ /.*filename\*=UTF-8''(.*)/gim ) {

        # This is an UTF8 filename as per rfc5987.
        # URL-decode to get the full filename.
        $filename = uri_unescape($1);

    } elsif ( $url =~ /([^\/]+)\/?$/gm ) {

        # Fallback to the last element of the URL as the filename.
        $logger->debug("No filename found in header, using URL as filename.");
        $filename = $1;
    }

    $logger->debug("Filename: $filename");

    # remove invalid Windows chars
    $filename =~ s@[\\/:"*?<>|]+@@g;

    my ( $fn, $path, $ext ) = fileparse( $filename, qr/\.[^.]*/ );
    my $byte_limit = LANraragi::Model::Config->enable_cryptofs ? 143 : 255;

    # don't allow the main filename to exceed the given byte limit
    # for extension and .upload prefix used by `handle_incoming_file`
    $filename = $fn;
    while ( get_bytelength( $filename . $ext . ".upload" ) > $byte_limit ) {
        $filename = substr( $filename, 0, -1 );
    }
    $filename = $filename . $ext;
    $logger->debug("Filename post clean: $filename");
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
