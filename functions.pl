use Digest::SHA qw(sha256_hex);
use URI::Escape;
use Redis;
use Encode;
use File::Path qw(make_path remove_tree);
use File::Basename;
use HTML::Table;
use LWP::Simple qw/get/;
use JSON::Parse 'parse_json';

require 'config.pl';

#getGalleryId(hash(or text),isHash)
#Takes an image hash or basic text, performs a remote search on g.e-hentai, and builds the matching JSON to send to the API for data.
sub getGalleryId{

	my $hash = $_[0];
	my $isHash = $_[1];
	my $URL;

	if ($isHash eq "1")
	{	#search with image SHA hash
		$URL = "http://g.e-hentai.org/".
				"?f_doujinshi=1&f_manga=1&f_artistcg=1&f_gamecg=1&f_western=1&f_non-h=1&f_imageset=1&f_cosplay=1&f_asianporn=1&f_misc=1".
				"&f_search=Search+Keywords&f_apply=Apply+Filter&f_shash=".$hash."&fs_similar=1";
	}
	else
	{	#search with archive title
		$URL = "http://g.e-hentai.org/".
				"?f_doujinshi=1&f_manga=1&f_artistcg=1&f_gamecg=1&f_western=1&f_non-h=1&f_imageset=1&f_cosplay=1&f_asianporn=1&f_misc=1".
				"&f_search=".$hash."&f_apply=Apply+Filter";
	}
	my $content = get $URL;

	#now for the parsing of the HTML we obtained.
	#the first occurence of <tr class="gtr0"> matches the first row of the results. 
	#If it doesn't exist, what we searched isn't on E-hentai.
	my @benis = split('<tr class="gtr0">', $content);
	
	#Inside that <tr>, we look for <div class="it5"> . the <a> tag inside has an href to the URL we want.
	my @final = split('<div class="it5">',@benis[1]);

	my $url = (split('http://g.e-hentai.org/g/',@final[1]))[1];

	
	my @values = (split('/',$url));

	my $gID = @values[0];
	my $gToken = @values[1];

	#Returning shit yo
	return qq({
				"method": "gdata",
				"gidlist": [
					[$gID,"$gToken"]
				]
				});
	
}

#Executes an API request with the given JSON and returns 
sub getTagsFromAPI{
	
	my $uri = 'http://g.e-hentai.org/api.php';
	my $json = $_[0];
	my $req = HTTP::Request->new( 'POST', $uri );
	$req->header( 'Content-Type' => 'application/json' );
	$req->content( $json );

	#Then you can execute the request with LWP:

	my $ua = LWP::UserAgent->new; 
	my $res = $ua->request($req);
	
	#$res is a JSON response. 
	#print $res->decoded_content;
	my $jsonresponse = $res -> decoded_content;
	my $hash = parse_json($jsonresponse);
	
	#eval {
	unless (exists $hash->{"error"})
	{
		my $data = $hash->{"gmetadata"};
		my $tags = @$data[0]->{"tags"};

		my $return = join(" ", @$tags);
		return $return;
	}	
	else 
	{
	return ""; #if an error occurs(no tags available) return an empty string.
	}

}


#Print a dropdown list to select CSS, and adds <link> tags for all the style sheets present in the /style folder.
#Takes a boolean as argument: if true, return the styles and the dropdown. If false, only return the styles.
sub printCssDropdown{

	#Getting all the available CSS sheets.
	my @css;
	opendir (DIR, "./styles/") or die $!;
	while (my $file = readdir(DIR)) 
	{
		if ($file =~ /.+\.css/)
		{push(@css, $file);}

	}
	closedir(DIR);

	#button for deploying dropdown
	my $CSSsel = '<div class="menu" style="display:inline">
    				<span>
        				<a href="#"><input type="button" class="stdbtn" value="Change Library Look"></a>';

	#the list itself
	$CSSsel = $CSSsel.'<div>';

	#html that we'll insert before the list to declare all the available styles.
	my $html;

	#We opened a drop-down list. Now, we'll fill it.
	for ( my $i = 0; $i < $#css+1; $i++) 
	{
		if (@css[$i] ne "lrr.css") #quality work
		{
			#populate the div with spans
			$CSSsel = $CSSsel.'<span><a href="#" onclick="switch_style(\''.$i.'\');return false;">'.&cssNames(@css[$i]).'</a></span>';


			if (@css[$i] eq &get_style) #if this is the default sheet, set it up as so.
				{$html=$html.'<link rel="stylesheet" type="text/css" title="'.$i.'" href="./styles/'.@css[$i].'"> ';}
			else
				{$html=$html.'<link rel="alternate stylesheet" type="text/css" title="'.$i.'" href="./styles/'.@css[$i].'"> ';}

		}
	}		

	#close up dropdown list
	$CSSsel = $CSSsel.'</div>
    				</span>
				</div>';

	if ($_[0])
	{return $html.$CSSsel;}
	else
	{return $html;}
}
	

#This handy function gives us a SHA-1 hash for the passed file, which is used as an id for some files. 
sub shasum{
  my $digest = "";
  eval{
    open(FILE, $_[0]) or die "Can't find file $file\n";
    my $ctx = Digest::SHA->new;
    $ctx->addfile(*FILE);
    $digest = $ctx->hexdigest;
    close(FILE);
  };
  if($@){
    print $@;
    return "";
  }
  return $digest;
}


#parseName, with regex. [^([]+ 
sub parseName
	{
	my $id = $_[1];
	
	#Use the regex.
	$_[0] =~ &get_regex || next;

	my ($event,$artist,$title,$series,$language) = &regexsel;
	my $tags ="";
		
	return ($event,$artist,$title,$series,$language,$tags,$id);
	}
	


#With a list of files, generate the HTML table that will be shown in the main index.
sub generateTable
	{
		my @dircontents = @_;
		my $file = "";
		my $path = "";
		my $suffix = "";
		my $name = "";
		my $thumbname = "";
		my ($event,$artist,$title,$series,$language,$tags,$id) = (" "," "," "," "," "," ");
		my $fullfile="";
		my $isnew = "none";
		my $count;
		my $dirname = &get_dirname;

		my $redis = Redis->new(server => &get_redisad, 
							reconnect => 100,
							every     => 3000);

		#Generate Archive table
		my $table = new HTML::Table(-rows=>0,
		                            -cols=>6,
		                            -class=>'itg'
		                            );

		$table->addSectionRow ( 'thead', 0, "",'<a>Title</a>','<a>Artist/Group</a>','<a>Series</a>',"<a>Language</a>","<a>Tags</a>");
		$table->setSectionRowHead('thead', -1, -1, 1);

		#Add IDs to the table headers to hide them with media queries on small screens.
		$table->setSectionCellAttr('thead', 0, 1, 2, 'id="titleheader"');
		$table->setSectionCellAttr('thead', 0, 1, 3, 'id="artistheader"');
		$table->setSectionCellAttr('thead', 0, 1, 4, 'id="seriesheader"');
		$table->setSectionCellAttr('thead', 0, 1, 5, 'id="langheader"');
		$table->setSectionCellAttr('thead', 0, 1, 6, 'id="tagsheader"');

		foreach $file (@dircontents)
		{
			#ID of the archive, used for storing data in Redis.
			$id = sha256_hex($file);

			#Let's check out the Redis cache first! It might already have the info we need.
			if ($redis->hexists($id,"title"))
				{
					#bingo, no need for expensive file parsing operations.
					my %hash = $redis->hgetall($id);

					#It's not a new archive, though. But it might have never been clicked on yet, so we'll grab the value for $isnew stored in redis.

					#Hash Slice! I have no idea how this works.
					($name,$event,$artist,$title,$series,$language,$tags,$isnew) = @hash{qw(name event artist title series language tags isnew)};
				}
			else	#can't be helped. Do it the old way, and add the results to redis afterwards.
				{
					#This means it's a new archive, though! We can notify the user about that later on, and specify it in the hash.
					$isnew="block";
					
					($name,$path,$suffix) = fileparse($file, qr/\.[^.]*/);
					
					#parseName function is up there 
					($event,$artist,$title,$series,$language,$tags,$id) = &parseName($name.$suffix,$id);
					
					#jam this shit in redis
					#prepare the hash which'll be inserted.
					my %hash = (
						name => encode_utf8($name),
						event => encode_utf8($event),
						artist => encode_utf8($artist),
						title => encode_utf8($title),
						series => encode_utf8($series),
						language => encode_utf8($language),
						tags => encode_utf8($tags),
						file => encode_utf8($file),
						isnew => encode_utf8($isnew),
						);
						
					#for all keys of the hash, add them to the redis hash $id with the matching keys.
					$redis->hset($id, $_, $hash{$_}, sub {}) for keys %hash; 
					$redis->wait_all_responses;
				}
				
			#Parameters have been obtained, let's decode them.
			($_ = decode_utf8($_)) for ($name, $event, $artist, $title, $series, $language, $tags, $file);
			
			my $icons = qq(<div style="font-size:14px"><a href="$dirname/$name$suffix" title="Download this archive."><i class="fa fa-save"></i><a/> 
							<a href="./edit.pl?id=$id" title="Edit this archive's tags and data."><i class="fa fa-pencil"></i><a/></div>);
					#<a href="./tags.pl?id=$id" title="E-Hentai Tag Import (Unfinished)."><i class="fa fa-server"></i><a/>
					
			#When generating the line that'll be added to the table, user-defined options have to be taken into account.
			#Truncated tag display. Works with some hella disgusting CSS shit.
			my $printedtags = $event." ".$tags;
			if (length $printedtags > 50)
			{
				$printedtags = qq(<a class="tags" style="text-overflow:ellipsis;">$printedtags</a><div class="caption" style="position:absolute;">$printedtags</div>); 
			}
			
			#version with hover thumbnails 
			if (&enable_thumbs)
			{
				#ajaxThumbnail makes the thumbnail for that album if it doesn't already exist. 
				#(If it fails for some reason, it won't return an image path, triggering the "no thumbnail" image on the JS side.)
				my $thumbname = $dirname."/thumb/".$id.".jpg";

				my $row = qq(<span style="display: none;">$title</span>
										<a href="./reader.pl?id=$id" );

				if (-e $thumbname)
				{
					$row.=qq(onmouseover="thumbTimeout = setTimeout(showtrail, 200,'$thumbname')" );
				}
				else
				{
					$row.=qq(onmouseover="thumbTimeout = setTimeout(ajaxThumbnail, 200,'$id')" );
				}
											
				$row.=qq(onmouseout="hidetrail(); clearTimeout(thumbTimeout);">
										$title
										</a>
										<img src="img/n.gif" style="float: right; margin-top: -15px; z-index: -1; display: $isnew">); #user is notified here if archive is new (ie if it hasn't been clicked on yet)

				#add row for this archive to table
				$table->addRow($icons.qq(<input type="text" style="display:none;" id="$id" value="$id"/>),$row,$artist,$series,$language,$printedtags);
			}
			else #version without, ezpz
			{
				#add row to table
				$table->addRow($icons,qq(<span style="display: none;">$title</span><a href="./reader.pl?id=$id" title="$title">$title</a>),$artist,$series,$language,$printedtags);
			}
				
			$table->setSectionClass ('tbody', -1, 'list' );
			
		}


		$table->setColClass(1,'itdc');
		$table->setColClass(2,'title itd');
		$table->setColClass(3,'artist itd');
		$table->setColClass(4,'series itd');
		$table->setColClass(5,'language itd');
		$table->setColClass(6,'tags itu');
		$table->setColWidth(1,30);

		return $table;
	}