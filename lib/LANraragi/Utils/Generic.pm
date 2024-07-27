package LANraragi::Utils::Generic;

use strict;
use warnings;
use utf8;
no warnings 'experimental';

use Storable qw(store);
use Digest::SHA qw(sha256_hex);
use Mojo::Log;
use Mojo::Util qw(xml_escape);
use Mojo::IOLoop;
use Logfile::Rotate;
use Proc::Simple;
use Sys::CpuAffinity;

use LANraragi::Utils::TempFolder qw(get_temp);
use LANraragi::Utils::String qw(trim);
use LANraragi::Utils::Logging qw(get_logger);

# Generic Utility Functions.
use Exporter 'import';
our @EXPORT_OK = qw(is_image is_archive render_api_response get_tag_with_namespace shasum start_shinobu
  split_workload_by_cpu start_minion get_css_list generate_themes_header flat get_bytelength array_difference);

# Checks if the provided file is an image.
# Uses non-capturing groups (?:) to avoid modifying the incoming argument.
sub is_image {
    return $_[0] =~ /^.+\.(?:png|jpg|gif|bmp|jpeg|jfif|webp|avif|heif|heic|jxl|)$/i;
}

# Checks if the provided file is an archive.
sub is_archive {
    return $_[0] =~ /^.+\.(?:zip|rar|7z|tar|tar\.gz|lzma|xz|cbz|cbr|cb7|cbt|pdf|epub|)$/i;
}

# Renders the basic success API JSON template.
# Specifying an error message argument will set the success variable to 0.
sub render_api_response {
    my ( $mojo, $operation, $errormessage, $successMessage ) = @_;
    my $failed = ( defined $errormessage );

    $mojo->render(
        json => {
            operation      => $operation,
            error          => $failed ? xml_escape($errormessage) : "",
            success        => $failed ? 0 : 1,
            successMessage => $failed ? "" : xml_escape($successMessage),
        },
        status => $failed ? 400 : 200
    );
}

# Find the first tag matching the given namespace, or return the default value.
sub get_tag_with_namespace {
    my ( $namespace, $tags, $default ) = @_;
    my @values = split( ',', $tags );

    foreach my $tag (@values) {
        my ( $namecheck, $value ) = split( ':', $tag );
        $namecheck = trim($namecheck);
        $value     = trim($value);

        if ( $namecheck eq $namespace ) {
            return $value;
        }
    }

    return $default;
}

# Split an array into an array of arrays, according to host CPU count.
sub split_workload_by_cpu {

    my ( $numCpus, @workload ) = @_;

    # Split the workload equally between all CPUs with an array of arrays
    my @sections;
    while (@workload) {
        foreach ( 0 .. $numCpus - 1 ) {
            if (@workload) {
                push @{ $sections[$_] }, shift @workload;
            }
        }
    }

    return @sections;
}

# Start a Minion worker if there aren't any available.
sub start_minion {
    my $mojo   = shift;
    my $logger = get_logger( "Minion", "minion" );

    my $numcpus = Sys::CpuAffinity::getNumCpus();
    $logger->info("Starting new Minion worker in subprocess with $numcpus parallel jobs.");

    my $worker = $mojo->app->minion->worker;
    $worker->status->{jobs} = $numcpus;
    $worker->on( dequeue => sub { pop->once( spawn => \&_spawn ) } );

    # https://github.com/mojolicious/minion/issues/76
    my $proc = Proc::Simple->new();
    $proc->start(
        sub {
            $logger->info("Minion worker $$ started");
            $worker->run;
            $logger->info("Minion worker $$ stopped");
            return 1;
        }
    );
    $proc->kill_on_destroy(0);

    # Freeze the process object in the PID file
    store \$proc, get_temp() . "/minion.pid";
    open( my $fh, ">", get_temp() . "/minion.pid-s6" );
    print $fh $proc->pid;
    close($fh);
    return $proc;
}

sub _spawn {
    my ( $job, $pid )  = @_;
    my ( $id,  $task ) = ( $job->id, $job->task );
    my $logger = get_logger( "Minion Worker", "minion" );
    $job->app->log->debug(qq{Process $pid is performing job "$id" with task "$task"});
}

# Start Shinobu and return its Proc::Background object.
sub start_shinobu {
    my $mojo = shift;

    my $proc = Proc::Simple->new();
    $proc->start( $^X, "./lib/Shinobu.pm" );
    $proc->kill_on_destroy(0);

    $mojo->LRR_LOGGER->debug( "Shinobu Worker new PID is " . $proc->pid );

    # Freeze the process object in the PID file
    store \$proc, get_temp() . "/shinobu.pid";
    open( my $fh, ">", get_temp() . "/shinobu.pid-s6" );
    print $fh $proc->pid;
    close($fh);
    return $proc;
}

#This function gives us a SHA hash for the passed file, which is used for thumbnail reverse search on E-H.
#First argument is the file, second is the algorithm to use. (1, 224, 256, 384, 512, 512224, or 512256)
#E-H only uses SHA-1 hashes.
sub shasum {

    my $digest = "";
    my $logger = get_logger( "Hash Computation", "lanraragi" );

    eval {
        my $ctx = Digest::SHA->new( $_[1] );
        $ctx->addfile( $_[0] );
        $digest = $ctx->hexdigest;
    };

    if ($@) {
        $logger->error( "Error building hash for " . $_[0] . " -- " . $@ );

        return "";
    }

    return $digest;
}

sub get_css_list {

    #Get all the available CSS sheets.
    my @css;
    opendir( my $dir, "./public/themes" ) or die $!;
    while ( my $file = readdir($dir) ) {
        if ( $file =~ /.+\.css/ ) { push( @css, $file ); }
    }
    closedir($dir);

    return @css;
}

# Print a dropdown list to select CSS, and adds <link> tags for all the style sheets present in the /style folder.
sub generate_themes_header {

    my $self    = shift;
    my $version = $self->LRR_VERSION;
    my @css     = get_css_list;

    # Html that we'll insert in the header to declare all the available styles.
    my $html = "";

    # Go through the css files
    for ( my $i = 0; $i < $#css + 1; $i++ ) {

        my $css_file = $css[$i];
        my ( $css_name, $css_color ) = css_default_data($css_file);

        # If this is the default sheet, set it up as so.
        if ( $css[$i] eq LANraragi::Model::Config->get_style ) {

            $html .= qq(<link rel="stylesheet" type="text/css" title="$css_name" href="/themes/$css_file?$version">);

            # Add the main color as a them-color meta tag
            $html .= qq(<meta name="theme-color" content="$css_color">);
        } else {
            $html .= qq(<link rel="alternate stylesheet" type="text/css" title="$css_name" href="/themes/$css_file?$version">);
        }
    }

    return $html;

}

# Assign a name and an accent color to the css file passed. You can add names by adding cases.
# Note: CSS files added to the /themes folder will ALWAYS be pickable by the users no matter what.
# All this sub does is give .css files prettier names in the dropdown. Files without a name here will simply show as their filename to the users.
sub css_default_data {
    if ($_[0] eq "g.css")               { return ( "H-Verse",   "#5F0D1F" ) }
    elsif ($_[0] eq "modern.css")       { return ( "Hachikuji", "#34353B" ) }
    elsif ($_[0] eq "modern_clear.css") { return ( "Yotsugi",   "#34495E" ) }
    elsif ($_[0] eq "modern_red.css")   { return ( "Nadeko",    "#D83B66" ) }
    elsif ($_[0] eq "ex.css")           { return ( "Sad Panda", "#43464E"  )}
    else { return ( $_[0], "#34353B") }
}

sub flat {
    return map { ref eq 'ARRAY' ? @$_ : $_ } @_;
}

# Get the byte length of a string.
sub get_bytelength {
    use bytes;
    return length shift;
}

# Gets right difference between 2 arrays.
sub array_difference {
    my ( $array1, $array2 ) = @_;

    my %seen;
    my @difference;

    # Add all elements from array1 to the hash
    $seen{$_} = 1 for @$array1;

    # Check elements in array2 and add the ones not seen in array1 to the difference array
    foreach my $element (@$array2) {
        push @difference, $element unless $seen{$element};
    }

    return @difference;
}

1;
