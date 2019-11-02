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

function toggleInbox(button) {

	input = $("#inboxbtn");

	//invert input's checked value
	inboxState = !(input.prop("checked"));
	input.prop("checked", inboxState);

	if (inboxState) {
		$("#inboxbtn").val("显示所有作品");
	} else {
		$("#inboxbtn").val("显示最新作品");
	}

	//Redraw the table 
	$('#clrsrch').click();
}

// looks at all checked favTags and builds an OR regex to jam in DataTables
// and then ANDs result with standard smart DataTables search
function performSearch() {

	favTags = $(".favtag");
	searchQuery = "("

	for (var i = 0; i < favTags.length; i++) {
		tagCheckbox = favTags[i];
		if (tagCheckbox.checked)
			searchQuery += tagCheckbox.id + "|";
	}

	//chop last | character
	searchQuery = searchQuery.slice(0, -1);
	searchQuery += ")";

	//Perform search in datatables field with our own regexes enabled and smart search off
	if (searchQuery !== ")") {
		arcTable.column('.tags.itd').search(searchQuery, true, false);
		arcTable.search($('#srch').val().replace(",", ""), false, true);
		arcTable.draw();
	} else {
		// no fav filters
		arcTable.column('.tags.itd').search("", false, true);
		arcTable.search($('#srch').val().replace(",", ""), false, true).draw();
	}

}

//Switch view on index and saves the value in the user's localStorage. The DataTables callbacks adapt automatically.
//0 = List view
//1 = Thumbnail view
function switch_index_view() {

	if (localStorage.indexViewMode == 1) {
		localStorage.indexViewMode = 0;
		$("#viewbtn").val("以相册模式显示");
	}
	else {
		localStorage.indexViewMode = 1;
		$("#viewbtn").val("以列表模式显示");
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
			if (confirm('你确定要删掉这个作品吗?')) 
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
				sort: function(a, b) { console.log(a); return b.value - a.value; },
				filter: function(text, input) {
					return Awesomplete.FILTER_CONTAINS(text, input.match(/[^,]*$/)[0]);
				},
				item: function(text, input) {
					return Awesomplete.ITEM(text, input.match(/[^,]*$/)[0]);
				},
				replace: function(text) {
					var before = this.input.value.match(/^.+,\s*|/)[0];
					this.input.value = before + text + ", ";
				}
			});

			// Perform a search when a tag is selected
			Awesomplete.$('#srch').addEventListener("awesomplete-selectcomplete", function() {
				performSearch();
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