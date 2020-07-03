//Functions for DataTable initialization.

var column1 = "artist";
var column2 = "series";
var column3 = "";

//Executed onload of the archive index to initialize DataTables and other minor things.
//This is painful to read.
function initIndex(pagesize) {

	$.fn.dataTableExt.oStdClasses.sStripeOdd = 'gtr0';
	$.fn.dataTableExt.oStdClasses.sStripeEven = 'gtr1';

	//datatables configuration
	arcTable = $('.datatables').DataTable({
		'serverSide': true,
		'processing': true,
		'ajax': "search",
		'deferRender': true,
		'lengthChange': false,
		'pageLength': pagesize,
		'order': [[0, 'asc']],
		'dom': '<"top"ip>rt<"bottom"p><"clear">',
		'language': {
			'info': 'Showing _START_ to _END_ of _TOTAL_ ancient chinese lithographies.',
			'infoEmpty': '<h1>No archives to show you! Try <a href="upload">uploading some</a>?</h1><br/>',
			'processing': '<div id="progress" class="indeterminate""><div class="bar-container"><div class="bar" style=" width: 80%; "></div></div></div>'
		},
		'preDrawCallback': thumbViewInit, //callbacks for thumbnail view
		'rowCallback': buildThumbDiv,
		'columns': [{
			className: 'title itd',
			'data': null,
			'name': 'title',
			'render': titleColumnDisplay
		}, {
			className: column1 + ' itd',
			'data': 'tags',
			'name': column1,
			'render': function (data, type, full, meta) {
				return createNamespaceColumn(column1, type, data);
			}
		}, {
			className: column2 + ' itd',
			'data': 'tags',
			'name': column2,
			'render': function (data, type, full, meta) {
				return createNamespaceColumn(column2, type, data);
			}
		}, {
			className: 'tags itd',
			'data': 'tags',
			'name': 'tags',
			'orderable': false,
			'render': tagsColumnDisplay
		}, { // The columns below are invisible and only meant to add extra parameters to a search.
			className: 'isnew itd',
			visible: false,
			'data': 'isnew',
			'name': 'isnew'
		}, {
			className: 'untagged itd',
			visible: false,
			'data': null,
			'name': 'untagged'
		}],
	});

	//add datatable search event to the local searchbox and clear search to the clear filter button
	$('#subsrch').click(function () {
		performSearch();
	});
	$('#srch').keyup(function (e) {
		if (e.defaultPrevented) {
			return;
		} else if (e.key == "Enter") {
			performSearch();
		}
		e.preventDefault();
	});

	$('#clrsrch').click(function () {
		$('#srch').val('');
		performSearch();
	});

	//clear searchbar cache
	$('#srch').val('');

	//nuke style of table - datatables seems to assign its table a fixed width for some reason.
	$('.datatables').attr("style", "")

	//Change button label if list mode is enabled.
	if (localStorage.indexViewMode == 0)
		$("#viewbtn").val("Switch to Thumbnail View");
}

//For datatable initialization, columns with just one data source display that source as a link for instant search.
function createNamespaceColumn(namespace, type, data) {
	if (type == "display") {

		if (data === "")
			return "";

		var namespaceRegEx = namespace;
		if (namespace == "series") namespaceRegEx = "(?:series|parody)";
		regex = new RegExp(".*" + namespaceRegEx + ":\\s?([^,]*),*.*", "gi"); // Catch last namespace:xxx value in tags
		match = regex.exec(data);

		if (match != null) {
			return `<a style="cursor:pointer" arc-namespace="${namespace}" onclick="$('#srch').val($(this).attr('arc-namespace') + ':' + $(this).html()); 
																					arcTable.search($(this).attr('arc-namespace') + ':' + $(this).html()).draw();">
						${match[1].replace(/\b./g, function (m) { return m.toUpperCase(); })}
					</a>`;
		} else return "";

	}
	return data;
}

function openInNewTab(url) {
	var win = window.open(url, '_blank');
	win.focus();
}

function titleColumnDisplay(data, type, full, meta) {
	if (type == "display") {

		titleHtml = "";
		titleHtml += buildProgressDiv(data.arcid, data.isnew);

		return `${titleHtml} 
				<a class="image-tooltip" id="${data.arcid} style="cursor:pointer" 
				   onmouseover="buildImageTooltip($(this))" onclick="openInNewTab('reader?id=${data.arcid}')"> 
					${encode(data.title)}
				</a>
				<div class="caption" style="display: none;">
					<img style="height:200px" src="./api/thumbnail?id=${data.arcid}" onerror="this.src='./img/noThumb.png'">
				</div>`;
	}

	return data.title;
}

function tagsColumnDisplay(data, type, full, meta) {
	if (type == "display") {

		line = '<span class="tag-tooltip" onmouseover="buildTagTooltip($(this))" style="text-overflow:ellipsis;">' + colorCodeTags(data) + '</span>';
		line += buildTagsDiv(data);
		return line;
	}
	return data;
}

//Functions executed on DataTables draw callbacks to build the thumbnail view if it's enabled:
//Inits the div that contains the thumbnails
function thumbViewInit(settings) {
	//we only do all this thingamajang if thumbnail view is enabled
	if (localStorage.indexViewMode == 1) {
		// create a thumbs container if it doesn't exist. put it in the dataTables_scrollbody div
		if ($('#thumbs_container').length < 1)
			$('.top').after("<div id='thumbs_container'></div>");

		// clear out the thumbs container
		$('#thumbs_container').html('');

		$('.itg').hide();
	}
	else {
		//Destroy the thumb container and make the table visible again
		$('#thumbs_container').remove();
		$('.itg').show();
	}
}

//Builds a id1 class div to jam in the thumb container for an archive whose JSON data we read
function buildThumbDiv(row, data, index) {

	if (localStorage.indexViewMode == 1) {
		//Build a thumb-like div with the data
		thumb_div = `<div style="height:335px" class="id1" id="${data.arcid}">
						<div class="id2" style="cursor:pointer">
							${buildProgressDiv(data.arcid, data.isnew)}
							<a onclick="openInNewTab('reader?id=${data.arcid}')" title="${encode(data.title)}">${encode(data.title)}</a>
						</div>
						<div style="height:280px; cursor:pointer" class="id3" >
							<a onclick="openInNewTab('reader?id=${data.arcid}')" title="${encode(data.title)}">
								<img style="position:relative;" id ="${data.arcid}_thumb" src="./img/wait_warmly.jpg"/>
								<i id="${data.arcid}_spinner" class="fa fa-4x fa-cog fa-spin ttspinner"></i>
								<img src="./api/thumbnail?id=${data.arcid}" 
									 onload="$('#${data.arcid}_thumb').remove(); $('#${data.arcid}_spinner').remove();" 
									 onerror="this.src='./img/noThumb.png'"/>
							</a>
						</div>
						<div class="id4">
							<span class="tags tag-tooltip" onmouseover="buildTagTooltip($(this))">${colorCodeTags(data.tags)}</span>
							${buildTagsDiv(data.tags)} 
						</div>
					</div>`;

		$('#thumbs_container').append(thumb_div);
	}
}

function buildProgressDiv(id, isnew) {

	// localStorage'd reader progress takes priority over the server-provided new flag
	// (which might not always be up to date due to cache n shit)
	if (localStorage.getItem(id + "-totalPages") !== null && localStorage.nobookmark !== 'true') {
		// Progress recorded, display an indicator
		currentPage = Number(localStorage.getItem(id + "-reader")) + 1;
		totalPages = Number(localStorage.getItem(id + "-totalPages"));

		if (currentPage === totalPages)
			return "<div class='isnew'>👑</div>";
		else
			return `<div class='isnew'><sup>${currentPage}/${totalPages}</sup></div>`;
	}

	if (isnew === "block" || isnew === "true") {
		return '<div class="isnew">🆕</div>';
	}

	return "";
}

//Build a tooltip when hovering over an archive title, then display it. The tooltip is saved in DOM for further uses.
function buildImageTooltip(target) {

	if (target.innerHTML === "")
		return;

	target.qtip({
		content: {
			//make a clone of the existing image div and rip off the caption class to avoid display glitches
			text: target.next('div').clone().removeClass("caption")
		},
		position: {
			target: 'mouse',
			adjust: {
				mouse: true,
				x: 5
			},
			viewport: $(window)
		},
		show: {
			solo: true
		},
		style: {
			classes: 'caption caption-image'
		},
		show: {
			delay: 45
		}
	});

	target.attr('onmouseover', ''); //Don't trigger this function again for this element
	target.mouseover(); //Call the mouseover event again so the tooltip shows now
}

//Ditto for tag tooltips, with different options.
function buildTagTooltip(target) {
	target.qtip({
		content: {
			text: target.next('div')
		},
		position: {
			my: 'middle right',
			at: 'top left',
			target: false,
			viewport: $(window)
		},
		show: {
			solo: true,
			delay: 45
		},
		hide: {
			fixed: true,
			delay: 300
		},
		style: {
			classes: 'caption caption-tags'
		}
	});

	target.attr('onmouseover', '');
	target.mouseover();
}

//Builds a caption div containing clickable tags. Uses a string containing all tags, split by commas.
//Namespaces are resolved on the fly.
function buildTagsDiv(tags) {
	if (tags === "")
		return "";

	tagsByNamespace = splitTagsByNamespace(tags);

	line = '<div style="display: none;" >';
	line += '<table class="itg" style="box-shadow: 0 0 0 0; border: none; border-radius: 0" ><tbody>';

	//Go through resolved namespaces and print tag divs
	Object.keys(tagsByNamespace).sort().forEach(function (key, index) {

		ucKey = key.charAt(0).toUpperCase() + key.slice(1);
		ucKey = encode(ucKey);
		line += `<tr><td style='font-size:10pt; padding: 3px 2px 7px; vertical-align:top'>${ucKey}:</td><td>`;

		tagsByNamespace[key].forEach(function (tag) {
			line += `<div class="gt" arc-namespace="${key}" onclick="$('#srch').val($(this).attr('arc-namespace') + ':' + $(this).html()); 
																	arcTable.search($(this).attr('arc-namespace') + ':' + $(this).html()).draw();">
					 ${encode(tag)}</div>`;
		});

		line += "</td></tr>";
	});

	line += '</tbody></table></div>';
	return line;
}

// Remove namespace from tags and color-code them. Meant for inline display.
function colorCodeTags(tags) {
	line = "";
	if (tags === "")
		return line;

	tagsByNamespace = splitTagsByNamespace(tags);
	Object.keys(tagsByNamespace).sort().forEach(function (key, index) {
		tagsByNamespace[key].forEach(function (tag) {
			var encodedK = encode(key.toLowerCase());
			line += `<span class='${encodedK}-tag'>${encode(tag)}</span>, `;
		});
	});
	// Remove last comma
	return line.slice(0, -2);
}

function splitTagsByNamespace(tags) {

	var tagsByNamespace = {};

	if (tags === null) {
		return tagsByNamespace;
	}

	tags.split(/,\s?/).forEach(function (tag) {
		nspce = null;
		val = null;

		//Split the tag from its namespace
		arr = tag.split(/:\s?/);
		if (arr.length == 2) {
			nspce = arr[0].trim();
			val = arr[1].trim();
		} else {
			nspce = "other";
			val = arr;
		}

		if (nspce in tagsByNamespace)
			tagsByNamespace[nspce].push(val);
		else
			tagsByNamespace[nspce] = [val];

	});

	return tagsByNamespace;
}
