#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use open ':std', ':encoding(UTF-8)';
use Cwd;
use Config;

use feature qw(say);
use File::Path qw(make_path);

#Vendor dependencies
my @vendor_css = (
    "/blueimp-file-upload/css/jquery.fileupload.css",      "/\@fortawesome/fontawesome-free/css/all.min.css",
    "/jqcloud2/dist/jqcloud.min.css",                      "/react-toastify/dist/ReactToastify.min.css",
    "/jquery-contextmenu/dist/jquery.contextMenu.min.css", "/tippy.js/dist/tippy.css",
    "/allcollapsible/dist/css/allcollapsible.min.css",     "/awesomplete/awesomplete.css",
    "/\@jcubic/tagger/tagger.css",                         "/swiper/swiper-bundle.min.css",
    "/sweetalert2/dist/sweetalert2.min.css",
);

my @vendor_js = (
    "/blueimp-file-upload/js/jquery.fileupload.js",       "/blueimp-file-upload/js/vendor/jquery.ui.widget.js",
    "/datatables.net/js/jquery.dataTables.min.js",        "/jqcloud2/dist/jqcloud.min.js",
    "/jquery/dist/jquery.min.js",                         "/react-toastify/dist/react-toastify.umd.js",
    "/jquery-contextmenu/dist/jquery.ui.position.min.js", "/jquery-contextmenu/dist/jquery.contextMenu.min.js",
    "/tippy.js/dist/tippy-bundle.umd.min.js",             "/\@popperjs/core/dist/umd/popper.min.js",
    "/allcollapsible/dist/js/allcollapsible.min.js",      "/awesomplete/awesomplete.min.js",
    "/\@jcubic/tagger/tagger.js",                         "/marked/marked.min.js",
    "/swiper/swiper-bundle.min.js",                       "/preact/dist/preact.umd.js",
    "/clsx/dist/clsx.min.js",                             "/preact/compat/dist/compat.umd.js",
    "/preact/hooks/dist/hooks.umd.js",                    "/sweetalert2/dist/sweetalert2.min.js",
    "/fscreen/dist/fscreen.esm.js"
);

my @vendor_woff = (
    "/\@fortawesome/fontawesome-free/webfonts/fa-solid-900.woff2",
    "/\@fortawesome/fontawesome-free/webfonts/fa-regular-400.woff2",
    "/open-sans-fontface/fonts/Regular/OpenSans-Regular.woff",
    "/open-sans-fontface/fonts/Bold/OpenSans-Bold.woff",
    "/roboto-fontface/fonts/roboto/Roboto-Regular.woff",
    "/roboto-fontface/fonts/roboto/Roboto-Bold.woff",
    "/inter-ui/Inter (web)/Inter-Regular.woff",
    "/inter-ui/Inter (web)/Inter-Bold.woff",
);

say("⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⣠⣴⣶⣿⠿⠟⠛⠓⠒⠤");
say("⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⣠⣾⣿⡟⠋");
say("⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢰⣿⣿⠋");
say("⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⣿⣿⠇⡀");
say("⢀⢀⢀⢀⢀⢀⢀⢀⢀⣀⣤⡆⢿⣿⢀⢿⣷⣦⣄⣀");
say("⢀⢀⢀⢀⢀⢀⢀⣶⣿⠿⠛⠁⠈⢻⡄⢀⠈⠙⠻⢿⣿⣆");
say("⢀⢀⢀⢀⢀⢀⢸⣿⣿⣶⣤⣀⢀⢀⢀⢀⢀⣀⣤⣶⣿⣿");
say("⢀⢀⢀⢀⢀⢀⢸⣿⣿⣿⣿⣿⣿⣶⣤⣶⣿⠿⠛⠉⣿⣿");
say("⢀⢀⢀⢀⢀⢀⢸⣿⣿⣿⣿⣿⣿⣿⣿⠉⢀⢀⢀⢀⣿⣿");
say("⢀⢀⢀⢀⣀⣤⣾⣿⣿⣿⣿⣿⣿⣿⣿⢀⢀⢀⣠⣴⣿⣿⣦⣄⡀");
say("⢀⣤⣶⣿⠿⠟⠉⢀⠉⠛⠿⣿⣿⣿⣿⣴⣾⡿⠿⠋⠁⠈⠙⠻⢿⣷⣦⣄");
say("⣿⣿⣯⣅⢀⢀⢀⢀⢀⢀⢀⣀⣭⣿⣿⣿⣍⡀⢀⢀⢀⢀⢀⢀⢀⣨⣿⣿⡇");
say("⣿⣿⣿⣿⣿⣶⣤⣀⣤⣶⣿⡿⠟⢹⣿⣿⣿⣿⣷⣦⣄⣠⣴⣾⡿⠿⠋⣿⡇");
say("⣿⣿⣿⣿⣿⣿⣿⣿⡟⠋⠁⢀⢀⢸⣿⣿⣿⣿⣿⣿⣿⣿⠛⠉⢀⢀⢀⣿⡇");
say("⣿⣿⣿⣿⣿⣿⣿⣿⡇⢀⢀⢀⢀⣸⣿⣿⣿⣿⣿⣿⣿⣿⢀⢀⢀⢀⢀⣿⡇");
say("⠙⢿⣿⣿⣿⣿⣿⣿⡇⢀⣠⣴⣿⡿⠿⣿⣿⣿⣿⣿⣿⣿⢀⣀⣤⣾⣿⠟⠃");
say("⢀⢀⠈⠙⠿⣿⣿⣿⣷⣿⠿⠛⠁⢀⢀⢀⠉⠻⢿⣿⣿⣿⣾⡿⠟⠉");
say("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
say("~~~~~LANraragi Installer~~~~~");
say("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");

unless ( @ARGV > 0 ) {
    say("Execution: npm run lanraragi-installer [mode]");
    say("--------------------------");
    say("Available modes are: ");
    say("* install-front: Install/Update Clientside dependencies.");
    say("* install-back: Install/Update Perl dependencies.");
    say("* install-full: Install/Update all dependencies.");
    say("");
    say("If installing from source, please use install-full.");
    exit;
}

my $front = $ARGV[0] eq "install-front";
my $back  = $ARGV[0] eq "install-back";
my $full  = $ARGV[0] eq "install-full";

say( "Working Directory: " . getcwd );
say("");

# Provide cpanm with the correct module installation dir when using Homebrew
my $cpanopt = "";
if ( $ENV{HOMEBREW_FORMULA_PREFIX} ) {
    $cpanopt = " -l " . $ENV{HOMEBREW_FORMULA_PREFIX} . "/libexec";
}

#Load IPC::Cmd
install_package( "IPC::Cmd",         $cpanopt );
install_package( "Config::AutoConf", $cpanopt );
IPC::Cmd->import('can_run');
require Config::AutoConf;

say("\r\nWill now check if all LRR software dependencies are met. \r\n");

#Check for Redis
say("Checking for Redis...");
can_run('redis-server')
  or die 'NOT FOUND! Please install a Redis server before proceeding.';
say("OK!");

#Check for GhostScript
say("Checking for GhostScript...");
can_run('gs')
  or warn 'NOT FOUND! PDF support will not work properly. Please install the "gs" tool.';
say("OK!");

#Check for libarchive
say("Checking for libarchive...");
Config::AutoConf->new()->check_header("archive.h")
  or die 'NOT FOUND! Please install libarchive and ensure its headers are present.';
say("OK!");

#Check for PerlMagick
say("Checking for ImageMagick/PerlMagick...");
my $imgk;

eval {
    require Image::Magick;
    $imgk = Image::Magick->QuantumDepth;
};

if ($@) {
    say("NOT FOUND");
    say("Please install ImageMagick with Perl for thumbnail support.");
    say("Further instructions are available at https://www.imagemagick.org/script/perl-magick.php .");
    say("The ImageMagick detection command returned: $imgk -- $@");
} else {
    say( "Returned QuantumDepth: " . $imgk );
    say("OK!");
}

#Build & Install CPAN Dependencies
if ( $back || $full ) {
    say("\r\nInstalling Perl modules... This might take a while.\r\n");

    if ( $Config{"osname"} ne "darwin" ) {
        say("Installing Linux::Inotify2 (2.2) for non-macOS systems...");

        # Install 2.2 explicitly as 2.3 doesn't work properly on WSL
        eval { system("cpanm https://cpan.metacpan.org/authors/id/M/ML/MLEHMANN/Linux-Inotify2-2.2.tar.gz $cpanopt --reinstall"); }

          if ($@) {
            die "Something went wrong while installing Linux::Inotify2 - Bailing out.";
        }
    }

    if ( system( "cpanm --installdeps ./tools/. --notest" . $cpanopt ) != 0 ) {
        die "Something went wrong while installing Perl modules - Bailing out.";
    }
}

#Clientside Dependencies with Provisioning
if ( $front || $full ) {

    say("\r\nObtaining remote Web dependencies...\r\n");

    if ( system("npm install") != 0 ) {
        die "Something went wrong while obtaining node modules - Bailing out.";
    }

    say("\r\nProvisioning...\r\n");

    #Load File::Copy
    install_package("File::Copy");
    File::Copy->import("copy");

    make_path getcwd . "/public/css/vendor";
    make_path getcwd . "/public/css/webfonts";
    make_path getcwd . "/public/js/vendor";

    for my $css (@vendor_css) {
        cp_node_module( $css, "/public/css/vendor/" );
    }

    #Rename the fontawesome css to something a bit more explanatory
    copy( getcwd . "/public/css/vendor/all.min.css", getcwd . "/public/css/vendor/fontawesome-all.min.css" );

    for my $js (@vendor_js) {
        cp_node_module( $js, "/public/js/vendor/" );
    }

    for my $woff (@vendor_woff) {
        cp_node_module( $woff, "/public/css/webfonts/" );
    }

}

#Done!
say("\r\nAll set! You can start LANraragi by typing the command: \r\n");
say("   ╭─────────────────────────────────────╮");
say("   │                                     │");
say("   │              npm start              │");
say("   │                                     │");
say("   ╰─────────────────────────────────────╯");

sub cp_node_module {

    my ( $item, $newpath ) = @_;

    my $nodename = getcwd . "/node_modules" . $item;
    $item =~ /([^\/]+$)/;
    my $newname     = getcwd . $newpath . $&;
    my $nodemapname = $nodename . ".map";
    my $newmapname  = $newname . ".map";

    say("\r\nCopying $nodename \r\n to $newname");
    copy( $nodename, $newname ) or die "The copy operation failed: $!";

    my $mapresult = copy( $nodemapname, $newmapname ) and say("Copied sourcemap file.\r\n");

}

sub install_package {

    my $package = $_[0];
    my $cpanopt = $_[1];

    ## no critic
    eval "require $package";    #Run-time evals are needed here to check if the package has been properly installed.
    ## use critic

    if ($@) {
        say("$package not installed! Trying to install now using cpanm$cpanopt");
        system("cpanm $package $cpanopt");
    } else {
        say("$package package installed, proceeding...");
    }
}
