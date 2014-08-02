#Default config variables. Change as you see fit.
my $htmltitle = "LANraragi Main Page"; #Title of the html page.
my $motd = "Welcome to this Library running LANraragi v.0.0.1!"; #Text that appears on top of the page. Empty for no text.
my $thumbnails = 1; #Whether or not you load thumbnails when hovering over a title.
my $password = "kamimamita"; #Password for editing titles. You should probably change this, even though it's not "admin" 
my $dirname = "./content"; #Directory of the zip archives.

#Functions that return the local config variables. Avoids fuckups if you happen to create a $motd variable in your own code, for example.

sub get_htmltitle { return $htmltitle };
sub get_motd { return $motd };
sub get_thumbnails { return $thumbnails };
sub get_password { return $password };
sub get_dirname  { return $dirname };
