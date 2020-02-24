package LANraragi::Utils::TempFolder;

use strict;
use warnings;
use utf8;

use Cwd 'abs_path';
use FindBin;
use File::stat;
use File::Find;
use File::Path qw(remove_tree);

use LANraragi::Utils::Generic;
use LANraragi::Utils::Logging qw(get_logger);

#Contains all functions related to the temporary folder.
use Exporter 'import'; 
our @EXPORT_OK = qw(get_temp get_tempsize clean_temp_full clean_temp_partial); 

#Get the current tempfolder.
#This can be called from any process safely as it uses FindBin.
sub get_temp {
    my $temp_folder = "$FindBin::Bin/../public/temp";
    
    # Folder location can be overriden by LRR_TEMP_DIRECTORY
    if ($ENV{LRR_TEMP_DIRECTORY}) {
        $temp_folder = $ENV{LRR_TEMP_DIRECTORY};
    }

    mkdir $temp_folder;
    return abs_path($temp_folder);
}

#Get the current size of the tempfolder, in Megabytes.
sub get_tempsize {
    my $size = 0;

    #Only stat the temp folder if it exists
    my $temp = &get_temp;
    if ( -e $temp ) {
        find( sub { $size += -s if -f }, $temp );
    }
    return int( $size / 1048576 * 100 ) / 100;
}

#Remove all folders in the tempfolder.
#Dies if an error occurs.
sub clean_temp_full {

    remove_tree( &get_temp, { error => \my $err } );

    my $cleanmsg = "";
    if (@$err) {
        for my $diag (@$err) {
            my ( $file, $message ) = %$diag;
            if ( $file eq '' ) {
                die "General error: $message\n";
            }
            else {
                die "Problem unlinking $file: $message\n";
            }
        }
    }

}

#Remove all folders in /public/temp except the most recent one
#For this, we use Perl's ctime, which uses inode last modified time.
sub clean_temp_partial {

    my $logger = get_logger( "Temporary Folder", "lanraragi" );

    my $tempdir = &get_temp;

    #Abort if the temp dir doesn't exist yet
    return unless ( -e $tempdir );

    my $size    = get_tempsize;
    my $maxsize = LANraragi::Model::Config->get_tempmaxsize;

    if ( $size > $maxsize ) {
        $logger->info( "Current temporary folder size is $size MBs, "
              . "Maximum size is $maxsize MBs. Cleaning." );

        #Wipe thumb temp folder first
        if ( -e $tempdir . "/thumb" ) { unlink( $tempdir . "/thumb" ); }

        opendir( my $dir_fh, $tempdir );

        my @folder_list;
        while ( my $file = readdir $dir_fh ) {

            next unless -d $tempdir . '/' . $file;
            next if $file eq '.' or $file eq '..';

            push @folder_list, "$tempdir/$file";
        }
        closedir $dir_fh;

        @folder_list = sort {
            my $a_stat = stat($a);
            my $b_stat = stat($b);
            $a_stat->ctime <=> $b_stat->ctime;
        } @folder_list;

        #Remove all folders in folderlist except the last one
        my $survivor = pop @folder_list;
        $logger->debug("Deleting all folders in /temp except $survivor");

        remove_tree( @folder_list, { error => \my $err } );

        if (@$err) {
            for my $diag (@$err) {
                my ( $file, $message ) = %$diag;
                if ( $file eq '' ) {
                    $logger->error("General error: $message\n");
                }
                else {
                    $logger->error("Problem unlinking $file: $message\n");
                }
            }
        }

        $logger->info("Done!");
    }
}

1;
