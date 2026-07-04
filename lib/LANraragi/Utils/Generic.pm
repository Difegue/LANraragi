package LANraragi::Utils::Generic;

use strict;
use warnings;
use utf8;
use Cwd 'abs_path';
no warnings 'experimental';

use Storable    qw(store);
use Digest::SHA qw(sha256_hex);
use Mojo::Log;
use Mojo::Util qw(xml_escape);
use Mojo::IOLoop;
use Mojo::JSON qw(decode_json);
use Proc::Simple;
use Sys::CpuAffinity;
use Config;

use LANraragi::Utils::TempFolder qw(get_temp);
use LANraragi::Utils::String     qw(trim);
use LANraragi::Utils::Logging    qw(get_logger);

use constant IS_UNIX => ( $Config{osname} ne 'MSWin32' );

BEGIN {
    if ( !IS_UNIX ) {
        require Win32::Process;
        Win32::Process->import(qw(NORMAL_PRIORITY_CLASS));
    }
}

# Generic Utility Functions.
use Exporter 'import';
our @EXPORT_OK = qw(is_image is_archive is_chapter render_api_response get_tag_with_namespace shasum_str start_shinobu start_tsubasa
  split_workload_by_cpu start_minion get_css_list generate_themes_header flat get_bytelength array_difference
  intersect_arrays filter_hash_by_keys exec_with_lock exec_with_lock_pure generate_css_detail get_version get_item_title);

# Version information
my $version_info;

# Checks if the provided file is an image.
# Uses non-capturing groups (?:) to avoid modifying the incoming argument.
sub is_image {
    return $_[0] =~ /^.+\.(?:png|jpg|gif|bmp|jpeg|jfif|webp|avif|heif|heic|jxl|)$/i;
}

# Checks if the provided file is an archive.
sub is_archive {
    return $_[0] =~ /^.+\.(?:zip|rar|7z|tar|tar\.gz|lzma|xz|cbz|cbr|cb7|cbt|pdf|epub|tar\.zst|zst)$/i;
}

sub is_chapter {
    return $_[0] =~ /^.+\/chapter[^\/]+$/i;
}

# Returns a human-readable title for the given ID (archive or tank).
sub get_item_title {
    my ($id) = @_;
    if ( $id =~ /^TANK/ ) {
        require LANraragi::Model::Tankoubon;
        my %tank = LANraragi::Model::Tankoubon::get_tankoubon($id);
        return $tank{name} // "";
    } else {
        require LANraragi::Model::Archive;
        return LANraragi::Model::Archive::get_title($id) // "";
    }
}

# Renders the basic success API JSON template, where the $mojo object inherits the openapi controller.
# Specifying an error message argument will set the success variable to 0.
sub render_api_response {
    my ( $mojo, $operation, $errormessage, $successMessage ) = @_;
    my $failed = ( defined $errormessage );

    $mojo->render(
        openapi => {
            operation      => $operation,
            error          => $failed ? xml_escape($errormessage) : "",
            success        => $failed ? 0                         : 1,
            successMessage => $failed ? ""                        : xml_escape($successMessage),
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

    if (IS_UNIX) {
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
    } else {
        my $proc;
        Win32::Process::Create( $proc, undef, "perl \"" . abs_path(".") . "/lib/Worker.pm\"", 0, NORMAL_PRIORITY_CLASS, "." );
        $logger->info( "Starting new Minion worker with PID " . $proc->GetProcessID() . "." );
        return $proc;
    }
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
    if (IS_UNIX) {
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
    } else {
        my $proc;
        Win32::Process::Create( $proc, undef, "perl \"" . abs_path(".") . "/lib/Shinobu.pm\"", 0, NORMAL_PRIORITY_CLASS, "." );
        open( my $fh, ">", get_temp() . "/shinobu.pid-s6" );
        print $fh $proc->GetProcessID();
        close($fh);
        $mojo->LRR_LOGGER->debug( "Shinobu Worker new PID is " . $proc->GetProcessID() );
        return $proc;
    }
}

sub start_tsubasa {
    my $mojo = shift;
    if (IS_UNIX) {
        my $proc = Proc::Simple->new();
        $proc->start( $^X, "./lib/Tsubasa.pm" );
        $proc->kill_on_destroy(0);

        $mojo->LRR_LOGGER->debug( "Tsubasa Worker new PID is " . $proc->pid );

        # Freeze the process object in the PID file
        store \$proc, get_temp() . "/tsubasa.pid";
        open( my $fh, ">", get_temp() . "/tsubasa.pid-s6" );
        print $fh $proc->pid;
        close($fh);
        return $proc;
    } else {
        my $proc;
        Win32::Process::Create( $proc, undef, "perl \"" . abs_path(".") . "/lib/Tsubasa.pm\"", 0, NORMAL_PRIORITY_CLASS, "." );
        open( my $fh, ">", get_temp() . "/tsubasa.pid-s6" );
        print $fh $proc->GetProcessID();
        close($fh);
        $mojo->LRR_LOGGER->debug( "Tsubasa Worker new PID is " . $proc->GetProcessID() );
        return $proc;
    }
}

#This function gives us a SHA hash for the passed data, which is used for thumbnail reverse search on E-H.
#First argument is the data, second is the algorithm to use. (1, 224, 256, 384, 512, 512224, or 512256)
#E-H only uses SHA-1 hashes.
sub shasum_str {

    my $digest = "";
    my $logger = get_logger( "Hash Computation", "lanraragi" );

    eval {
        my $ctx = Digest::SHA->new( $_[1] );
        $ctx->add( $_[0] );
        $digest = $ctx->hexdigest;
    };

    if ($@) {
        $logger->error( "Error building hash for " . $_[0] . " -- " . $@ );

        return "";
    }

    return $digest;
}

sub get_css_list {

    # Get all the available CSS sheets.
    my @css;
    opendir( my $dir, "./public/themes" ) or die $!;
    while ( my $file = readdir($dir) ) {
        if ( $file =~ /.+\.css/ ) { push( @css, $file ); }
    }
    closedir($dir);

    return @css;
}

# Craft list of css objects based on the available themes
sub generate_css_detail {

    my @css_list;

    foreach my $css_file (get_css_list) {

        my ( $css_name, $css_color ) = css_default_data($css_file);
        my $id = $css_file =~ s/\.css//gr;    # Strip extension for ID

        my $preview = "/img/theme_preview/$id.png";

        # Fallback for nonexisting previews
        unless ( -e "public$preview" ) {
            $preview = "/img/flubbed.gif";
        }

        my $css_info = {
            id      => $id,
            file    => $css_file,
            name    => $css_name,
            color   => $css_color,
            preview => $preview
        };

        push @css_list, $css_info;
    }

    return \@css_list;
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
        my $css_url = $self->url_for("/themes/$css_file?$version");

        # If this is the default sheet, set it up as so.
        if ( $css[$i] eq LANraragi::Model::Config->get_style ) {

            $html .= qq(<link rel="stylesheet" type="text/css" title="$css_name" href="$css_url">);

            # Add the main color as a theme-color meta tag
            $html .= qq(<meta name="theme-color" content="$css_color">);
        } else {
            $html .= qq(<link rel="alternate stylesheet" type="text/css" title="$css_name" href="$css_url">);
        }
    }

    return $html;
}

# Assign a name and an accent color to the css file passed. You can add names by adding cases.
# Note: CSS files added to the /themes folder will ALWAYS be pickable by the users no matter what.
# All this sub does is give .css files prettier names in the dropdown. Files without a name here will simply show as their filename to the users.
sub css_default_data {
    if    ( $_[0] eq "g.css" )            { return ( "H-Verse",   "#5F0D1F" ) }
    elsif ( $_[0] eq "modern.css" )       { return ( "Hachikuji", "#34353B" ) }
    elsif ( $_[0] eq "modern_clear.css" ) { return ( "Yotsugi",   "#34495E" ) }
    elsif ( $_[0] eq "modern_red.css" )   { return ( "Nadeko",    "#D83B66" ) }
    elsif ( $_[0] eq "ex.css" )           { return ( "Sad Panda", "#43464E" ) }
    else                                  { return ( $_[0],       "#34353B" ) }
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

# intersect_arrays(@array1, @array2, $isneg)
# Intersect two arrays and return the result. If $isneg is true, return the difference instead.
sub intersect_arrays {

    my ( $array1, $array2, $isneg ) = @_;

    # If array1 is empty, just return an empty array or the second array if $isneg is true
    if ( scalar @$array1 == 0 ) {
        return $isneg ? @$array2 : ();
    }

    # If array2 is empty, die since this sub shouldn't even be used in that case
    if ( scalar @$array2 == 0 ) {
        die "intersect_arrays called with an empty array2";
    }

    my %hash = map { $_ => 1 } @$array1;
    my @result;

    if ($isneg) {
        @result = grep { !exists $hash{$_} } @$array2;
    } else {
        @result = grep { exists $hash{$_} } @$array2;
    }

    return @result;
}

sub filter_hash_by_keys {

    my ( $allowed_keys, %hash ) = @_;

    # Convert the array of allowed keys into a hash for quick lookup
    my %allowed_keys_hash = map { $_ => 1 } @$allowed_keys;

    # Iterate over the keys in the hash and delete those not in the allowed keys
    foreach my $key ( keys %hash ) {
        delete $hash{$key} unless exists $allowed_keys_hash{$key};
    }

    return %hash;
}

# TODO: Probably rename to exec_with_lock_render
# Execute a function under a redis lock context.
# If the lock cannot be acquired, renders a 423 error and returns false,
# otherwise executes the function and returns true (or rethrows error if any).
# Automatically cleans up the lock and connection after execution.
sub exec_with_lock {

    my ( $mojo, $lock_name, $operation, $resource_id, $func ) = @_;

    my ( $acquired, $response ) = exec_with_lock_pure( [$lock_name], $func );

    if ( !$acquired ) {
        $mojo->render(
            json => {
                operation => $operation,
                success   => 0,
                error     => "Locked resource: $resource_id."
            },
            status => 423
        );
        return 0;
    }

    return 1;

}

# TODO: Probably rename to exec_with_lock
# exec_with_lock_pure( \@lock_names, $func, $redis (optional), $ttl (optional) )
# Execute a function under a multi-lock context.
# Does not implement lock_name sorting,
# so locks should be passed in a deterministic order to avoid deadlocking.
# For high-level, fast operations, as the expiry defaults to 10s.
# Returns a tuple ($acquired, $response), where $response is
# function response (if any) if acquired, or undef if not acquired.
# Redis connection is optional; if not supplied, a managed connection will be created.
sub exec_with_lock_pure {

    my $lock_names = shift;
    my $func       = shift;
    my $redis      = shift;
    my $ttl        = shift // 10;
    my $own_redis  = 0;

    die "Lock name list cannot be empty" unless scalar(@$lock_names);

    # prepare the script for token release
    # tokens demonstrate ownership over a redis lock, and is used to prevent workers
    # from deleting locks that don't belong to them.
    # https://redis.io/docs/latest/develop/clients/patterns/distributed-locks/#correct-implementation-with-a-single-instance
    my $release_lua = <<'LUA';
    if redis.call('GET', KEYS[1]) == ARGV[1] then
        return redis.call('DEL', KEYS[1])
    end
    return 0
LUA

    # create managed redis connection if not passed
    unless ( defined $redis ) {
        $redis     = LANraragi::Model::Config->get_redis_config;
        $own_redis = 1;
    }

    # try to acquire all locks, or release all if any lock cannot be acquired.
    my @lock_name_stack = ();
    foreach my $lock_name (@$lock_names) {
        my $token = sha256_hex( $lock_name . ":" . $$ . ":" . time() . ":" . rand() );
        my $lock  = eval { $redis->set( $lock_name, $token, 'NX', 'EX', $ttl ) };
        if ( my $acquire_error = $@ ) {

            # If a lock acquisition failure happens, then a problem has occurred with Redis.
            get_logger( "Concurrency", "lanraragi" )->error("Failed to acquire lock $lock_name: $acquire_error");
            last;
        }
        last unless $lock;
        push( @lock_name_stack, [ $lock_name, $token ] );
    }

    # if a single lock fails to acquire, stop trying for the rest, and
    # go release all previously acquired locks in the reverse order.
    unless ( scalar(@lock_name_stack) == scalar(@$lock_names) ) {
        while (@lock_name_stack) {
            my ( $lock_name, $token ) = @{ pop(@lock_name_stack) };

            # This should be best effort release, but if failure happens,
            # then continue releasing remaining locks and let TTL take over.
            my $release_error = eval { $redis->eval( $release_lua, 1, $lock_name, $token ); 1 } ? undef : $@;
            get_logger( "Concurrency", "lanraragi" )->error("Failed to release lock ($lock_name): $release_error")
              if $release_error;
        }
        if ($own_redis) {
            my $close_error = eval { $redis->quit(); 1 } ? undef : $@;
            get_logger( "Concurrency", "lanraragi" )->error("Failed to close Redis connection: $close_error") if $close_error;
        }
        return 0, undef;
    }

    # run the actual business logic (and collect response)
    my $response = eval { $func->(); };
    my $fn_err   = $@;

    # release all previously acquired locks in reverse order.
    while (@lock_name_stack) {
        my ( $lock_name, $token ) = @{ pop(@lock_name_stack) };
        my $release_error = eval { $redis->eval( $release_lua, 1, $lock_name, $token ); 1 } ? undef : $@;
        get_logger( "Concurrency", "lanraragi" )->error("Failed to release lock after evaluation ($lock_name): $release_error")
          if $release_error;
    }

    # close managed connection
    my $close_error = eval { $redis->quit() if $own_redis; 1 } ? undef : $@;
    get_logger( "Concurrency", "lanraragi" )->error("Failed to close Redis connection after evaluation: $close_error")
      if $close_error;

    # throw error if exists
    die $fn_err if $fn_err;
    return 1, $response;

}

sub get_version {
    # Load package.json to get version/vername/description
    $version_info = decode_json( Mojo::File->new('package.json')->slurp ), shift unless $version_info;
    return $version_info;
}

1;
