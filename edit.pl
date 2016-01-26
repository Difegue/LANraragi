#!/usr/bin/perl

use strict;
use CGI qw(:standard);
use File::Basename;
use Redis;
use Encode;

require 'config.pl';
require 'functions.pl';

my $qedit = new CGI;			   

my $html = start_html
	(
	-title=>&get_htmltitle.' - Edit Mode',
    -author=>'lanraragi-san',		
    -style=>[{'src'=>'./bower_components/font-awesome/css/font-awesome.min.css'}],
    -script=>[{-type=>'JAVASCRIPT',
							-src=>'./js/css.js'},
			 {-type=>'JAVASCRIPT',
							-src=>'./bower_components/jquery/dist/jquery.min.js'},
			 {-type=>'JAVASCRIPT',
							-src=>'./js/ajax.js'}],			
	-head=>[Link({-rel=>'icon',-type=>'image/png',-href=>'favicon.ico'}),
					meta({-name=>'viewport', -content=>'width=device-width'})],
	-encoding => "utf-8",
	-onLoad => "//Set the correct CSS from the user's localStorage.
						set_style_from_storage();"
	);

$html .= &printCssDropdown(0);
$html .= "<script>
				function updateTags(a) {
					document.getElementById('tagText').value=document.getElementById('tagText').value+a;
				}
			</script>";
	
if ($qedit->param()) {
    # Parameters are defined, therefore something has been submitted...	
	
	#Redis initialization.
	my $redis = Redis->new(server => &get_redisad, 
						reconnect => 100,
						every     => 3000);

	
	#Are the submitted arguments POST(and not the cgi:ajax ones)?
	my %params = $qedit->Vars;
	unless (exists $params{"fname"}){
		if ('POST' eq $qedit->request_method ) { # ty stack overflow 
		# It is, which means parameters for a rename have been passed. Let's get cracking!
		#Check for password first.
		my $pass = $qedit->param('pass');
		unless ((&enable_pass && ($pass eq &get_password)) || &enable_pass==0)
			{
			$html .= "<div class='ido' style='text-align:center'><h1>Wrong password.</h1><br/>";
			$html .= "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/></div>";
			}
		else
			{ 
			my $event = $qedit->param('event');
			my $artist = $qedit->param('artist');
			my $title = $qedit->param('title');
			my $series = $qedit->param('series');
			my $language = $qedit->param('language');
			my $tags = $qedit->param('tags');
			my $id = $qedit->param('id');
			
			#clean up the user's inputs.
			removeSpaceF($event);
			removeSpaceF($artist);
			removeSpaceF($title);
			removeSpaceF($series);
			removeSpaceF($language);
			removeSpaceF($tags);
			
			#Input new values into redis hash.
			#prepare the hash which'll be inserted.
			my %hash = (
					event => $event,
					artist => $artist,
					title => $title,
					series => $series,
					language => $language,
					tags => $tags
				);
				
			#for all keys of the hash, add them to the redis hash $id with the matching keys.
			$redis->hset($id, $_, $hash{$_}, sub {}) for keys %hash;
			$redis->wait_all_responses;
			&rebuild_index;
			$html .= "<div class='ido' style='text-align:center'><h1>Edit Successful!</h1><br/>";
				
			$html .= "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/></div>";
			
			}		
		} else {
			# It's GET. That means we've only been given a file id. Generate the renaming form.
		    
			#Does the passed file exist?
			my $id = $qedit->param('id');
			
			if ($redis->hexists($id,"title"))
			{
				$redis->quit();
				$html .=generateForm($qedit);	
			}
			else
				{
				$redis->quit();
				$html .= "<div class='ido' style='text-align:center'><h1>File not found. </h1><br/>";
				$html .= "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/></div>";
				}
		} 
	}
	else
	{
		#If this is an AJAX request, we get the tags and send them back.
		$html.= getTags($qedit->param('hashDiv'));
	}
} else {
    # No parameters back the fuck off
    $html .= "pls gib arguments";
}

$html .= end_html;

#We print the html we generated.
print $qedit->header(-type    => 'text/html',
                   	-charset => 'utf-8');
print $html;


sub generateForm
	{
	my $id = $_[0]->param('id');
	
	my $redis = Redis->new(server => &get_redisad, 
						reconnect => 100,
						every     => 3000);
						
	my %hash = $redis->hgetall($id);					
	my ($name,$event,$artist,$title,$series,$language,$tags,$file,$thumbhash) = @hash{qw(name event artist title series language tags file thumbhash)};
	($_ = decode_utf8($_)) for ($name, $event, $artist, $title, $series, $language, $tags, $file);


	my $html = "<div class='ido' style='text-align:center'>";
	if ($artist eq "")
		{$html .= $_[0]->h1({-class=>'ih', -style=>'text-align:center'},'Editing '.$title);}
	else
		{$html .= $_[0]->h1({-class=>'ih', -style=>'text-align:center'},'Editing '.$title.' by '.$artist);}

	$html .= $_[0]->start_form(
					-name		=> 'editArchiveForm',
					);

	$html .= "<table style='margin:auto'><tbody>";
	
	$html .= "<tr><td style='text-align:left; width:100px'>Current File Name:</td><td>";
	$html .= $_[0]->textfield(
			-name      => 'filename',
			-value     => $file,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:90%",
			-readonly,
		);
	$html .= "</td></tr>";
	
	$html .= "<tr><td style='text-align:left; width:100px'>ID:</td><td>";
	$html .= $_[0]->textfield(
			-name      => 'id',
			-id 	   => 'archiveID',
			-value     => $id,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:90%",
			-readonly,
		);
	$html .= "</td></tr>";
	
	$html .= "<tr><td style='text-align:left; width:100px'>Title:</td><td>";
	$html .= $_[0]->textfield(
			-name      => 'title',
			-id		   => 'title',
			-value     => $title,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:90%",
		);
	$html .= "</td></tr>";
	
	$html .= "<tr><td style='text-align:left; width:100px'>Artist:</td><td>";
	$html .= $_[0]->textfield(
			-name      => 'artist',
			-value     => $artist,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:90% ",
		);
	$html .= "</td></tr>";
	
	$html .= "<tr><td style='text-align:left; width:100px'>Series:</td><td>";
	$html .= $_[0]->textfield(
			-name      => 'series',
			-value     => $series,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:90%",
		);
	$html .= "</td></tr>";
	
	$html .= "<tr><td style='text-align:left; width:100px'>Language:</td><td>";
	$html .= $_[0]->textfield(
			-name      => 'language',
			-value     => $language,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:90%",
		);
	$html .= "</td></tr>";
	
	$html .= "<tr><td style='text-align:left; width:100px'>Released at:</td><td>";
	$html .= $_[0]->textfield(
			-name      => 'event',
			-value     => $event,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:90%",
		);
	$html .= "</td></tr>";

	#These buttons here call the ajax functions, which in turn calls the getTags/getTagsSearch subs.
	$html .= qq(<tr><td style='text-align:left; width:100px; vertical-align:top'>Tags:

			<input type='button' name='tag_import' value='Import E-Hentai&#x00A; Tags&#x00A;(Image Search)' onclick="ajaxTags('$thumbhash',1,\$('#pw_field').val());" 
				class='stdbtn' style='margin-top:25px;min-width:50px; max-width:100px;height:60px '></input> 
			
			<input type='button' name='tag_import' value='Import E-Hentai&#x00A; Tags&#x00A;(Text Search)' onclick="ajaxTags('$title',0,\$('#pw_field').val());" 
				class='stdbtn' style='margin-top:25px;min-width:50px; max-width:100px;height:60px '></input>

			</td><td>);
			#>
			
			
	$html .= $_[0]->textarea(
			-name      => 'tags',
			-id  	   => 'tagText',
			-value     => $tags,
			-size      => 20,
			-maxlength => 5000,
			-class => "stdinput",
			-style => "width:90%; height:300px",
		);
	$html .= qq(<i class="fa fa-5x fa-cog fa-spin" style="  color:black;
			    position:absolute;
			  top:60%; 
			  left:52%; 
			  display:none" id="tag-spinner"></i>
			</td></tr>);
	
		if (&enable_pass)
	{
		$html .= "<tr><td style='text-align:left; width:100px'>Admin Password:</td><td>";
		$html .= $_[0]->password_field(
				-name      => 'pass',
				-id 	   => 'pw_field',
				-value     => '',
				-size      => 20,
				-maxlength => 255,
				-class => "stdinput",
				-style => "width:90%",
			);
		$html .= "</td></tr>";
	}
	
	$html .= "<tr><td></td>";

	$html .= "<td style='text-align:left'><input class='stdbtn' type='button' onclick=\"validateForm('editArchiveForm');\" value='Edit Archive'/>";
	$html .= "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/></td></tr>";
	$html .= "<tr id='wrongpass' style='display:none;font-size:13px'><td></td><td style='text-align:left'> Wrong Password. </td></tr>";

	$html .= "</tbody></table>";
	$html .= $_[0]->end_form;
	
	$html .= "</div>";
	$redis->quit();
	return $html;
	}
