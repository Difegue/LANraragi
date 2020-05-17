package LANraragi::Utils::Generic;

use strict;
use warnings;
use utf8;
use feature "switch";
no warnings 'experimental';

use Storable qw(store lock_retrieve);
use Digest::SHA qw(sha256_hex);
use Mojo::Log;
use Logfile::Rotate;
use Proc::Simple;

use LANraragi::Utils::Logging qw(get_logger);

# Generic Utility Functions.
use Exporter 'import';
our @EXPORT_OK = qw(remove_spaces remove_newlines is_image success get_tag_with_namespace shasum start_shinobu
  get_css_list generate_themes_header generate_themes_selector);

# Remove spaces before and after a word
sub remove_spaces {
    $_[0] =~ s/^\s+|\s+$//g;
}

# Remove all newlines in a string
sub remove_newlines {
    $_[0] =~ s/\R//g;
}

# Checks if the provided file is an image.
# WARNING: This modifies the given filename variable!
sub is_image {
    return $_[0] =~ /^.+\.(png|jpg|gif|bmp|jpeg|jfif|webp|PNG|JPG|GIF|BMP|JPEG|JFIF|WEBP)$/;
}

# Renders the basic success API JSON template.
sub success {
    my ( $mojo, $operation ) = @_;

    $mojo->render(
        json => {
            operation => $operation,
            success   => 1
        }
    );
}

# Find the first tag matching the given namespace, or return the default value.
sub get_tag_with_namespace {
    my ( $namespace, $tags, $default ) = @_;
    my @values = split( ',', $tags );

    foreach my $tag (@values) {
        my ( $namecheck, $value ) = split( ':', $tag );
        remove_spaces($namecheck);
        remove_spaces($value);

        if ( $namecheck eq $namespace ) {
            return $value;
        }
    }

    return $default;
}

#Start Shinobu and return its Proc::Background object.
sub start_shinobu {
    my $logger = get_logger( "Shinobu Boot", "lanraragi" );

    my $proc = Proc::Simple->new();
    $proc->start( $^X, "./lib/Shinobu.pm" );
    $proc->kill_on_destroy(0);

    # Freeze the process object in the PID file
    store \$proc, '.shinobu-pid';
    return $proc;
}

# Retrieve the Shinobu filemap, serialized to a file.
sub get_shinobu_filemap {
    if ( -e "./.shinobu-filemap" ) {
        return %{ lock_retrieve("./.shinobu-filemap") };
    } else {
        return;
    }
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
    opendir( DIR, "./public/themes" ) or die $!;
    while ( my $file = readdir(DIR) ) {
        if ( $file =~ /.+\.css/ ) { push( @css, $file ); }
    }
    closedir(DIR);

    return @css;
}

#Print a dropdown list to select CSS, and adds <link> tags for all the style sheets present in the /style folder.
sub generate_themes_header {

    my $self = shift;
    my @css  = get_css_list;

    #html that we'll insert in the header to declare all the available styles.
    my $html = "";

    #Go through the css files
    for ( my $i = 0; $i < $#css + 1; $i++ ) {

        my $css_name = css_default_names( $css[$i] );

        #if this is the default sheet, set it up as so.
        if ( $css[$i] eq LANraragi::Model::Config->get_style ) {

            $html =
                $html
              . '<link rel="stylesheet" type="text/css" title="'
              . $css_name
              . '" href="/themes/'
              . $css[$i] . '?'
              . $self->LRR_VERSION . '"> ';
        } else {

            $html =
                $html
              . '<link rel="alternate stylesheet" type="text/css" title="'
              . $css_name
              . '" href="/themes/'
              . $css[$i] . '?'
              . $self->LRR_VERSION . '"> ';
        }
    }

    return $html;

}

sub generate_themes_selector {

    my @css    = get_css_list;
    my $CSSsel = '<div>';

    #Go through the css files
    for ( my $i = 0; $i < $#css + 1; $i++ ) {

        #populate the div with buttons
        my $css_name = css_default_names( $css[$i] );
        $CSSsel =
            $CSSsel
          . '<input class="stdbtn" type="button" onclick="switch_style(\''
          . $css_name
          . '\');" value="'
          . $css_name . '"/>';
    }

    #close up div
    $CSSsel = $CSSsel . '</div>';

    return $CSSsel;
}

#Assign a name to the css file passed. You can add names by adding cases.
#Note: CSS files added to the /themes folder will ALWAYS be pickable by the users no matter what.
#All this sub does is give .css files prettier names in the dropdown. Files without a name here will simply show as their filename to the users.
sub css_default_names {
    given ( $_[0] ) {
        when ("g.css")            { return "HentaiVerse" }
        when ("modern.css")       { return "Hachikuji" }
        when ("modern_clear.css") { return "Yotsugi" }
        when ("modern_red.css")   { return "Nadeko" }
        when ("ex.css")           { return "Sad Panda" }
        default                   { return $_[0] }
    }
}

1;
