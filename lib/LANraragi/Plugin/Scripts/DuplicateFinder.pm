package LANraragi::Plugin::Scripts::DuplicateFinder;

use strict;
use warnings;
no warnings 'uninitialized';

use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::Plugins qw(use_plugin);
use LANraragi::Utils::Database qw(set_tags);
use LANraragi::Model::Archive;
use LANraragi::Model::Category;

sub plugin_info {

    return (
        # Standard metadata
        name        => "Duplicate Finder",
        type        => "script",
        namespace   => "duplicatefinder",
        author      => "CHUSHEN",
        version     => "1.0",
        description => "Find duplicate archives by title and add them to the DuplicateArchives category."
    );

}

sub run_script {
    shift;
    my $lrr_info = shift;
    my $logger   = get_plugin_logger();

    my %title_count;
    # get all archives
    my @archives = LANraragi::Model::Archive->generate_archive_list;
    for my $archive (@archives) {
        my $title  = $archive->{"title"};
        $title_count{$title}++;
    }
    my $archives_count = scalar keys %title_count;
    $logger->info("start process, total count: $archives_count");

    my $DuplicateArchivesCategory="DuplicateArchives";

    # get all static categories
    my @static_categories=LANraragi::Model::Category->get_static_category_list;
    foreach my $static_category (@static_categories){
        my $cat_name = $static_category->{"name"};
        my $cat_id = $static_category->{"id"};
        if ($cat_name eq $DuplicateArchivesCategory){
            # remove old DuplicateArchives category
            LANraragi::Model::Category::delete_category($cat_id);
            $logger->info("remove old category: $cat_name");
        }
    }

    # create new DuplicateArchives category with pinned
    my $catID = LANraragi::Model::Category::create_category( $DuplicateArchivesCategory, "", 1, "" );

    foreach my $title (keys %title_count) {
        if ($title_count{$title} > 1) {
            my @duplicate_archives = grep { $_->{'title'} eq $title } @archives;
            for my $duplicate_archive (@duplicate_archives) {
                my $arcid = $duplicate_archive->{"arcid"};
                my $title  = $duplicate_archive->{"title"};
                # add archive to DuplicateArchives category
                my ($status, $message) = LANraragi::Model::Category::add_to_category($catID, $arcid);
                if ($status ne 1){
                    $logger->warn("Failed to add archive: $title. Error message: $message");
                }
            }
        }
    }

    return ( success => "Finish!" );
}

1;