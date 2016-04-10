use strict;
use Redis;
use Encode;

require 'config.pl';

#deleteArchive($id)
#Deletes the archive with the given id from redis, and the matching archive file.
sub deleteArchive
	{

	my $id = $_[0];

	my $redis = Redis->new(server => &get_redisad, 
						reconnect => 100,
						every     => 3000);	

	my $filename = $redis->hget($id, "name");
	my $filename2 = $redis->hget($id, "file");
	$filename = decode_utf8($filename);
	$filename2 = decode_utf8($filename2);

	my $filepath = &get_dirname.'/'.$filename;
	#print $filepath;
	$redis->del($id);

	#print $delcmd;
	$redis->quit();

	unlink $filename2;

	if (-e $filename2)
		{ return "0"; }
	else
		{ return $filename2; }
	}



#generateForm($id)
#Generates the Form for editing archives in edit.pl. 
sub generateForm
	{
	my $id = $_[0];
	
	my $redis = Redis->new(server => &get_redisad, 
						reconnect => 100,
						every     => 3000);
						
	my %hash = $redis->hgetall($id);					
	my ($name,$event,$artist,$title,$series,$language,$tags,$file,$thumbhash) = @hash{qw(name event artist title series language tags file thumbhash)};
	($_ = decode_utf8($_)) for ($name, $event, $artist, $title, $series, $language, $tags, $file);

	$redis->quit();

	my $pagetitle = &get_htmltitle;
	my $html = qq(
		<html>
		<head>
			<title>$pagetitle - Edit Mode</title>

			<meta name="viewport" content="width=device-width" />
			<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />

			<link type="image/png" rel="icon" href="./img/favicon.ico" />
			<link rel="stylesheet" type="text/css" href="./bower_components/font-awesome/css/font-awesome.min.css" />

			<script src="./js/css.js" type="text/JAVASCRIPT"></script>
			<script src="./bower_components/jquery/dist/jquery.min.js" type="text/JAVASCRIPT"></script>
			<script src="./js/ajax.js" type="text/JAVASCRIPT"></script>
		
		</head>
		<body onload="set_style_from_storage();">

	);

	$html .= &printCssDropdown(0);
	$html .= "<script>set_style_from_storage();</script>
			<div class='ido' style='text-align:center'>";


	if ($artist eq "")
		{$html .= "<h1 class='ih' style='text-align:center'>Editing $title</h1>";}
	else
		{$html .= "<h1 class='ih' style='text-align:center'>Editing $title by $artist</h1>";}

	$html .= qq(
			<form name='editArchiveForm' id='editArchiveForm' enctype='multipart/form-data' method='post'>
			  <table style='margin:auto; font-size:8pt;'><tbody>
				<tr><td style='text-align:left; width:100px'>Current File Name:</td><td>
				<input class='stdinput' type='text' style='width:100%' readonly='' maxlength='255' size='20' value='$file' name='filename'>
			  	</td></tr>

			  	<tr><td style='text-align:left; width:100px'>ID:</td><td>
					<input id='archiveID' class='stdinput' type='text' style='width:100%' readonly='' maxlength='255' size='20' value='$id' name='id'>
			  	</td></tr>

			  	<tr><td style='text-align:left; width:100px'>Title:</td><td>
					<input id='title' class='stdinput' type='text' style='width:100%' maxlength='255' size='20' value='$title' name='title'>
			  	</td></tr>

			  	<tr><td style='text-align:left; width:100px'>Artist:</td><td>
			  		<input class='stdinput' type='text' style='width:100%' maxlength='255' size='20' value='$artist' name='artist'>
				</td></tr>

				<tr><td style='text-align:left; width:100px'>Series:</td><td>
					<input class='stdinput' type='text' style='width:100%' maxlength='255' size='20' value='$series' name='series'>
				</td></tr>

				<tr><td style='text-align:left; width:100px'>Language:</td><td>
					<input class='stdinput' type='text' style='width:100%' maxlength='255' size='20' value='$language' name='language'>
				</td></tr>

				<tr><td style='text-align:left; width:100px'>Released at:</td><td>
					<input class='stdinput' type='text' style='width:100%' maxlength='255' size='20' value='$event' name='event'>
				</td></tr>

				<tr><td style='text-align:left; width:100px; vertical-align:top'>Tags <span style="font-size:6pt">(separated by hyphens, i.e : tag1, tag2)</span> :
					<input type='button' name='tag_import' value='Import EHentai&#x00A; Tags&#x00A;(Text Search)' onclick="saveArchiveCallback(ajaxTags,'$id',0);" 
					class='stdbtn' style='margin-top:25px; min-width:90px; height:60px'></input>

					<input type='button' name='tag_import' value='Import EHentai&#x00A; Tags&#x00A;(Image Search)' onclick="saveArchiveCallback(ajaxTags,'$id',1);" 
					class='stdbtn' style='margin-top:25px; min-width:90px; height:60px'></input> 
				
					<input type='button' name='tag_import' value='Import nHentai&#x00A; Tags' onclick="saveArchiveCallback(ajaxTags,'$id',2);" 
					class='stdbtn' style='margin-top:25px; min-width:90px; height:60px; margin-bottom: 5px'></input>

					<i class='fa fa-2x fa-exclamation-circle'></i> Importing Tags will save any modifications to archive metadata you might have made !
				</td>
				<td>
					<textarea id='tagText' class='stdinput' name='tags' maxlength='5000' style='width:100%; height:350px' size='20'>$tags</textarea>
					<i class='fa fa-5x fa-cog fa-spin' style=' color:black; position:absolute; top:55%; left:52%; display:none' id='tag-spinner'></i>
				</td></tr>

				<tr>
				<td colspan='2' style='text-align:left'> <br/>
					<input class='stdbtn' type='button' onclick=" saveArchiveData();" value='Edit Archive'/>
					<input class='stdbtn' type='button' onclick=" if (confirm('Are you sure you want to delete this archive?')) deleteArchive('$id');" value='Delete Archive'/>
					<input class='stdbtn' type='button' onclick="window.location.replace('./');" value='Return to Library'/>
				<br/></td></tr>
				<tr><td colspan='2' ><span id='statusEdit' style='font-weight:800; font-size: 12pt; margin: 50%'></span></td>
				</tbody></table>
			</form>
			);

	$html .= "</div></body></html>";
	return $html;
	}