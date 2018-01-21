#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use Cwd;

use local::lib;
use feature qw(say);

#Vendor dependencies
my @vendor_css =("/blueimp-file-upload/css/jquery.fileupload.css",
                 "/datatables/media/css/jquery.dataTables.min.css",
                 "/fontawesome-web/css/fontawesome-all.min.css",
                 "/jb-dropit/dropit.css",
                 "/jqcloud2/dist/jqcloud.min.css",
                 "/jquery-toast-plugin/dist/jquery.toast.min.css");

my @vendor_js = ("/blueimp-file-upload/js/jquery.fileupload.js",
                 "/blueimp-file-upload/js/vendor/jquery.ui.widget.js",
                 "/datatables/media/js/jquery.dataTables.min.js",
                 "/jb-dropit/dropit.js",
                 "/jqcloud2/dist/jqcloud.min.js",
                 "/jquery/dist/jquery.min.js",
                 "/jquery-toast-plugin/dist/jquery.toast.min.js");

my @vendor_woff=("/fontawesome-web/webfonts/fa-solid-900.woff",
                 "/open-sans-fontface/fonts/Regular/OpenSans-Regular.woff",
                 "/open-sans-fontface/fonts/Bold/OpenSans-Bold.woff",
                 "/roboto-fontface/fonts/roboto/Roboto-Regular.woff",
                 "/roboto-fontface/fonts/roboto/Roboto-Bold.woff");


say("             . .. .     MMMMMMMM........");
say("             . .. . MMMMMM. ....MM .....");
say("......            MMMMM.    . .      .  ");
say("   .           MMMM         ....   . .. ");
say(" .....        NMMM.MMM      ...    . .. ");
say("......     MMMM MM  MMMMMM  ...... .... ");
say("......   MMMM ...MM.....MMMMM...........");
say(" .      MMMMM .   ....   MMMM.          ");
say("   .    MMMMMMMM  ...MMMMMMMM           ");
say("   .    MMMMMMMMMMMMMMM~..MMM           ");
say(" . .    MMMMMMMMMMMM.. ...MMM. .        ");
say("   .    MMMMMMMMMMMM    . MMM.          ");
say("   ..MMMMMMMMMMMMMMM...MMMMMMMMM   .....");
say(" MMMMMM,    MMMMMMMMMMMMM .   MMMMMM    ");
say("MMMM          .MMMMMMM  . .      MMMMM  ");
say("MMMMMZ       ~MMMMMMMMMZ...     MMMMMM  ");
say("MMMMMMMMM MMMMMM.MMMMMMMMMM.MMMMMM MMM  ");
say("MMMMMMMMMMMMD .  MMMMMMMMMMMMMD    MMM  ");
say("MMMMMMMMMMM  ....MMMMMMMMMMMM. .   MMM  ");
say("MMMMMMMMMMM   .  MMMMMMMMMMMM      MMM  ");
say("MMMMMMMMMMM   7MMMMMMMMMMMMMM   7MMMM   ");
say("  .MMMMMMMMMMMMM8 .. MMMMMMMMMMMMMM.    ");
say("   .  MMMMMMMM.   ....  MMMMMMMM        ");
say("   .    .M+   .   .... ... MM           ");
say("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
say("~~~~~~~~~~~LANraragi Installer~~~~~~~~~~");
say("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");

unless (@ARGV > 0 ) {
  say ("Execution: npm run lanraragi-installer [mode]");
  say ("--------------------------");
  say ("Available modes are: ");
  say ("* install-front: Install/Update Clientside dependencies.");
  say ("* install-back: Install/Update Perl dependencies.");
  say ("* install-full: Install/Update all dependencies.");
  say ("");
  say ("If using a prepackaged release, you probably only need install-back.");
  exit;
}

my $front = $ARGV[0] eq "install-front";
my $back = $ARGV[0] eq "install-back";
my $full = $ARGV[0] eq "install-full";

say("Working Directory: ".getcwd);
say("");

#Load IPC::Cmd
install_package("IPC::Cmd");
IPC::Cmd->import( 'can_run' );

say ("\r\nWill now check if all LRR software dependencies are met. \r\n");

#Check for Redis
print ("Checking for Redis...");
can_run('redis-server') or die 'NOT FOUND! \r\n Please install a Redis server before proceeding.';
say ("OK!");

#Check for unar
print ("Checking for unar...");
can_run('unar') or die 'NOT FOUND! \r\n Please install unar before proceeding.';
say ("OK!");

#Check for PerlMagick
print ("Checking for ImageMagick/PerlMagick...");

my $imgk = `perl -MImage::Magick -le 'print Image::Magick->QuantumDepth'`;

if ($?) {
  say ("NOT FOUND");
  say ("Please install ImageMagick with Perl before proceeding.");
  say ("The ImageMagick detection command returned: $imgk");
  die;
}
else {
  say ("OK!");
}

#Build & Install CPAN Dependencies 
if ($back || $full) {
  say ("\r\nInstalling Perl modules... This might take a while.\r\n");

  system("cpanm --installdeps ./tools/.");
}

#Clientside Dependencies with Provisioning
if ($front || $full) {

  say ("\r\nObtaining remote Web dependencies...\r\n");

  system("npm install");

  say ("\r\nProvisioning...\r\n");
  #Load File::Copy
  install_package("File::Copy");
  File::Copy->import("copy");

  mkdir getcwd."/public/css/vendor";
  mkdir getcwd."/public/css/webfonts";
  mkdir getcwd."/public/js/vendor";

  for my $css (@vendor_css) {
    cp_node_module($css, "/public/css/vendor/");
  }

  for my $js (@vendor_js) {
    cp_node_module($js, "/public/js/vendor/");
  }

  for my $woff (@vendor_woff) {
    cp_node_module($woff, "/public/css/webfonts/");
  }
  
}

#Done!
say ("\r\nAll set! You can start LANraragi by typing the command: ");
say ("------------------------");
say ("|                      |");
say ("|      npm start       |");
say ("|                      |");
say ("------------------------");

sub cp_node_module {

  my ($item, $newpath) = @_;

  my $nodename = getcwd."/node_modules".$item;
  $item =~ /([^\/]+$)/;
  my $newname = getcwd.$newpath.$&;

  say ("Copying $nodename \r\n to $newname \r\n");
  copy($nodename , $newname) or die "The copy operation failed: $!";

}

sub install_package {

  my $package = $_[0];

  eval "require $package";
  if( $@ ) {
     say ("$package not installed! Trying to install now using cpanm.");
     system("cpanm $package");
     require $package;
  }
  else {
    say ("$package package installed, proceeding...");
  }

}