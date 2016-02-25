use strict;
use Redis;
use File::Remove 'remove';
use IPC::Cmd qw[can_run run];

require 'config.pl';

#deleteArchive($id)
#Deletes the archive with the given id from redis, and the matching archive file.
sub deleteArchive
	{

	my $id = $_[0];

	my $redis = Redis->new(server => &get_redisad, 
						reconnect => 100,
						every     => 3000);	

	my $filepath = $redis->hget($id, "file");

	$filepath = decode_utf8($filepath);
	#print $filepath;
	$redis->del($id);

	my $delcmd = "rm \"$filepath\"";
	#print $delcmd;
	$redis->quit();

	my ( $success, $error_message, $full_buf, $stdout_buf, $stderr_buf ) =
	            run( command => $delcmd, verbose => 0 );

	if (-e $filepath)
		{ return 0; }
	else
		{ return 1; }
	
	}



#generateForm($cgi)
#Generates the Form for editing archives in edit.pl. 
sub generateForm
	{
	my $cgi = $_[0];
	my $id = $cgi->param('id');
	
	my $redis = Redis->new(server => &get_redisad, 
						reconnect => 100,
						every     => 3000);
						
	my %hash = $redis->hgetall($id);					
	my ($name,$event,$artist,$title,$series,$language,$tags,$file,$thumbhash) = @hash{qw(name event artist title series language tags file thumbhash)};
	($_ = decode_utf8($_)) for ($name, $event, $artist, $title, $series, $language, $tags, $file);


	my $html = "<div class='ido' style='text-align:center'>";
	if ($artist eq "")
		{$html .= "<h1 class='ih' style='text-align:center'>Editing $title</h1>";}
	else
		{$html .= "<h1 class='ih' style='text-align:center'>Editing $title by $artist</h1>";}

	$html .= $cgi->start_form(
					-name		=> 'editArchiveForm',
					);

	$html .= "<table style='margin:auto'><tbody>";
	
	$html .= "<tr><td style='text-align:left; width:100px'>Current File Name:</td><td>";
	$html .= $cgi->textfield(
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
	$html .= $cgi->textfield(
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
	$html .= $cgi->textfield(
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
	$html .= $cgi->textfield(
			-name      => 'artist',
			-value     => $artist,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:90% ",
		);
	$html .= "</td></tr>";
	
	$html .= "<tr><td style='text-align:left; width:100px'>Series:</td><td>";
	$html .= $cgi->textfield(
			-name      => 'series',
			-value     => $series,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:90%",
		);
	$html .= "</td></tr>";
	
	$html .= "<tr><td style='text-align:left; width:100px'>Language:</td><td>";
	$html .= $cgi->textfield(
			-name      => 'language',
			-value     => $language,
			-size      => 20,
			-maxlength => 255,
			-class => "stdinput",
			-style => "width:90%",
		);
	$html .= "</td></tr>";
	
	$html .= "<tr><td style='text-align:left; width:100px'>Released at:</td><td>";
	$html .= $cgi->textfield(
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

			<input type='button' name='tag_import' value='Import E-Hentai&#x00A; Tags&#x00A;(Text Search)' onclick="ajaxTags('$id',0);" 
				class='stdbtn' style='margin-top:25px;min-width:50px; max-width:100px;height:60px '></input>

			<input type='button' name='tag_import' value='Import E-Hentai&#x00A; Tags&#x00A;(Image Search)' onclick="ajaxTags('$id',1);" 
				class='stdbtn' style='margin-top:25px;min-width:50px; max-width:100px;height:60px '></input> 
			
			<input type='button' name='tag_import' value='Import nHentai&#x00A; Tags' onclick="ajaxTags('$id',2);" 
				class='stdbtn' style='margin-top:25px;min-width:50px; max-width:100px;height:60px '></input>
			

			</td><td>);
			#>
			
			
	$html .= $cgi->textarea(
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
	
	$html .= "<tr><td></td>";

	$html .= "<td style='text-align:left'><input class='stdbtn' type='submit' value='Edit Archive'/>";
	$html .= "<input class='stdbtn' type='button' onclick=\"if (confirm('Are you sure you want to delete this archive?'))
																    window.location.replace('./edit.pl?id=$id&delete=1');
																\" value='Delete Archive'/>";
	$html .= "<input class='stdbtn' type='button' onclick=\"window.location.replace('./');\" value='Return to Library'/></td></tr>";

	$html .= "</tbody></table>";
	$html .= $cgi->end_form;
	
	$html .= "</div>";
	$redis->quit();
	return $html;
	}