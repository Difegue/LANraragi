/*
////// REGULAR INDEX PAGE FUNCTIONS
*/

//Toggles a favtag. Modifies the matching input DOM object and changes the button's class.
function toggleFav(button) {

	favTag = button.value;
	input = $("[id='" + favTag + "']");

	//invert input's checked value
	tagState = !(input.prop("checked"));
	input.prop("checked", tagState);

	//Add/remove class to button depending on the state
	if (tagState)
		button.classList.add("toggled");
	else
		button.classList.remove("toggled");

	//Trigger search
	performSearch();
}

function toggleFilter(button) {

	//invert input's checked value
	inboxState = !(button.prop("checked"));
	button.prop("checked", inboxState);

	if (inboxState) {
		button.val("Show all archives");
	} else { // Reset string to ogvalue
		button.val(button.prop("ogvalue"));
	}

	//Redraw the table 
	performSearch();
}

// looks at all checked favTags and builds an OR regex to jam in DataTables
// and then ANDs result with standard smart DataTables search
function performSearch() {

	favTags = $(".favtag");
	favTagQuery = "\"";

	for (var i = 0; i < favTags.length; i++) {
		tagCheckbox = favTags[i];
		if (tagCheckbox.checked)
			favTagQuery += tagCheckbox.id + "\" \"";
	}

	// Add the favtag query to the tags column so it's picked up by the search engine 
	// This allows for the regular search bar to be used in conjunction with favtags.
	if (favTagQuery !== "\" ") {
		arcTable.column('.tags.itd').search(favTagQuery);
	} else {
		// no fav filters
		arcTable.column('.tags.itd').search("");
	}

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
	arcTable.draw();
}

//Switch view on index and saves the value in the user's localStorage. The DataTables callbacks adapt automatically.
//0 = List view
//1 = Thumbnail view
function switch_index_view() {

	if (localStorage.indexViewMode == 1) {
		localStorage.indexViewMode = 0;
		$("#viewbtn").val("Switch to Thumbnail View");
	}
	else {
		localStorage.indexViewMode = 1;
		$("#viewbtn").val("Switch to List View");
	}

	//Redraw the table yo
	arcTable.draw();

}

function checkVersion(currentVersionConf) {
	//Check the github API to see if an update was released. If so, flash another friendly notification inviting the user to check it out
	var githubAPI = "https://api.github.com/repos/difegue/lanraragi/releases/latest";
	var latestVersion;

	$.getJSON(githubAPI).done(function (data) {
		var expr = /(\d+)/g;
		var latestVersionArr = Array.from(data.tag_name.match(expr));
		var latestVersion = '';
		var currentVersionArr = Array.from(currentVersionConf.match(expr));
		var currentVersion = '';

		latestVersionArr.forEach(function(element, index) {
			if(index+1 < latestVersionArr.length) {
				latestVersion = latestVersion + '' + element;
			} else {
				latestVersion = latestVersion + '.' + element;
			}
		});
		currentVersionArr.forEach(function(element, index) {
			if(index+1 < currentVersionArr.length) {
				currentVersion = currentVersion + '' + element;
			} else {
				currentVersion = currentVersion + '.' + element;
			}
		});

		if (latestVersion > currentVersion) {

			$.toast({
				heading: 'A new version of LANraragi (' + data.tag_name + ') is available !',
				text: '<a href="' + data.html_url + '">Click here to check it out.</a>',
				hideAfter: false,
				position: 'top-left',
				icon: 'info'
			});

		}
	});
}

function handleContextMenu(option, id) {

	switch (option) {
		case "edit":
			window.open("./edit?id="+id);
			break;
		case "delete":
			if (confirm('Are you sure you want to delete this archive?')) 
				deleteArchive(id);
			break;
		case "read":
			window.open("./reader?id="+id);
			break;
		case "download":
			window.open("./api/servefile?id="+id);
			break;
		default:
			break;
	}
}

// Format tag objects from the API into a format awesomplete likes.
function fullTag(tag) {
	label = tag.text;
	if (tag.namespace !== "")
		label = tag.namespace+":"+tag.text;
	
	return { label: label, value: tag.weight };
}

function loadTagSuggestions() {
	// Query the tag cloud API to get the most used tags.
	$.get("api/tagstats")
		.done(function (data) {
			// Only use tags with weight >1 
			taglist = data.reduce(function(res, tag) {
					if (tag.weight > 1) 
						res.push(tag);
					return res;
			}, []);
			
			new Awesomplete('#srch', {
				list: taglist,
				data: fullTag,
				// Sort by weight
				sort: function(a, b) { return b.value - a.value; },
				filter: function(text, input) {
					return Awesomplete.FILTER_CONTAINS(text, input.match(/[^, -]*$/)[0]);
				},
				item: function(text, input) {
					return Awesomplete.ITEM(text, input.match(/[^, -]*$/)[0]);
				},
				replace: function(text) {
					var before = this.input.value.match(/^.*(,|-)\s*-*|/)[0];
					this.input.value = before + text + ", ";
				}
			});

		}).fail(function (data) {
			$.toast({
				showHideTransition: 'slide',
				position: 'top-left',
				loader: false,
				heading: errorMessage,
				text: data.error,
				icon: 'error'
			});
		});
}