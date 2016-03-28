#!/usr/bin/perl

use strict;
use CGI qw/:standard/;
use HTML::Table;
use File::Path qw(remove_tree);
use Redis;

#Require config 
require 'config.pl';
require 'functions/functions_generic.pl';
require 'functions/functions_index.pl';
require 'functions/functions_login.pl';


	my $dirname = &get_dirname;

	#Get all files in content directory.
	#This should be enough supported file extensions, right? The old lsar method was hacky and took too long.
	my @filez = glob("$dirname/*.zip $dirname/*.rar $dirname/*.7z $dirname/*.tar $dirname/*.tar.gz $dirname/*.lzma $dirname/*.xz $dirname/*.cbz $dirname/*.cbr");

	#Default redis server location is localhost:6379. 
	#Auto-reconnect on, one attempt every 100ms up to 2 seconds. Die after that.
	my $redis = Redis->new(server => &get_redisad, 
							reconnect => 100,
							every     => 3000);

	remove_tree($dirname.'/temp'); #Remove temp dir.

	my $table;
	#From the file tree, generate the HTML table
	if (@filez)
	{ $table = &generateTable(@filez); }
	else
	{ $table = "<h1>Looks like you didn't upload any archives yet. Try dragging some into the content folder, or uploading them from <a href='upload.pl'>this page</a> ! </h1>"}
	$redis->quit();


	#Actual HTML output
	my $cgi = new CGI;

	#We print the html we generated.
	print $cgi->header(-type    => 'text/html',
                   -charset => 'utf-8');

	print &printPage($table,$cgi);





	# BIG PRINTS		   
	sub printPage {

		my $table = $_[0];
		my $cgi = $_[1];
		my $html = start_html
			(
			-title=>&get_htmltitle,
			-author=>'lanraragi-san',
			-style=>[{'src'=>'./styles/lrr.css'},
					{'src'=>'./bower_components/font-awesome/css/font-awesome.min.css'}],
			-script=>[
						{-type=>'JAVASCRIPT',
							-src=>'./bower_components/jquery/dist/jquery.min.js'},
						{-type=>'JAVASCRIPT',
							-src=>'./bower_components/datatables/media/js/jquery.dataTables.min.js'},
						{-type=>'JAVASCRIPT',
							-src=>'./bower_components/dropit/dropit.js'},
						{-type=>'JAVASCRIPT',
							-src=>'./js/ajax.js'},	
						{-type=>'JAVASCRIPT',
							-src=>'./js/thumb.js'},
						{-type=>'JAVASCRIPT',
							-src=>'./js/css.js'}],	
			-head=>[Link({-rel=>'icon',-type=>'image/png',-href=>'favicon.ico'}),
					meta({-name=>'viewport', -content=>'width=device-width'})],
			-encoding => "UTF-8",
			#on Load, initialize datatables and some other shit
			-onLoad => "var thumbTimeout = null;
									
						\$.fn.dataTableExt.oStdClasses.sStripeOdd = 'gtr0';
						\$.fn.dataTableExt.oStdClasses.sStripeEven = 'gtr1';

						//datatables configuration
						arcTable= \$('.itg').DataTable( { 
							'lengthChange': false,
							'pageLength': ".&get_pagesize().",
							'order': [[ 1, 'asc' ]],
							'dom': '<\"top\"ip>rt<\"bottom\"p><\"clear\">',
							'language': {
									'info':           'Showing _START_ to _END_ of _TOTAL_ ancient chinese lithographies.',
    								'infoEmpty':      'No archives to show you !',
    							}
						});

					    //Initialize CSS dropdown with dropit
						\$('.menu').dropit({
					       action: 'click', // The open action for the trigger
					        submenuEl: 'div', // The submenu element
					        triggerEl: 'a', // The trigger element
					        triggerParentEl: 'span', // The trigger parent element
					        afterLoad: function(){}, // Triggers when plugin has loaded
					        beforeShow: function(){}, // Triggers before submenu is shown
					        afterShow: function(){}, // Triggers after submenu is shown
					        beforeHide: function(){}, // Triggers before submenu is hidden
					        afterHide: function(){} // Triggers before submenu is hidden
					    });

						//Set the correct CSS from the user's localStorage again, in case the version in <script> tags didn't load.
						//(That happens on mobiles for some reason.)
						set_style_from_storage();

						//add datatable search event to the local searchbox and clear search to the clear filter button
						\$('#srch').keyup(function(){
						      arcTable.search(\$(this).val()).draw() ;
						});

						\$('#clrsrch').click(function(){
							arcTable.search('').draw(); 
							\$('#srch').val('');
							});

						//clear searchbar cache
						\$('#srch').val('');

						//end init thumbnails
						hidetrail();
						document.onmouseover=followmouse;

						"
			);

		if (&isUserLogged($cgi))
		{
			$html.='<p id="nb">
			<i class="fa fa-caret-right"></i>
			<a href="./upload.pl">Upload Archive</a>
			<span style="margin-left:5px"></span>
			<i class="fa fa-caret-right"></i>
			<a href="./tags.pl">Batch Tagging</a>
			<span style="margin-left:5px"></span>
			<i class="fa fa-caret-right"></i>
			<a href="./backup.pl">Backup/Restore Database</a>
			</p>';
		}
		else
		{
			$html.='<p id="nb">
			<i class="fa fa-caret-right"></i>
			<a href="./login.pl">Admin Login</a>
			</p>';	
		}
		
			
		$html.="<div class='ido'>
		<div id='toppane'>
		<h1 class='ih'>".&get_motd."</h1> 
		<div class='idi'>";
			
		#Search field (stdinput class in panda css)
		$html.="<input type='text' id='srch' class='search stdinput' size='90' placeholder='Search Title, Artist, Series, Language or Tags' /> <input id='clrsrch' class='stdbtn' type='button' value='Clear Filter'/></div>";

		#Dropdown list for changing CSSes on the fly.
		my $CSSsel = &printCssDropdown(1);

		#Random button + CSS dropdown with dropit. These can't be generated in JS, the styles need to be loaded asap.
		$html.="<p id='cssbutton' style='display:inline'><input class='stdbtn' type='button' onclick=\"var win=window.open('random.pl','_blank'); win.focus();\" value='Give me a random archive'/>".$CSSsel."</p>";

		$html=$html."<script>
			//Set the correct CSS from the user's localStorage.
			set_style_from_storage();

			//Init thumbnail hover
			showtrail('img/noThumb.png');
			</script>";

		$html.="$table"; #print our finished table

		$html.="</div></div>"; #close errything

		$html.='		<p class="ip">
					<a href="https://github.com/Difegue/LANraragi">
						Sorry, I stuttered.
					</a>
				</p>';
				
		$html.=end_html; #close html
		return $html;
	}


