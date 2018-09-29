/*
////// REGULAR INDEX PAGE FUNCTIONS
*/

// Lifted from SO, parse a JSON string and return the matching object. 
// Returns false if the string isn't valid JSON.
function tryParseJSON(jsonString) {
	try {
		var o = JSON.parse(jsonString);

		// Handle non-exception-throwing cases:
		// Neither JSON.parse(false) or JSON.parse(1234) throw errors, hence the type-checking,
		// but... JSON.parse(null) returns null, and typeof null === "object", 
		// so we must check for that, too. Thankfully, null is falsey, so this suffices:
		if (o && typeof o === "object") {
			return o;
		}
	}
	catch (e) { }

	return false;
};

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

	searchQuery = searchQuery.slice(0, -1);
	searchQuery += ")";

	//Perform search in datatables field with our own regexes enabled and smart search off
	if (searchQuery !== "") {
		arcTable.search(searchQuery, true, false).draw();
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

function checkVersion(currentVersion) {
	//Check the github API to see if an update was released. If so, flash another friendly notification inviting the user to check it out
	var githubAPI = "https://api.github.com/repos/difegue/lanraragi/releases/latest";
	var latestVersion;

	$.getJSON(githubAPI).done(function (data) {
		latestVersion = data.tag_name;
		if (latestVersion != "v." + currentVersion) {

			$.toast({
				heading: 'A new version of LANraragi (' + latestVersion + ') is available !',
				text: '<a href="' + data.html_url + '">Click here to check it out.</a>',
				hideAfter: false,
				position: 'top-left',
				icon: 'info'
			});

		}
	});
}
