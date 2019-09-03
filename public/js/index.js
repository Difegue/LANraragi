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
	favTagSearch();
}

function toggleInbox(button) {

	input = $("#inboxbtn");

	//invert input's checked value
	inboxState = !(input.prop("checked"));
	input.prop("checked", inboxState);

	if (inboxState) {
		$("#inboxbtn").val("Show all archives");
	} else {
		$("#inboxbtn").val("Show new archives only");
	}

	//Redraw the table 
	$('#clrsrch').click();
}

// Triggered when a favTag checkbox is modified, 
// looks at all checked favTags and builds an OR regex to jam in DataTables
function favTagSearch() {

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
		arcTable.search(searchQuery, true, false).draw();
	} else {
		//clear
		arcTable.search("", false, true).draw();
	}

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

function loadTagSuggestions() {

	
	$.get("api/tagstats")
		.done(function (data) {
			// Only use tags with weight >1 
			taglist = data.reduce(function(res, tag) {
				if (tag.weight > 1) {
					if (tag.namespace === "")
						res.push(tag.text);
					else
						res.push(tag.namespace+":"+tag.text);
				}
				return res;
			}, []);

			new Awesomplete('#srch', {

				list: taglist,
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