//Functions for DataTable initialization.

//Executed onload of the archive index to initialize DataTables and other minor things.
//This is painful to read.
function initIndex(pagesize, dataSet) {
	thumbTimeout = null;

	$.fn.dataTableExt.oStdClasses.sStripeOdd = 'gtr0';
	$.fn.dataTableExt.oStdClasses.sStripeEven = 'gtr1';

	//datatables configuration
	arcTable = $('.datatables').DataTable({
		'data': dataSet,
		'deferRender': true,
		'lengthChange': false,
		'pageLength': pagesize,
		'order': [[1, 'asc']],
		'dom': '<"top"ip>rt<"bottom"p><"clear">',
		'language': {
			'info': 'Showing _START_ to _END_ of _TOTAL_ ancient chinese lithographies.',
			'infoEmpty': '<h1>No archives to show you ! Try <a href="upload">uploading some</a> ?</h1><br/>(If you dropped files into the content folder, please wait for the cache to build.)',
		},
		'preDrawCallback': thumbViewInit, //callbacks for thumbnail view
		'rowCallback': buildThumbDiv,
		'columns': [
			{
				className: 'itdc',
				'width': '20',
				'data': 'isnew', //mild trickery to keep the isnew value stored in the table
				'render': actionColumnDisplay
			},
			{
				className: 'title itd',
				'data': null,
				'render': titleColumnDisplay
			},
			{
				className: 'artist itd',
				'data': 'tags',
				'render': artistColumnDisplay
			},
			{
				className: 'series itd',
				'data': 'tags',
				'render': seriesColumnDisplay
			},
			{
				className: 'tags itd',
				'data': 'tags',
				'render': function (data, type, full, meta) {
					if (type == "display") {

						line = '<span class="tags tag-tooltip" onmouseover="buildTagTooltip($(this))" style="text-overflow:ellipsis;">' + colorCodeTags(data) + '</span>';
						line += buildTagsDiv(data);
						return line;
					}
					return data;
				}
			}
		],
	});

	//add datatable search event to the local searchbox and clear search to the clear filter button
	$('#srch').keyup(function () {
		arcTable.search($(this).val()).draw();
	});

	$('#clrsrch').click(function () {
		//clear all favtags
		for (var i = 0; i < $(".favtag").length; i++) {
			$(".favtag")[i].checked = false;
			$(".favtag-btn")[i].classList.remove("toggled");
		}

		arcTable.search('').draw();
		$('#srch').val('');
	});

	//clear searchbar cache
	$('#srch').val('');

	//nuke style of table - datatables seems to assign its table a fixed width for some reason.
	$('.datatables').attr("style", "")

	/* Custom filtering function which will only show new archives if the inbox button is toggled. */
	$.fn.dataTable.ext.search.push(
		function (settings, data, dataIndex) {

			input = $("#inboxbtn");

			if (!input.prop("checked"))
				return true;

			//See mild trickery above
			if (data[0] === "block") {
				return true;
			}
			return false;
		}
	);

	//Init Thumbnail Mode if enabled - we do it twice in order to initialize it at the value the user has stored.
	//(Yeah it's shitty but it works so w/e)
	switch_index_view();
	switch_index_view();

}

//For datatable initialization, columns with just one data source display that source as a link for instant search.
function artistColumnDisplay(data, type, full, meta) {
	if (type == "display") {

		if (data === "")
			return "";

		regex = /.*artist:\s?([^,]*),*.*/gi; //Catch last artist:xxx value in tags
		match = regex.exec(data);

		if (match != null) {
			return '<a style="cursor:pointer" onclick="$(\'#srch\').val($(this).html()); arcTable.search($(this).html()).draw();">' +
				match[1].replace(/\b./g, function (m) { return m.toUpperCase(); }) +
				'</a>';
		} else return "";

	}

	return data;
}

//For datatable initialization, columns with just one data source display that source as a link for instant search.
function seriesColumnDisplay(data, type, full, meta) {
	if (type == "display") {

		if (data === "")
			return "";

		regex = /.*(parody|series|magazine):\s?([^,]*),*.*/gi
		match = regex.exec(data);

		if (match != null) {
			return '<a style="cursor:pointer" onclick="$(\'#srch\').val($(this).html()); arcTable.search($(this).html()).draw();">' +
				match[2].replace(/\b./g, function (m) { return m.toUpperCase(); }) +
				'</a>';
		} else return "";

	}

	return data;
}


function actionColumnDisplay(data, type, full, meta) {
	if (type == "display") {
		return '<div style="font-size:16px">'
			+ '<a href="./api/servefile?id=' + full.arcid + '" title="Download this archive."><i class="fa fa-save" style="margin-right:2px"></i><a/>'
			+ '<a href="./edit?id=' + full.arcid + '" title="Edit this archive\'s tags and data."><i class="fa fa-edit"></i><a/></div>';
	}

	return data;
}

function titleColumnDisplay(data, type, full, meta) {
	if (type == "display") {

		titleHtml = "";
		if (data.isnew === "block") {
			titleHtml = '<span class="isnew"></span>'
		}

		return titleHtml + '<a class="image-tooltip" onmouseover="buildImageTooltip($(this))" href="./reader?id=' + data.arcid + '">'
			+ data.title + '</a><div class="caption" style="display: none;"><img src="./api/thumbnail?id='
			+ data.arcid + '" onerror="this.src=\'./img/noThumb.png\'"></div>';
	}

	return data.title;
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
		//Build a thumb-like div with the data and jam it in thumbs_container
		thumb_div = '<div style="height:335px" class="id1">' +
			'<div class="id2">' +
			'<div class="id44">' +
			'<div class="isnew" style=" display: ' + data.isnew + '">' +
			'</div>' +
			'</div>' +
			'<a href="./reader?id=' + data.arcid + '" title="' + data.title + '">' + data.title + '</a>' +
			'</div>' +
			'<div style="height:280px" class="id3">' +
			'<a href="./reader?id=' + data.arcid + '" title="' + data.title + '">';

		thumb_div += '<img style="position:relative;" id ="' + data.arcid + '_thumb" src="./img/wait_warmly.jpg"/>' +
			'<i id="' + data.arcid + '_spinner" class="fa fa-4x fa-cog fa-spin ttspinner"></i>' +
			'<img style="position:absolute; top:0; left:0; width:200px" src="./api/thumbnail?id=' + data.arcid + '" onload="$(\'#' + data.arcid + '_thumb\').remove(); $(\'#' + data.arcid + '_spinner\').remove();" onerror="this.src=\'./img/noThumb.png\'"/>';

		thumb_div += '</a>' +
			'</div>' +
			'<div class="id4">' +
			'<div class="id41" style="font-size:16px; margin-left:10px"><a title="Download this archive." href="./api/servefile?id=' + data.arcid + '">' +
			'<i style="margin-right:2px" class="fa fa-save"></i>' +
			'</a>' +
			'<a title="Edit this archive\'s tags and data." href="./edit?id=' + data.arcid + '">' +
			'<i class="fa fa-edit"></i>' +
			'</a></div>' +
			'<div class="id42 tag-tooltip"><a style="cursor:pointer" onmouseover="buildTagTooltip($(this))">Hover me for tags!</a>' +
			buildTagsDiv(data.tags) + '</div>' +
			'</div>' +
			'</div>';

		$('#thumbs_container').append(thumb_div);
	}
}

//Build a tooltip when hovering over an archive title, then display it. The tooltip is saved in DOM for further uses.
function buildImageTooltip(target) {
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

		line += "<tr><td style='font-size:10pt; padding: 0 2px 7px; vertical-align:top'>" + ucKey + ":</td><td>";

		tagsByNamespace[key].forEach(function (tag) {
			line += '<div class="gt" onclick="$(\'#srch\').val($(this).html()); arcTable.search($(this).html()).draw();">' + tag + '</div>';
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
			line+="<span class='"+key+"-tag'>"+tag+"</span>, ";
		});
	});	
	return line;
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