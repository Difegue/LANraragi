#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use local::lib;
use feature qw(say);

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

#Load IPC::Cmd
eval "require IPC::Cmd";
if( $@ ) {
   say ("IPC::Cmd not installed! Trying to install now using cpanm.");
   system("cpanm IPC::Cmd");
   require IPC::Cmd;
}
else {
  say ("IPC::Cmd package installed, proceeding...");
}

IPC::Cmd->import( 'can_run' );

say ("");
say ("Will now check if all LRR software dependencies are met.");
say ("");

#Check for Redis
print ("Checking for Redis...");
can_run('redis-cli') or die 'NOT FOUND! \r\n Please install a Redis server before proceeding.';
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
say ("");
say ("Installing Perl modules... This might take a while.");
say ("");

system("cpanm --installdeps ./tools/.");

#Webpack Clientside Dependencies
say ("");
say ("Installing Web dependencies...");
say ("");

system("npm install");

#Done!
say ("");
say ("All set! You can start LANraragi by typing the command: ");
say ("npm start");