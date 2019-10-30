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
    "/blueimp-file-upload/css/jquery.fileupload.css",
    "/datatables/media/css/jquery.dataTables.min.css",
    "/\@fortawesome/fontawesome-free/css/all.min.css",
    "/jqcloud2/dist/jqcloud.min.css",
    "/jquery-toast-plugin/dist/jquery.toast.min.css",
    "/jquery-contextmenu/dist/jquery.contextMenu.min.css",
    "/qtip2/dist/jquery.qtip.min.css",
    "/allcollapsible/dist/css/allcollapsible.min.css",
    "/awesomplete/awesomplete.css"
);

my @vendor_js = (
    "/blueimp-file-upload/js/jquery.fileupload.js",
    "/blueimp-file-upload/js/vendor/jquery.ui.widget.js",
    "/datatables/media/js/jquery.dataTables.min.js",
    "/jqcloud2/dist/jqcloud.min.js",
    "/jquery/dist/jquery.min.js",
    "/jquery-migrate/dist/jquery-migrate.min.js",
    "/jquery-toast-plugin/dist/jquery.toast.min.js",
    "/jquery-contextmenu/dist/jquery.ui.position.min.js",
    "/jquery-contextmenu/dist/jquery.contextMenu.min.js",
    "/qtip2/dist/jquery.qtip.min.js",
    "/allcollapsible/dist/js/allcollapsible.min.js",
    "/awesomplete/awesomplete.min.js"
);

my @vendor_woff = (
    "/\@fortawesome/fontawesome-free/webfonts/fa-solid-900.woff",
    "/open-sans-fontface/fonts/Regular/OpenSans-Regular.woff",
    "/open-sans-fontface/fonts/Bold/OpenSans-Bold.woff",
    "/roboto-fontface/fonts/roboto/Roboto-Regular.woff",
    "/roboto-fontface/fonts/roboto/Roboto-Bold.woff",
    "/inter-ui/Inter (web)/Inter-Regular.woff",
    "/inter-ui/Inter (web)/Inter-Bold.woff"
);

say(
"⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⣠⣴⣶⣿⠿⠟⠛⠓⠒⠤"
);
say("⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⣠⣾⣿⡟⠋");
say("⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢰⣿⣿⠋");
say("⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⣿⣿⠇⡀");
say("⢀⢀⢀⢀⢀⢀⢀⢀⢀⣀⣤⡆⢿⣿⢀⢿⣷⣦⣄⣀");
say("⢀⢀⢀⢀⢀⢀⢀⣶⣿⠿⠛⠁⠈⢻⡄⢀⠈⠙⠻⢿⣿⣆");
say("⢀⢀⢀⢀⢀⢀⢸⣿⣿⣶⣤⣀⢀⢀⢀⢀⢀⣀⣤⣶⣿⣿");
say("⢀⢀⢀⢀⢀⢀⢸⣿⣿⣿⣿⣿⣿⣶⣤⣶⣿⠿⠛⠉⣿⣿");
say("⢀⢀⢀⢀⢀⢀⢸⣿⣿⣿⣿⣿⣿⣿⣿⠉⢀⢀⢀⢀⣿⣿");
say(
"⢀⢀⢀⢀⣀⣤⣾⣿⣿⣿⣿⣿⣿⣿⣿⢀⢀⢀⣠⣴⣿⣿⣦⣄⡀"
);
say(
"⢀⣤⣶⣿⠿⠟⠉⢀⠉⠛⠿⣿⣿⣿⣿⣴⣾⡿⠿⠋⠁⠈⠙⠻⢿⣷⣦⣄"
);
say(
"⣿⣿⣯⣅⢀⢀⢀⢀⢀⢀⢀⣀⣭⣿⣿⣿⣍⡀⢀⢀⢀⢀⢀⢀⢀⣨⣿⣿⡇"
);
say(
"⣿⣿⣿⣿⣿⣶⣤⣀⣤⣶⣿⡿⠟⢹⣿⣿⣿⣿⣷⣦⣄⣠⣴⣾⡿⠿⠋⣿⡇"
);
say(
"⣿⣿⣿⣿⣿⣿⣿⣿⡟⠋⠁⢀⢀⢸⣿⣿⣿⣿⣿⣿⣿⣿⠛⠉⢀⢀⢀⣿⡇"
);
say(
"⣿⣿⣿⣿⣿⣿⣿⣿⡇⢀⢀⢀⢀⣸⣿⣿⣿⣿⣿⣿⣿⣿⢀⢀⢀⢀⢀⣿⡇"
);
say(
"⠙⢿⣿⣿⣿⣿⣿⣿⡇⢀⣠⣴⣿⡿⠿⣿⣿⣿⣿⣿⣿⣿⢀⣀⣤⣾⣿⠟⠃"
);
say(
"⢀⢀⠈⠙⠿⣿⣿⣿⣷⣿⠿⠛⠁⢀⢀⢀⠉⠻⢿⣿⣿⣿⣾⡿⠟⠉"
);
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

#Load IPC::Cmd
install_package("IPC::Cmd");
IPC::Cmd->import('can_run');

say("\r\nWill now check if all LRR software dependencies are met. \r\n");

#Check for Redis
say("Checking for Redis...");
can_run('redis-server')
  or die 'NOT FOUND! Please install a Redis server before proceeding.';
say("OK!");

#Build & Install CPAN Dependencies
if ( $back || $full ) {
    say("Ensure you have libarchive/libjpeg/libpng installed or this will fail!"
    );
    say("\r\nInstalling Perl modules... This might take a while.\r\n");

    # libarchive is not provided by default on macOS, so we have to set the correct env vars
    # to successfully compile Archive::Extract::Libarchive and Archive::Peek::Libarchive
    my $pre = "";
    if ($Config{"osname"} eq "darwin") {
        say("Setting Environmental Flags for macOS");
        $pre = "export CFLAGS=\"-I/usr/local/opt/libarchive/include\" && \\
          export PKG_CONFIG_PATH=\"/usr/local/opt/libarchive/lib/pkgconfig\" && ";
    } else {
        say("Installing Linux::Inotify2 for non-macOS systems...");
        install_package("Linux::Inotify2");
    }
    # provide cpanm with the correct module installation dir when using Homebrew
    my $suff = "";
    if ($ENV{HOMEBREW_FORMULA_PREFIX}) {
      $suff = " -l " . $ENV{HOMEBREW_FORMULA_PREFIX} . "/libexec";
    }

    if ( system($pre . "cpanm --installdeps ./tools/. --notest" . $suff) != 0 ) {
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
    copy(
        getcwd . "/public/css/vendor/all.min.css",
        getcwd . "/public/css/vendor/fontawesome-all.min.css"
    );

    for my $js (@vendor_js) {
        cp_node_module( $js, "/public/js/vendor/" );
    }

    for my $woff (@vendor_woff) {
        cp_node_module( $woff, "/public/css/webfonts/" );
    }

}

#Done!
say("\r\nAll set! You can start LANraragi by typing the command: \r\n");
say(
"   ╭─────────────────────────────────────╮"
);
say("   │                                     │");
say("   │              npm start              │");
say("   │                                     │");
say(
"   ╰─────────────────────────────────────╯"
);

sub cp_node_module {

    my ( $item, $newpath ) = @_;

    my $nodename = getcwd . "/node_modules" . $item;
    $item =~ /([^\/]+$)/;
    my $newname = getcwd . $newpath . $&;

    say("Copying $nodename \r\n to $newname \r\n");
    copy( $nodename, $newname ) or die "The copy operation failed: $!";

}

sub install_package {

    my $package = $_[0];

    ## no critic
    eval "require $package"
      ; #Run-time evals are needed here to check if the package has been properly installed.
    ## use critic

    if ($@) {
        say("$package not installed! Trying to install now using cpanm.");
        system("cpanm $package");
        require $package;
    }
    else {
        say("$package package installed, proceeding...");
    }

}
