package LANraragi::Plugin::Scripts::FolderToCat;

use strict;
use warnings;
use File::Find;
use File::Basename;
use Data::Dumper;

use LANraragi::Utils::Logging qw(get_logger);
use LANraragi::Utils::Generic qw(is_archive);
use LANraragi::Utils::Database qw(compute_id);
use LANraragi::Model::Category;

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name      => "Subfolders to Categories",
        type      => "script",
        namespace => "fldr2cat",
        author    => "Difegue",
        version   => "1.0",
        icon =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IArs4c6QAAAuJJREFUOI3FlE1sVFUUx3/nvVdaSqd0sAmElDYopOWjsKiEnYkLowU2uMGw0ajBhS5oqAtwo3FTaIQNCz7CBldEE01M+AglJMACUyBQrI6iQ2groNNxpjPz5n3MnXddvOnrfACNK09yk/fuved3//933j3wf8Thw6O6q6tHd3X16FOnTusX7ZW7I7H0kuUrV6hCtmHxt7UnOXHiDInEJAAzM49kscMtw2xesWHfKOTGASNa+GnmHfYP7gSgr28TY2PnF4UBWAD88Tlk7kFVyuDbX0ew43vzU/6bnc+12vnqx4OrX//i4gIQXS2uJkZGvqRXD3Q/V9LKXdjmSxcmjq7ahi6vtRazMKAHGua8oolbsHDyFk7iF4r/3IOyGl9QKI1u+vo2kUhMsmZ3T8Pa5c+E5vYYzbFWWkQTW23R+XKc+9/+eKUB+MbBHZWqhpW9MGSjtdDes57OzRtZ2hFD4tshcEAVkHIeVIapse8wDPNQxbKBDuDhxHKODd5myZ44698dBTQgUbEkex0CFzJXIfDC58CDwCP3Z1ZtPpAaD4FWnJIv2Nkm+j85AroE/jRoHwI/SgoBbt27h+54DS3je0VEh7VtimOnm2mKxRcguhpUDXvGUDb9bd3fh14rCtNPWuh9/6s6RfWq6mEetG0le/cb5KPbpajKActwChaIVNR5ddAqeLkCmt9TLjCbzEVFtQDstENTW0c4M58cJbiNsPmxtBs7eQ03p87VANP3J+n94CjiPKj76N4z7M4f6IPKk35YAFMORUCzpRU3/VdoV82BytUm+jMQlEArlBJmEyncORdnroTypxCRt7YMp5IRUBVzv/cPnV0n+VshyH8MgYuycyjHJjPt4GbyONki5VIAItfQnBeTG62YD1458DTF8EJXscSw1lEu4s0m8TJ/k/o5iZuZIygHlb+ZHwzkUoC+2T+cuiNSd08/re1qMjFa25YM5D0xjVtGe8fUhg9/zfMf41+ZdKPYI8TqHgAAAABJRU5ErkJggg==",
        description =>
          "Scan your Content Folder and automatically create Static Categories for each subfolder.<br>This Script will create a category for each subfolder with archives as direct children.",
        parameters =>
          [ { type => "bool", desc => "Delete all your static categories before creating the ones matching your subfolders" } ]
    );

}

# Mandatory function to be implemented by your script
sub run_script {
    shift;
    my $lrr_info          = shift;
    my ($delete_old_cats) = @_;
    my $logger            = get_logger( "Folder2Category", "plugins" );
    my $userdir           = LANraragi::Model::Config->get_userdir;

    my %subfolders;
    my @created_categories;

    if ($delete_old_cats) {
        $logger->info("Deleting all Static Categories before folder walking as instructed.");

        my @categories = LANraragi::Model::Category::get_category_list;
        for my $category (@categories) {
            if ( %{$category}{"search"} eq "" ) {
                my $cat_id = %{$category}{"id"};
                $logger->debug("Deleting '$cat_id'");
                LANraragi::Model::Category::delete_category($cat_id);
            }
        }
    }

    # Walk through content folder and find all subfolders with files in them
    find(
        {   wanted => sub {
                return if $File::Find::dir eq $userdir;    # Direct children of the content dir are excluded

                my $dirname = basename($File::Find::dir);
                if ( is_archive($_) ) {
                    unless ( exists( $subfolders{$dirname} ) ) {
                        $subfolders{$dirname} = [];        # Create array in hash for this folder
                    }
                    push @{ $subfolders{$dirname} }, $_;
                }
            },
            no_chdir    => 1,
            follow_fast => 1
        },
        $userdir
    );

    $logger->debug( "Find routine results: " . Dumper %subfolders );

    # For each subfolder with file, create a category bearing its name and containing all its files
    for my $folder ( keys %subfolders ) {
        my $catID = LANraragi::Model::Category::create_category( $folder, "", 0, "" );
        push @created_categories, $catID;

        for my $file ( @{ $subfolders{$folder} } ) {
            my $id = compute_id($file) || next;
            LANraragi::Model::Category::add_to_category( $catID, $id );
        }
    }

    return ( created_categories => \@created_categories );

}

1;
