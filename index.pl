#!/usr/bin/perl

use strict;
use CGI qw/:standard/;
use Redis;
use Template;
use utf8;
use Authen::Passphrase;
use File::Find qw(find);

#Require config 
require 'functions/functions_config.pl';
require 'functions/functions_generic.pl';
require 'functions/functions_index.pl';
require 'functions/functions_login.pl';

	my $version = "v.0.3.5";
	my $dirname = &get_dirname;

	#Get all files in content directory and subdirectories.
	#This should be enough supported file extensions, right? The old lsar method was hacky and took too long.
	my @filez;
	find({ wanted => sub { 
							if ($_ =~ /^*.+\.(zip|rar|7z|tar|tar.gz|lzma|xz|cbz|cbr)$/ )
								{push @filez, $_ }
						 },
		   no_chdir => 1,
		   follow_fast => 1 }, 
		$dirname);
			  

	remove_tree('./temp'); #Remove temp dir.

	my $table;

	#From the file tree, generate the HTML table
	if (@filez)
	{ $table = &generateTableJSON(@filez); }
	else
	{ $table = "[]"}

	#Actual HTML output
	my $cgi = new CGI;
	my $tt  = Template->new({
        INCLUDE_PATH => "templates",
        ENCODING => 'UTF-8' 
    });

	#We print the html we generated.
	print $cgi->header(-type    => 'text/html',
                   -charset => 'utf-8');

	my $out;

	#Checking if the user still has the default password enabled
	my $ppr = Authen::Passphrase->from_rfc2307(&get_password);
	my $passcheck = ($ppr->match("kamimamita") && &enable_pass);

	$tt->process(
        "index.tmpl",
        {
            title => &get_htmltitle,
            pagesize => &get_pagesize,
            userlogged => &isUserLogged($cgi),
            motd => &get_motd,
            cssdrop => &printCssDropdown(1),
            tableJSON => decode_utf8($table),
            usingdefpass => $passcheck,
            version => $version,
        },
        \$out,
    ) or die $tt->error;

    print $out;

