package LANraragi::Utils::TempFolder;

use strict;
use warnings;
use utf8;

use Cwd 'abs_path';
use File::Basename;

#Contains all functions related to the temporary folder.
use Exporter 'import';
our @EXPORT_OK = qw(get_temp);

#Get the current tempfolder.
sub get_temp {
    my $temp_folder = dirname(__FILE__) . "/../../../temp";

    # Folder location can be overriden by LRR_TEMP_DIRECTORY
    if ( $ENV{LRR_TEMP_DIRECTORY} ) {
        $temp_folder = $ENV{LRR_TEMP_DIRECTORY};
    }

    mkdir $temp_folder;
    return abs_path($temp_folder);
}

1;
