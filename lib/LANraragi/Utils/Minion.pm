package LANraragi::Utils::Minion;

use strict;
use warnings;
use utf8;

use LANraragi::Utils::Logging qw(get_logger);
use LANraragi::Utils::Archive qw(extract_thumbnail);

use LANraragi::Model::Upload;

# Add Tasks to the Minion instance.
sub add_tasks {
    my $minion = shift;

    $minion->add_task(
        thumbnail_task => sub {
            my ( $job,     @args ) = @_;
            my ( $dirname, $id )   = @args;

            my $thumbname = extract_thumbnail( $dirname, $id );
            $job->finish($thumbname);
        }
    );

    $minion->add_task(
        warm_cache => sub {
            my ( $job, @args ) = @_;
            my $logger = get_logger( "Minion", "minion" );

            $logger->info("Warming up search cache...");

            # TODO: Add warms for the most used searches -> look at categories
            LANraragi::Model::Search::do_search( "", "", 0, "title", "asc", 0, 0 );
            $logger->info("Done!");
            $job->finish;
        }
    );

    $minion->add_task(
        handle_upload => sub {
            my ( $job, @args ) = @_;
            my ($file) = @args;

            my $logger = get_logger( "Minion", "minion" );
            $logger->info("Processing uploaded file $file...");

            # Since we already have a file, this goes straight to handle_incoming_file.
            my ( $status, $id, $message ) = LANraragi::Model::Upload::handle_incoming_file($file);

            $job->finish(
                {   status  => $status,
                    id      => $id,
                    message => $message
                }
            );
        }
    );

    $minion->add_task(
        run_script => sub {
            my ( $job,    @args )      = @_;
            my ( $plugin, $arguments ) = @args;

            my $logger = get_logger( "Minion", "minion" );

            # TODO?

        }
    );

    $minion->add_task(
        download_url => sub {
            my ( $job, @args ) = @_;
            my ($url) = @args;

            my $logger = get_logger( "Minion", "minion" );
            $logger->info("Downloading url $url...");

            #TODO: Check downloader plugins for one matching the given URL

            # Invoke plugin if there's a match

            # Otherwise, try downloading the URL the bare-bones way

            # Hand off the result to the handle_incoming_file sub

        }
    );

}

1;
