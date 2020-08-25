package LANraragi::Utils::Minion;

use strict;
use warnings;
use utf8;

use LANraragi::Utils::Logging qw(get_logger);
use LANraragi::Utils::Archive qw(extract_thumbnail); 

# Add Tasks to the Minion instance.
sub add_tasks {
    my $minion = shift;

    $minion->add_task(thumbnail_task => sub {
        my ($job, @args) = @_;
        my ($dirname, $id) = @args;

        my $thumbname = extract_thumbnail( $dirname, $id );
        $job->finish( $thumbname );
    });

    $minion->add_task(warm_cache => sub {
        my ($job, @args) = @_;
        my $logger = get_logger( "Minion", "minion" );

        $logger->info("Warming up search cache...");
        LANraragi::Model::Search::do_search( "", "", 0, "title", "asc", 0, 0 );
        $logger->info("Done!");
    });

    $minion->add_task(download_url => sub {
        my ($job, @args) = @_;
        sleep 5;
        print 'This is a background worker process.';
    });

}

1;