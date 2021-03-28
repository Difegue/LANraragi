//Functions for DataTable initialization.

//Executed onload of the archive index to initialize DataTables and other minor things.
//This is painful to read.
function initIndex(pagesize) {

	selectedCategory = "";
	isComingFromPopstate = false;

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
		'drawCallback': drawCallback,
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
	$('#subsrch').on("click", function () {
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

	$('#clrsrch').on("click", function () {
		$('#srch').val('');
		performSearch();
	});

	//clear searchbar cache
	$('#srch').val('');

	// Add a listen event to window.popstate to update the search accordingly if the user goes back using browser history
	window.onpopstate = () => {
		isComingFromPopstate = true;
		searchFromURLParams();
	}

	// If the url has parameters, handle them now by doing the matching search.
	searchFromURLParams();
}

// Looks at the active filters and performs a search using DataTables' API.
// (which is hooked back to the internal Search API)
// If you specify a page argument, the search will load the given page.
function performSearch(page) {

	// Add the selected category to the tags column so it's picked up by the search engine 
	// This allows for the regular search bar to be used in conjunction with categories.
	arcTable.column('.tags.itd').search(selectedCategory);

	// Add the isnew filter if asked
	input = $("#inboxbtn");

	if (input.prop("checked")) {
		arcTable.column('.isnew').search("true");
	} else {
		// no fav filters
		arcTable.column('.isnew').search("");
	}

	// Add the untagged filter if asked
	input = $("#untaggedbtn");

	if (input.prop("checked")) {
		arcTable.column('.untagged').search("true");
	} else {
		// no fav filters
		arcTable.column('.untagged').search("");
	}

	arcTable.search($('#srch').val().replace(",", ""));

	if (page) {
		// Hack the displayStart value to draw at the page we asked
		arcTable.settings()[0].iInitDisplayStart = page * arcTable.settings()[0]._iDisplayLength;
	}
	else {
		arcTable.settings()[0].iInitDisplayStart = 0;
	}
	arcTable.draw();

	//Re-load categories so the most recently selected/created ones appear first
	loadCategories();
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
			return `<a style="cursor:pointer" onclick="fillSearchField(event, '${namespace}','${match[1]}')">
						${match[1].replace(/\b./g, function (m) { return m.toUpperCase(); })}
					</a>`;
		} else return "";

	}
	return data;
}

// Fill out the search field and trigger a search programmatically.
function fillSearchField(e, namespace, tag) {
	$('#srch').val(`${namespace}:${tag}`);
	arcTable.search(`${namespace}:${tag}`).draw();
	e.preventDefault(); // Override href 
}

function titleColumnDisplay(data, type, full, meta) {
	if (type == "display") {

		titleHtml = "";
		titleHtml += buildProgressDiv(data);

		return `${titleHtml} 
				<a class="context-menu" id="${data.arcid}" onmouseover="buildImageTooltip(this)" href="reader?id=${data.arcid}"> 
					${encode(data.title)}
				</a>
				<div class="caption" style="display: none;">
					<img style="height:300px" src="./api/archives/${data.arcid}/thumbnail" onerror="this.src='./img/noThumb.png'">
				</div>`;
	}

	return data.title;
}

function tagsColumnDisplay(data, type, full, meta) {
	if (type == "display") {

		line = '<span class="tag-tooltip" onmouseover="buildTagTooltip(this)" style="text-overflow:ellipsis;">' + colorCodeTags(data) + '</span>';
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

function drawCallback(settings) {
	if (typeof (arcTable) !== "undefined") {
		var pageInfo = arcTable.page.info();
		if (pageInfo.pages == 0) {
			$('.itg').hide();
		} else {
			$('.itg').show();
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

		// Update url to contain all search parameters, and push it to the history 
		if (isComingFromPopstate) // But don't fire this if we're coming from popstate 
			isComingFromPopstate = false;
		else {
			var params = buildURLParams();
			if (params === "?")
				params = "/";
			window.history.pushState(null, null, params);
		}
	}
}

function buildURLParams() {

	var cat = arcTable.column('.tags.itd').search();
	var untag = arcTable.column('.untagged').search();
	var isnew = arcTable.column('.isnew').search();
	var page = arcTable.page.info().page + 1;
	var sortby = arcTable.order()[0][0];
	var sortorder = arcTable.order()[0][1];

	var encodedSearch = encodeURIComponent(arcTable.search());

	return `?`
		+ ((page !== 1) ? `p=${page}` : "")
		+ ((sortby !== 0) ? `&sort=${sortby}` : "")
		+ ((sortorder !== "asc") ? `&sortdir=${sortorder}` : "")
		+ ((encodedSearch !== "") ? `&q=${encodedSearch}` : "")
		+ ((cat !== "") ? `&c=${cat}` : "")
		+ ((untag !== "") ? `&untagged` : "")
		+ ((isnew !== "") ? `&isnew` : "");

}

function searchFromURLParams() {

	var params = new URLSearchParams(window.location.search);

	if (params.has("c"))
		selectedCategory = params.get("c");
	else
		selectedCategory = "";

	$("#untaggedbtn").prop("checked", params.has("untagged"));
	updateToggleClass($("#untaggedbtn"));

	$("#inboxbtn").prop("checked", params.has("isnew"));
	updateToggleClass($("#inboxbtn"));

	if (params.has("q")) {
		$('#srch').val(decodeURIComponent(params.get("q")));
	} else {
		$('#srch').val("");
	}

	var order = [[0, "asc"]];

	if (params.has("sort"))
		order[0][0] = params.get("sort");

	if (params.has("sortdir"))
		order[0][1] = params.get("sortdir");

	arcTable.order(order);

	if (params.has("p"))
		performSearch(params.get("p") - 1);
	else
		performSearch();

}

//Builds a id1 class div to jam in the thumb container for an archive whose JSON data we read
function buildThumbDiv(row, data, index) {

	if (localStorage.indexViewMode == 1) {
		//Build a thumb-like div with the data
		thumb_css = (localStorage.cropthumbs === 'true') ? "id3" : "id3 nocrop";
		thumb_div = `<div style="height:335px" class="id1 context-menu" id="${data.arcid}">
						<div class="id2">
							${buildProgressDiv(data)}
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
							<span class="tags tag-tooltip" onmouseover="buildTagTooltip(this)">${colorCodeTags(data.tags)}</span>
							${buildTagsDiv(data.tags)} 
						</div>
					</div>`;

		$('#thumbs_container').append(thumb_div);
	}
}

function buildProgressDiv(arcdata) {

	id = arcdata.arcid;
	isnew = arcdata.isnew;
	pagecount = parseInt(arcdata.pagecount || 0);
	progress = parseInt(arcdata.progress || 0);

	if (isnew === "true") {
		return '<div class="isnew">🆕</div>';
	} else if (pagecount > 0) {

		// Consider an archive read if progress is past 85% of total
		if ((progress / pagecount) > 0.85)
			return "<div class='isnew'>👑</div>";
		else
			return `<div class='isnew'><sup>${progress}/${pagecount}</sup></div>`;
	}

	return "";
}

//Build a tooltip when hovering over an archive title, then display it. The tooltip is saved in DOM for further uses.
function buildImageTooltip(target) {

	if (target.innerHTML === "")
		return;

	tippy(target, {
		content: $(target).next('div').clone().attr("style", "height:300px;")[0],
		delay: 0,
		animation: false,
		maxWidth: 'none',
		followCursor: true,
	}).show(); //Call show() so that the tooltip shows now

	$(target).attr('onmouseover', ''); //Don't trigger this function again for this element
}

//Ditto for tag tooltips, with different options.
function buildTagTooltip(target) {
	tippy(target, {
		content: $(target).next('div').attr("style", "")[0],
		delay: 0,
		placement: 'auto-start',
		maxWidth: 'none',
		interactive: true
	}).show(); //Call show() so that the tooltip shows now

	$(target).attr('onmouseover', '');
}

//Builds a caption div containing clickable tags. Uses a string containing all tags, split by commas.
//Namespaces are resolved on the fly.
function buildTagsDiv(tags) {
	if (tags === "")
		return "";

	tagsByNamespace = splitTagsByNamespace(tags);

	line = '<div class="caption caption-tags" style="display: none;" >';
	line += '<table class="itg" style="box-shadow: 0 0 0 0; border: none; border-radius: 0" ><tbody>';

	//Go through resolved namespaces and print tag divs
	Object.keys(tagsByNamespace).sort().forEach(function (key, index) {

		ucKey = key.charAt(0).toUpperCase() + key.slice(1);
		ucKey = encode(ucKey);
		encodedK = encode(key.toLowerCase());
		line += `<tr><td class='caption-namespace ${encodedK}-tag'>${ucKey}:</td><td>`;

		tagsByNamespace[key].forEach(function (tag) {
			line += `<div class="gt">
					 	<a onclick="fillSearchField(event, '${key}','${encode(tag)}')" 
						   href="?q=${encodeURIComponent(key + ":" + tag)}">
						   ${encode(tag)}
						</a>
					 </div>`;
		});

		line += "</td></tr>";
	});

	line += '</tbody></table></div>';
	return line;
}