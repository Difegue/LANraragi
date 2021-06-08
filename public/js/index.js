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

	updateToggleClass(button);

	//Redraw the table 
	performSearch();
}

function updateToggleClass(button) {

	if (button.prop("checked"))
		button.addClass("toggled");
	else
		button.removeClass("toggled");
}

function initSettings(version) {

	// Default to thumbnail mode
	if (localStorage.getItem("indexViewMode") === null) {
		localStorage.indexViewMode = 1;
	}

	// Default to crop landscape
	if (localStorage.getItem("cropthumbs") === null) {
		localStorage.cropthumbs = true;
	}

	// Default custom columns
	if (localStorage.getItem("customColumn1") === null) {
		localStorage.customColumn1 = "artist";
		localStorage.customColumn2 = "series";
	}

	// Tell user about the context menu
	if (localStorage.getItem("sawContextMenuToast") === null) {
		localStorage.sawContextMenuToast = true;

		$.toast({
			heading: `Welcome to LANraragi ${version}!`,
			text: "If you want to perform advanced operations on an archive, remember to just right-click its name. Happy reading!",
			hideAfter: false,
			position: 'top-left',
			icon: 'info'
		});
	}

	//0 = List view
	//1 = Thumbnail view
	// List view is at 0 but became the non-default state later so here's some legacy weirdness 
	if (localStorage.indexViewMode == 0)
		$("#compactmode").prop("checked", true);

	if (localStorage.cropthumbs === 'true')
		$("#cropthumbs").prop("checked", true);

	updateTableHeaders();
}

function isNullOrWhitespace(input) {
	return !input || !input.trim();
}

function saveSettings() {
	localStorage.indexViewMode = $("#compactmode").prop("checked") ? 0 : 1;
	localStorage.cropthumbs = $("#cropthumbs").prop("checked");

	if (!isNullOrWhitespace($("#customcol1").val()))
		localStorage.customColumn1 = $("#customcol1").val().trim();

	if (!isNullOrWhitespace($("#customcol2").val()))
		localStorage.customColumn2 = $("#customcol2").val().trim();

	// Absolutely disgusting
	arcTable.settings()[0].aoColumns[1].sName = localStorage.customColumn1;
	arcTable.settings()[0].aoColumns[2].sName = localStorage.customColumn2;

	updateTableHeaders();
	closeOverlay();

	//Redraw the table yo
	arcTable.draw();
}

function updateTableHeaders() {

	var cc1 = localStorage.customColumn1;
	var cc2 = localStorage.customColumn2;

	$("#customcol1").val(cc1);
	$("#customcol2").val(cc2);
	$("#customheader1").children()[0].innerHTML = cc1.charAt(0).toUpperCase() + cc1.slice(1);
	$("#customheader2").children()[0].innerHTML = cc2.charAt(0).toUpperCase() + cc2.slice(1);
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

function loadContextMenuCategories(id) {
	return genericAPICall(`/api/archives/${id}/categories`, 'GET', null, `Error finding categories for ${id}!`,
		function (data) {

			items = {};

			for (let i = 0; i < data.categories.length; i++) {
				cat = data.categories[i];
				items[`delcat-${cat.id}`] = { "name": cat.name, "icon": "fas fa-stream" };
			}

			if (Object.keys(items).length === 0) {
				items["noop"] = { "name": "This archive isn't in any category.", "icon": "far fa-sad-cry" };
			}

			return items;
		});
}

function handleContextMenu(option, id) {

	if (option.startsWith("category-")) {
		var catId = option.replace("category-", "");
		addArchiveToCategory(id, catId);
		return;
	}

	if (option.startsWith("delcat-")) {
		var catId = option.replace("delcat-", "");
		removeArchiveFromCategory(id, catId);
		return;
	}

	switch (option) {
		case "edit":
			openInNewTab("./edit?id=" + id);
			break;
		case "delete":
			if (confirm('Are you sure you want to delete this archive?'))
				deleteArchive(id);
			break;
		case "read":
			openInNewTab(`./reader?id=${id}`);
			break;
		case "download":
			openInNewTab(`./api/archives/${id}/download`);
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
				html += `<select id="catdropdown" class="favtag-btn">
							<option selected disabled>...</option>`;

				for (var i = 10; i < data.length; i++) {

					category = data[i];
					catName = encode(category.name);

					html += `<option id='${category.id}'>
								${catName}
							 </option>`;

				}
				html += "</select>";
			}

			$("#category-container").html(html);

			// Add a listener on dropdown selection
			$("#catdropdown").on("change", () => toggleCategory($("#catdropdown")[0].selectedOptions[0]));

		}).fail(data => showErrorToast("Couldn't load categories", data.error));
}

function migrateProgress() {
	localProgressKeys = Object.keys(localStorage).filter(x => x.endsWith("-reader")).map(x => x.slice(0, -7));

	if (localProgressKeys.length > 0) {
		$.toast({
			heading: 'Your Reading Progression is now saved on the server!',
			text: 'You seem to have some local progression hanging around -- Please wait warmly while we migrate it to the server for you. ☕',
			hideAfter: false,
			position: 'top-left',
			icon: 'info'
		});

		var promises = [];
		localProgressKeys.forEach(id => {

			var progress = localStorage.getItem(id + "-reader");

			promises.push(fetch(`api/archives/${id}/metadata`, { method: 'GET' })
				.then(response => response.json())
				.then((data) => {
					// Don't migrate if the server progress is already further
					if (progress !== null && data !== undefined && data !== null && progress > data.progress) {
						genericAPICall(`api/archives/${id}/progress/${progress}?force=1`, "PUT", null, "Error updating reading progress!", null);
					}

					// Clear out localStorage'd progress
					localStorage.removeItem(id + "-reader");
					localStorage.removeItem(id + "-totalPages");
				}));
		});

		Promise.all(promises).then(() => $.toast({
			heading: 'Reading Progression has been fully migrated! 🎉',
			text: 'You\'ll have to reopen archives in the Reader to see the migrated progression values.',
			hideAfter: false,
			position: 'top-left',
			icon: 'success'
		}));
	} else {
		console.log("No local reading progression to migrate");
	}
}