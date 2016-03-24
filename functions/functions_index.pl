use strict;
use utf8;
use URI::Escape;
use Redis;
use Encode;
use File::Path qw(make_path remove_tree);
use File::Basename;
use HTML::Table;

require 'config.pl';

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
		my $filecheck = "";
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
					($name,$event,$artist,$title,$series,$language,$tags,$filecheck,$isnew) = @hash{qw(name event artist title series language tags file isnew)};

					#Parameters have been obtained, let's decode them.
					($_ = decode_utf8($_)) for ($name, $event, $artist, $title, $series, $language, $tags, $filecheck);

					#Update the real file path and title just in case the file got manually renamed or some weird shit
					unless ($file eq $filecheck)
					{
						($name,$path,$suffix) = fileparse($file, qr/\.[^.]*/);
						$redis->hset($id, "file", encode_utf8($file));
						$redis->hset($id, "name", encode_utf8($name));
						$redis->wait_all_responses;
					}	

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

			my $urlencoded = $dirname."/".uri_escape($name).$suffix; 	

			my $icons = qq(<div style="font-size:14px"><a href="$urlencoded" title="Download this archive."><i class="fa fa-save"></i><a/> 
							<a href="./edit.pl?id=$id" title="Edit this archive's tags and data."><i class="fa fa-pencil"></i><a/></div>);
					

			#Tag display. Simple list separated by hyphens which expands into a caption div with nicely separated tags on hover.
			my $printedtags = "";

			unless ($event eq "") 
				{ $printedtags = $event.", ".$tags; }
			else
				{ $printedtags = $tags;}

			$printedtags = qq(<span class="tags" style="text-overflow:ellipsis;">$printedtags</span><div class="caption" style="position:absolute;">);

			#Split the tags, and put them in individual divs for pretty printing.
			my @tagssplit = split(',\s?',$tags);
			my $tag = "";

			foreach $tag (@tagssplit)
				{ $printedtags .= qq(<div class="gt" onclick="\$('#srch').val(\$(this).html()); arcTable.search(\$(this).html()).draw();">$tag</div>); } #The JS allows the user to search a tag by clicking it.

			#Close up the caption.
			$printedtags.="</div>"; 

			
			#version with hover thumbnails 
			if (&enable_thumbs)
			{
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
