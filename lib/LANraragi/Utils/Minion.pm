package LANraragi::Utils::Minion;

use strict;
use warnings;

use Encode;
use Mojo::UserAgent;
use Parallel::Loops;

use LANraragi::Utils::Logging    qw(get_logger);
use LANraragi::Utils::Database   qw(redis_decode);
use LANraragi::Utils::Archive    qw(extract_thumbnail);
use LANraragi::Utils::Plugins    qw(get_downloader_for_url get_plugin get_plugin_parameters use_plugin);
use LANraragi::Utils::Generic    qw(split_workload_by_cpu);
use LANraragi::Utils::String     qw(trim_url);
use LANraragi::Utils::TempFolder qw(get_temp);

use LANraragi::Model::Upload;
use LANraragi::Model::Config;
use LANraragi::Model::Stats;

# Add Tasks to the Minion instance.
sub add_tasks {
    my $minion = shift;

    $minion->add_task(
        thumbnail_task => sub {
            my ( $job, @args ) = @_;
            my ( $thumbdir, $id, $page ) = @args;

            my $logger = get_logger( "Minion", "minion" );

            # Non-cover thumbnails are rendered in low quality by default.
            my $use_hq    = $page eq 0 || LANraragi::Model::Config->get_hqthumbpages;
            my $thumbname = "";

            # Take a shortcut here - Minion jobs can keep the old basic behavior of page 0 = cover.
            eval { $thumbname = extract_thumbnail( $thumbdir, $id, $page, $page eq 0, $use_hq ); };
            if ($@) {
                my $msg = "Error building thumbnail: $@";
                $logger->error($msg);
                $job->fail( { errors => [$msg] } );
            } else {
                $job->finish($thumbname);
            }

        }
    );

    $minion->add_task(
        page_thumbnails => sub {

            my ( $job, @args )  = @_;
            my ( $id,  $force ) = @args;

            my $logger = get_logger( "Minion", "minion" );
            $logger->debug("Generating page thumbnails for archive $id...");

            # Get the number of pages in the archive
            my $redis = LANraragi::Model::Config->get_redis;
            my $pages = $redis->hget( $id, "pagecount" );

            my $use_hq   = LANraragi::Model::Config->get_hqthumbpages;
            my $thumbdir = LANraragi::Model::Config->get_thumbdir;

            my $use_jxl   = LANraragi::Model::Config->get_jxlthumbpages;
            my $format    = $use_jxl ? 'jxl' : 'jpg';
            my $subfolder = substr( $id, 0, 2 );

            my @errors = ();

            my $numCpus = Sys::CpuAffinity::getNumCpus();
            my $pl      = Parallel::Loops->new($numCpus);
            $pl->share( \@errors );

            $logger->debug("Number of available cores for processing: $numCpus");

            # Generate thumbnails for all pages -- Cover should already be handled in higher resolution
            my @keys = ();
            for ( my $i = 1; $i <= $pages; $i++ ) {
                push @keys, $i;
            }
            my @sections = split_workload_by_cpu( $numCpus, @keys );

            # Regen thumbnails for errythang if $force = 1, only missing thumbs otherwise
            eval {
                $pl->foreach(
                    \@sections,
                    sub {
                        foreach my $i (@$_) {

                            my $thumbname = "$thumbdir/$subfolder/$id/$i.$format";
                            unless ( $force == 0 && -e $thumbname ) {
                                $logger->debug("Generating thumbnail for page $i... ($thumbname)");
                                eval { $thumbname = extract_thumbnail( $thumbdir, $id, $i, 0, $use_hq ); };
                                if ($@) {
                                    $logger->warn("Error while generating thumbnail: $@");
                                    push @errors, $@;
                                }
                            }

                            # Add page number to note field so it can be fetched by the API
                            $job->note( $i => "processed", total_pages => $pages );

                        }
                    }
                );
            };

            $redis->hdel( $id, "thumbjob" );
            $redis->quit;
            $job->finish( { errors => \@errors } );
        }
    );

    $minion->add_task(
        regen_all_thumbnails => sub {
            my ( $job,      @args )  = @_;
            my ( $thumbdir, $force ) = @args;

            my $logger = get_logger( "Minion", "minion" );
            my $redis  = LANraragi::Model::Config->get_redis;
            my @keys   = $redis->keys('????????????????????????????????????????');
            $redis->quit();

            $logger->info("Starting thumbnail regen job (force = $force)");
            my @errors = ();

            my $numCpus = Sys::CpuAffinity::getNumCpus();
            my $pl      = Parallel::Loops->new($numCpus);
            $pl->share( \@errors );

            $logger->debug("Number of available cores for processing: $numCpus");
            my @sections = split_workload_by_cpu( $numCpus, @keys );

            # Regen thumbnails for errythang if $force = 1, only missing thumbs otherwise
            eval {
                $pl->foreach(
                    \@sections,
                    sub {
                        foreach my $id (@$_) {

                            my $use_jxl   = LANraragi::Model::Config->get_jxlthumbpages;
                            my $format    = $use_jxl ? 'jxl' : 'jpg';
                            my $subfolder = substr( $id, 0, 2 );
                            my $thumbname = "$thumbdir/$subfolder/$id.$format";

                            unless ( $force == 0 && -e $thumbname ) {
                                eval {
                                    $logger->debug("Regenerating for $id...");
                                    extract_thumbnail( $thumbdir, $id, 0, 1, 1 );
                                };

                                if ($@) {
                                    $logger->warn("Error while generating thumbnail: $@");
                                    push @errors, $@;
                                }
                            }
                        }
                    }
                );
            };

            $job->finish( { errors => \@errors } );
        }
    );

    $minion->add_task(
        build_stat_hashes => sub {
            my ( $job, @args ) = @_;
            LANraragi::Model::Stats->build_stat_hashes;
            $job->finish;
        }
    );

    $minion->add_task(
        handle_upload => sub {
            my ( $job,  @args )  = @_;
            my ( $file, $catid ) = @args;

            my $logger = get_logger( "Minion", "minion" );

# Superjank warning for the code below.
#
# Filepaths are left unencoded across all of LRR to avoid any headaches with how the filesystem handles filenames with non-ASCII characters.
# (Some FS do UTF-8 properly, others not at all. We use File::Find, which returns direct bytes, to always have a filepath that matches the FS.)
#
# By "unencoded" tho, I actually mean Latin-1/ISO-8859-1.
# Perl strings are internally either in Latin-1 or non-strict utf-8 ("utf8"), depending on the history of the string.
# (See https://perldoc.perl.org/perlunifaq#I-lost-track;-what-encoding-is-the-internal-format-really?)
#
# When passing the string through the Minion pipe, it gets switched to utf8 for...reasons? ¯\_(ツ)_/¯
# This actually breaks the string and makes it no longer match the real name/byte sequence if it contained non-ASCII characters,
# so we use this arcane dark magic function to switch it back.
# (See https://perldoc.perl.org/perlunicode#Forcing-Unicode-in-Perl-(Or-Unforcing-Unicode-in-Perl))
            utf8::downgrade( $file, 1 )
              or die "Bullshit! File path could not be converted back to a byte sequence!"
              ;    # This error happening would not make any sense at all so it deserves the EYE reference

            $logger->info("Processing uploaded file $file...");

            # Since we already have a file, this goes straight to handle_incoming_file.
            my ( $status_code, $id, $title, $message ) =
              LANraragi::Model::Upload::handle_incoming_file( $file, $catid, "", "", "" );
            my $status = $status_code == 200 ? 1 : 0;
            $job->finish(
                {   success  => $status,
                    id       => $id,
                    category => $catid,
                    title    => redis_decode($title),    # Fix display issues in the response
                    message  => $message
                }
            );
        }
    );

    $minion->add_task(
        download_url => sub {
            my ( $job, @args )  = @_;
            my ( $url, $catid ) = @args;

            my $ua     = Mojo::UserAgent->new;
            my $logger = get_logger( "Minion", "minion" );
            $logger->info("Downloading url $url...");

            # Keep a clean copy of the url for display and tagging
            my $og_url = $url;
            $og_url = trim_url($og_url);

            # If the URL is already recorded, abort the download
            my $recorded_id = LANraragi::Model::Stats::is_url_recorded($og_url);
            if ($recorded_id) {
                $job->finish(
                    {   success => 0,
                        url     => $og_url,
                        id      => $recorded_id,
                        message => "URL already downloaded!"
                    }
                );
                return;
            }

            # Check downloader plugins for one matching the given URL
            my $downloader = get_downloader_for_url($url);

            if ($downloader) {

                $logger->info( "Found downloader " . $downloader->{namespace} );

                # Use the downloader to transform the URL
                my $plugname = $downloader->{namespace};
                my $plugin   = get_plugin($plugname);
                my %settings = get_plugin_parameters($plugname);

                my $plugin_result = LANraragi::Model::Plugins::exec_download_plugin( $plugin, $url, %settings );

                if ( exists $plugin_result->{error} ) {
                    $job->finish(
                        {   success => 0,
                            url     => $url,
                            message => $plugin_result->{error}
                        }
                    );
                }

                $ua  = $plugin_result->{user_agent};
                $url = $plugin_result->{download_url};
                $logger->info("URL transformed by plugin to $url");
            } else {
                $logger->debug("No downloader found, trying direct URL.");
            }

            # Download the URL
            eval {
                my $tempfile = LANraragi::Model::Upload::download_url( $url, $ua );
                $logger->info("URL downloaded to $tempfile");

                # Add the url as a source: tag
                my $tag = "source:$og_url";

                # Hand off the result to handle_incoming_file
                my ( $status_code, $id, $title, $message ) =
                  LANraragi::Model::Upload::handle_incoming_file( $tempfile, $catid, $tag, "", "" );
                my $status = $status_code == 200 ? 1 : 0;

                $job->finish(
                    {   success  => $status,
                        url      => $og_url,
                        id       => $id,
                        category => $catid,
                        title    => $title,
                        message  => $message
                    }
                );
            };

            if ($@) {

                # Downloading failed...
                $job->finish(
                    {   success => 0,
                        url     => $og_url,
                        message => $@
                    }
                );
            }
        }
    );

    $minion->add_task(
        run_plugin => sub {
            my ( $job, @args ) = @_;
            my ( $namespace, $id, $scriptarg ) = @args;

            my $logger = get_logger( "Minion", "minion" );
            $logger->info("Running plugin $namespace...");

            my ( $pluginfo, $plugin_result ) = use_plugin( $namespace, $id, $scriptarg );

            $job->finish(
                {   type    => $pluginfo->{type},
                    success => ( exists $plugin_result->{error} ? 0 : 1 ),
                    error   => $plugin_result->{error},
                    data    => $plugin_result
                }
            );
        }
    );

}

1;
