/*
* 	REGULAR INDEX PAGE FUNCTIONS
*/

//Toggles a category filter. Sets the internal selectedCategory variable and changes the button's class.
function toggleCategory(button) {

	//Add/remove class to button depending on the state
	categoryId = button.id;
	if (selectedCategory === categoryId) {
		button.classList.remove("toggled");
		selectedCategory = "";
	} else {
		selectedCategory = categoryId;
		button.classList.add("toggled");
	}

	//Trigger search
	performSearch();
}

function toggleFilter(button) {

	// jquerify
	button = $(button);

	//invert input's checked value
	inboxState = !(button.prop("checked"));
	button.prop("checked", inboxState);

	if (inboxState) {
		button.addClass("toggled");
	} else {
		button.removeClass("toggled");
	}

	//Redraw the table 
	performSearch();
}

// Looks at the active filters and performs a search using DataTables' API.
// (which is hooked back to the internal Search API)
function performSearch() {

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
	arcTable.draw();

	//Re-load categories so the most recently selected/created ones appear first
	loadCategories();
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

		latestVersionArr.forEach(function (element, index) {
			if (index + 1 < latestVersionArr.length) {
				latestVersion = latestVersion + '' + element;
			} else {
				latestVersion = latestVersion + '.' + element;
			}
		});
		currentVersionArr.forEach(function (element, index) {
			if (index + 1 < currentVersionArr.length) {
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

	if (option.startsWith("category-")) {
		var catId = option.replace("category-","");
		addArchiveToCategory(id, catId);
		return;
	}

	switch (option) {
		case "edit":
			window.open("./edit?id=" + id);
			break;
		case "delete":
			if (confirm('Are you sure you want to delete this archive?'))
				deleteArchive(id);
			break;
		case "read":
			window.open("./reader?id=" + id);
			break;
		case "download":
			window.open("./api/servefile?id=" + id);
			break;
		default:
			break;
	}
}

// Format tag objects from the API into a format awesomplete likes.
function fullTag(tag) {
	label = tag.text;
	if (tag.namespace !== "")
		label = tag.namespace + ":" + tag.text;

	return { label: label, value: tag.weight };
}

function loadTagSuggestions() {
	// Query the tag cloud API to get the most used tags.
	$.get("/api/database/stats")
		.done(function (data) {
			// Only use tags with weight >1 
			taglist = data.reduce(function (res, tag) {
				if (tag.weight > 1)
					res.push(tag);
				return res;
			}, []);

			new Awesomplete('#srch', {
				list: taglist,
				data: fullTag,
				// Sort by weight
				sort: function (a, b) { return b.value - a.value; },
				filter: function (text, input) {
					return Awesomplete.FILTER_CONTAINS(text, input.match(/[^, -]*$/)[0]);
				},
				item: function (text, input) {
					return Awesomplete.ITEM(text, input.match(/[^, -]*$/)[0]);
				},
				replace: function (text) {
					var before = this.input.value.match(/^.*(,|-)\s*-*|/)[0];
					this.input.value = before + text + ", ";
				}
			});

		}).fail(data => showErrorToast("Couldn't load tag suggestions", data.error));
}

function loadCategories() {
	// Query the category API to get the most used tags.
	$.get("/api/categories")
		.done(function (data) {

			// Sort by LastUsed + pinned
			// Pinned categories are shown at the beginning
			data.sort((a, b) => parseFloat(b.last_used) - parseFloat(a.last_used));
			data.sort((a, b) => parseFloat(b.pinned) - parseFloat(a.pinned));
			var html = "";

			var iteration = (data.length > 10 ? 10 : data.length);

			for (var i = 0; i < iteration; i++) {
				category = data[i];
				const pinned = category.pinned === "1";

				catName = (pinned ? "📌" : "") + category.name;
				catName = encode(catName);

				div = `<div style='display:inline-block'>
						<input class='favtag-btn ${((category.id == selectedCategory) ? "toggled" : "")}' 
							   type='button' id='${category.id}' value='${catName}' 
							   onclick='toggleCategory(this)' title='Click here to display the archives contained in this category.'/>
					   </div>`;

				html += div;
			}

			//If more than 10 categories, the rest goes into a dropdown
			if (data.length > 10) {
				html += `<select class="favtag-btn">
							<option selected disabled>...</option>`;

				for (var i = 10; i < data.length; i++) {

					category = data[i];
					catName = encode(category.name);

					html += `<option id='${category.id}' onclick='toggleCategory(this)'>
								${catName}
							 </option>`;

				}
				html += "</select>";
			}

			$("#category-container").html(html);

		}).fail(data => showErrorToast("Couldn't load categories", data.error));
}

function encode(r){
	return r.replace(/[\x26\x0A\<>'"]/g,function(r){return"&#"+r.charCodeAt(0)+";"})
}