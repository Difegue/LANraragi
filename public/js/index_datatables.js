//Functions for DataTable initialization.

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
		'drawCallback': addPageSelect,
		'rowCallback': buildThumbDiv,
		'columns': [{
			className: 'title itd',
			'data': null,
			'name': 'title',
			'render': titleColumnDisplay
		}, {
			className: 'custom1 itd',
			'data': 'tags',
			'name': localStorage.customColumn1,
			'render': function (data, type, full, meta) {
				return createNamespaceColumn(localStorage.customColumn1, type, data);
			}
		}, {
			className: 'custom2 itd',
			'data': 'tags',
			'name': localStorage.customColumn2,
			'render': function (data, type, full, meta) {
				return createNamespaceColumn(localStorage.customColumn2, type, data);
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
			return `<a style="cursor:pointer" onclick="fillSearchField('${namespace}','${match[1]}')">
						${match[1].replace(/\b./g, function (m) { return m.toUpperCase(); })}
					</a>`;
		} else return "";

	}
	return data;
}

// Fill out the search field and trigger a search programmatically.
function fillSearchField(namespace, tag) {
	$('#srch').val(`${namespace}:${tag}`);
	arcTable.search(`${namespace}:${tag}`).draw();
}

function titleColumnDisplay(data, type, full, meta) {
	if (type == "display") {

		titleHtml = "";
		titleHtml += buildProgressDiv(data.arcid, data.isnew);

		return `${titleHtml} 
				<a class="image-tooltip" id="${data.arcid}" onmouseover="buildImageTooltip($(this))" href="reader?id=${data.arcid}"> 
					${encode(data.title)}
				</a>
				<div class="caption" style="display: none;">
					<img style="height:200px" src="./api/archives/${data.arcid}/thumbnail" onerror="this.src='./img/noThumb.png'">
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
			$('.datatables').after("<div id='thumbs_container'></div>");

		// clear out the thumbs container
		$('#thumbs_container').html('');

		$('.list').hide();
	}
	else {
		//Destroy the thumb container, make the table visible again and ensure autowidth is correct
		$('#thumbs_container').remove();
		$('.list').show();

		//nuke style of table - datatables' auto-width gets a bit lost when coming back from thumb view.
		$('.datatables').attr("style", "");

		if (typeof (arcTable) !== "undefined")
			arcTable.columns.adjust();
	}
}

function addPageSelect(settings) {
	if (typeof (arcTable) !== "undefined") {
		var pageInfo = arcTable.page.info();
		if (pageInfo.pages == 0) return;

		$(".dataTables_paginate").toArray().forEach((div) => {

			var container = $("<div class='page-select' >Go to Page: </div>");
			var nInput = document.createElement('select');
			$(nInput).attr("class", "favtag-btn");

			for (var j = 1; j <= pageInfo.pages; j++) { //add the pages
				var oOption = document.createElement('option');
				oOption.text = j;
				oOption.value = j;
				nInput.add(oOption, null);
			}

			nInput.value = pageInfo.page + 1;
			$(nInput).on("change", (e) => arcTable.page(nInput.value - 1).draw("page"));

			container.append(nInput);
			div.appendChild(container[0]);
		});
	}
}

//Builds a id1 class div to jam in the thumb container for an archive whose JSON data we read
function buildThumbDiv(row, data, index) {

	if (localStorage.indexViewMode == 1) {
		//Build a thumb-like div with the data
		thumb_css = (localStorage.cropthumbs === 'true') ? "id3" : "id3 nocrop";
		thumb_div = `<div style="height:335px" class="id1" id="${data.arcid}">
						<div class="id2">
							${buildProgressDiv(data.arcid, data.isnew)}
							<a href="reader?id=${data.arcid}" title="${encode(data.title)}">${encode(data.title)}</a>
						</div>
						<div style="height:280px" class="${thumb_css}">
							<a href="reader?id=${data.arcid}" title="${encode(data.title)}">
								<img style="position:relative;" id="${data.arcid}_thumb" src="./img/wait_warmly.jpg"/>
								<i id="${data.arcid}_spinner" class="fa fa-4x fa-cog fa-spin ttspinner"></i>
								<img src="./api/archives/${data.arcid}/thumbnail" 
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
		encodedK = encode(key.toLowerCase());
		line += `<tr><td class='caption-namespace ${encodedK}-tag'>${ucKey}:</td><td>`;

		tagsByNamespace[key].forEach(function (tag) {
			line += `<div class="gt" onclick="fillSearchField('${key}','${encode(tag)}')">
					 	${encode(tag)}
					 </div>`;
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

	if (tags === null || tags === undefined) {
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
