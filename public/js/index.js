/**
 * Non-DataTables Index functions.
 * (The split is there to permit easier switch if we ever yeet datatables from the main UI)
 */
const Index = {};
Index.selectedCategory = "";
Index.awesomplete = {};
Index.serverVersion = "";
Index.debugMode = false;
Index.isProgressLocal = true;
Index.pageSize = 100;

/**
 * Initialize the Archive Index.
 */
Index.initializeAll = function () {
    // Bind events to DOM
    $(document).on("click.save-settings", "#save-settings", Index.saveSettings);

    $(document).on("click.settings-btn", "#settings-btn", LRR.openSettings);
    $(document).on("click.close_overlay", "#overlay-shade", LRR.closeOverlay);

    // Get some info from the server: version, debug mode, local progress
    Server.callAPI("/api/info", "GET", null, "Error getting basic server info!", (data) => {
        Index.serverVersion = data.version;
        Index.debugMode = data.debug_mode;
        Index.isProgressLocal = data.server_tracks_progress;
        Index.pageSize = data.archives_per_page;

        // Check version if not in debug mode
        if (!Index.debugMode) {
            Index.checkVersion();
            Index.fetchChangelog();
        } else {
            $.toast({
                heading: "<i class=\"fas fa-bug\"></i> You're running in Debug Mode!",
                text: "Advanced server statistics can be viewed <a href=\"./debug\">here.</a>",
                hideAfter: false,
                position: "top-left",
                icon: "warning",
            });
        }

        Index.migrateProgress();
        Index.loadTagSuggestions();
        Index.loadCategories();

        // Initialize DataTables
        IndexTable.initializeAll();
    });

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
            heading: `Welcome to LANraragi ${Index.serverVersion}!`,
            text: "If you want to perform advanced operations on an archive, remember to just right-click its name. Happy reading!",
            hideAfter: false,
            position: "top-left",
            icon: "info",
        });
    }

    // 0 = List view
    // 1 = Thumbnail view
    // List view is at 0 but became the non-default state later so here's some legacy weirdness
    if (localStorage.indexViewMode === "0") $("#compactmode").prop("checked", true);
    if (localStorage.cropthumbs === "true") $("#cropthumbs").prop("checked", true);

    Index.updateTableHeaders();
};

/**
 * Toggles a category filter.
 * Sets the internal selectedCategory variable and changes the button's class.
 * @param {*} button Button matching the category.
 */
Index.toggleCategory = function (button) {
    // Add/remove class to button depending on the state
    const categoryId = button.id;
    if (Index.selectedCategory === categoryId) {
        button.classList.remove("toggled");
        Index.selectedCategory = "";
    } else {
        Index.selectedCategory = categoryId;
        button.classList.add("toggled");
    }

    // Trigger search
    IndexTable.doSearch();
};

/**
 * Save settings to localStorage.
 */
Index.saveSettings = function () {
    localStorage.indexViewMode = $("#compactmode").prop("checked") ? 0 : 1;
    localStorage.cropthumbs = $("#cropthumbs").prop("checked");

    if (!LRR.isNullOrWhitespace($("#customcol1").val())) localStorage.customColumn1 = $("#customcol1").val().trim();
    if (!LRR.isNullOrWhitespace($("#customcol2").val())) localStorage.customColumn2 = $("#customcol2").val().trim();

    // Absolutely disgusting
    IndexTable.dataTable.settings()[0].aoColumns[1].sName = localStorage.customColumn1;
    IndexTable.dataTable.settings()[0].aoColumns[2].sName = localStorage.customColumn2;

    Index.updateTableHeaders();
    LRR.closeOverlay();

    // Redraw the table yo
    IndexTable.dataTable.draw();
};

/**
 * Update the Table Headers based on the custom namespaces set in localStorage.
 */
Index.updateTableHeaders = function () {
    const cc1 = localStorage.customColumn1;
    const cc2 = localStorage.customColumn2;

    $("#customcol1").val(cc1);
    $("#customcol2").val(cc2);
    $("#customheader1").children()[0].innerHTML = cc1.charAt(0).toUpperCase() + cc1.slice(1);
    $("#customheader2").children()[0].innerHTML = cc2.charAt(0).toUpperCase() + cc2.slice(1);
};

/**
 * Check the Github API to see if an update was released.
 * If so, flash another friendly notification inviting the user to check it out
 */
Index.checkVersion = function () {
    const githubAPI = "https://api.github.com/repos/difegue/lanraragi/releases/latest";

    $.getJSON(githubAPI).done((data) => {
        const expr = /(\d+)/g;
        const latestVersionArr = Array.from(data.tag_name.match(expr));
        let latestVersion = "";
        const currentVersionArr = Array.from(Index.serverVersion.match(expr));
        let currentVersion = "";

        latestVersionArr.forEach((element, index) => {
            if (index + 1 < latestVersionArr.length) {
                latestVersion = `${latestVersion}${element}`;
            } else {
                latestVersion = `${latestVersion}.${element}`;
            }
        });
        currentVersionArr.forEach((element, index) => {
            if (index + 1 < currentVersionArr.length) {
                currentVersion = `${currentVersion}${element}`;
            } else {
                currentVersion = `${currentVersion}.${element}`;
            }
        });

        if (latestVersion > currentVersion) {
            $.toast({
                heading: `A new version of LANraragi (${data.tag_name}) is available !`,
                text: `<a href="${data.html_url}">Click here to check it out.</a>`,
                hideAfter: false,
                position: "top-left",
                icon: "info",
            });
        }
    });
};

/**
 * Fetch the latest LRR changelog and show it to the user if he just updated
 */
Index.fetchChangelog = function () {
    if (localStorage.lrrVersion !== Index.serverVersion) {
        localStorage.lrrVersion = Index.serverVersion;

        fetch("https://api.github.com/repos/difegue/lanraragi/releases/latest", { method: "GET" })
            .then((response) => (response.ok ? response.json() : { error: "Response was not OK" }))
            .then((data) => {
                if (data.error) throw new Error(data.error);

                if (data.state === "failed") {
                    throw new Error(data.result);
                }

                marked(data.body, {
                    gfm: true,
                    breaks: true,
                    sanitize: true,
                }, (err, html) => {
                    document.getElementById("changelog").innerHTML = html;
                    $("#updateOverlay").scrollTop(0);
                });

                $("#overlay-shade").fadeTo(150, 0.6, () => {
                    $("#updateOverlay").css("display", "block");
                });
            })
            .catch((error) => { LRR.showErrorToast("Error getting changelog for new version", error); });
    }
};

/**
 * Load the categories a given ID belongs to.
 * @param {*} id The ID of the archive to check
 * @returns Categories
 */
Index.loadContextMenuCategories = function (id) {
    return Server.callAPI(`/api/archives/${id}/categories`, "GET", null, `Error finding categories for ${id}!`,
        (data) => {
            const items = {};

            for (let i = 0; i < data.categories.length; i++) {
                const cat = data.categories[i];
                items[`delcat-${cat.id}`] = { name: cat.name, icon: "fas fa-stream" };
            }

            if (Object.keys(items).length === 0) {
                items.noop = { name: "This archive isn't in any category.", icon: "far fa-sad-cry" };
            }

            return items;
        });
};

/**
 * Handle context menu clicks.
 * @param {*} option The clicked option
 * @param {*} id The Archive ID
 * @returns
 */
Index.handleContextMenu = function (option, id) {
    if (option.startsWith("category-")) {
        const catId = option.replace("category-", "");
        Server.addArchiveToCategory(id, catId);
        return;
    }

    if (option.startsWith("delcat-")) {
        const catId = option.replace("delcat-", "");
        Server.removeArchiveFromCategory(id, catId);
        return;
    }

    switch (option) {
    case "edit":
        LRR.openInNewTab(`./edit?id=${id}`);
        break;
    case "delete":
        if (confirm("Are you sure you want to delete this archive?")) {
            Server.deleteArchive(id, () => { document.location.reload(true); });
        }
        break;
    case "read":
        LRR.openInNewTab(`./reader?id=${id}`);
        break;
    case "download":
        LRR.openInNewTab(`./api/archives/${id}/download`);
        break;
    default:
        break;
    }
};

/**
 * Load tag suggestions for the tag search bar.
 */
Index.loadTagSuggestions = function () {
    // Query the tag cloud API to get the most used tags.
    Server.callAPI("/api/database/stats?minweight=2", "GET", null, "Couldn't load tag suggestions",
        (data) => {
            Index.awesomplete = new Awesomplete("#search-input", {
                list: data,
                data(tag) {
                    // Format tag objects from the API into a format awesomplete likes.
                    let label = tag.text;
                    if (tag.namespace !== "") label = `${tag.namespace}:${tag.text}`;

                    return { label, value: tag.weight };
                },
                // Sort by weight
                sort(a, b) {
                    return b.value - a.value;
                },
                filter(text, input) {
                    return Awesomplete.FILTER_CONTAINS(text, input.match(/[^, -]*$/)[0]);
                },
                item(text, input) {
                    return Awesomplete.ITEM(text, input.match(/[^, -]*$/)[0]);
                },
                replace(text) {
                    const before = this.input.value.match(/^.*(,|-)\s*-*|/)[0];
                    this.input.value = `${before + text}, `;
                },
            });
        });
};

/**
 * Query the category API to build the filter buttons.
 */
Index.loadCategories = function () {
    Server.callAPI("/api/categories", "GET", null, "Couldn't load categories",
        (data) => {
            // Sort by LastUsed + pinned
            // Pinned categories are shown at the beginning
            data.sort((a, b) => parseFloat(b.last_used) - parseFloat(a.last_used));
            data.sort((a, b) => parseFloat(b.pinned) - parseFloat(a.pinned));
            let html = "";

            const iteration = (data.length > 10 ? 10 : data.length);

            for (let i = 0; i < iteration; i++) {
                const category = data[i];
                const pinned = category.pinned === "1";

                let catName = (pinned ? "📌" : "") + category.name;
                catName = LRR.encodeHTML(catName);

                const div = `<div style='display:inline-block'>
                    <input class='favtag-btn ${((category.id === Index.selectedCategory) ? "toggled" : "")}' 
                            type='button' id='${category.id}' value='${catName}' 
                            onclick='Index.toggleCategory(this)' title='Click here to display the archives contained in this category.'/>
                </div>`;

                html += div;
            }

            // If more than 10 categories, the rest goes into a dropdown
            if (data.length > 10) {
                html += `<select id="catdropdown" class="favtag-btn">
                            <option selected disabled>...</option>`;

                for (let i = 10; i < data.length; i++) {
                    const category = data[i];

                    html += `<option id='${category.id}'>
                                ${LRR.encodeHTML(category.name)}
                            </option>`;
                }
                html += "</select>";
            }

            $("#category-container").html(html);

            // Add a listener on dropdown selection
            $("#catdropdown").on("change", () => Index.toggleCategory($("#catdropdown")[0].selectedOptions[0]));
        });
};

/**
 * If server-side progress tracking is enabled, migrate local progression to the server.
 */
Index.migrateProgress = function () {
    // No migration if local progress is enabled
    if (Index.isProgressLocal) {
        return;
    }

    const localProgressKeys = Object.keys(localStorage).filter((x) => x.endsWith("-reader")).map((x) => x.slice(0, -7));
    if (localProgressKeys.length > 0) {
        $.toast({
            heading: "Your Reading Progression is now saved on the server!",
            text: "You seem to have some local progression hanging around -- Please wait warmly while we migrate it to the server for you. ☕",
            hideAfter: false,
            position: "top-left",
            icon: "info",
        });

        const promises = [];
        localProgressKeys.forEach((id) => {
            const progress = localStorage.getItem(`${id}-reader`);

            promises.push(fetch(`api/archives/${id}/metadata`, { method: "GET" })
                .then((response) => response.json())
                .then((data) => {
                    // Don't migrate if the server progress is already further
                    if (progress !== null && data !== undefined && data !== null && progress > data.progress) {
                        Server.callAPI(`api/archives/${id}/progress/${progress}?force=1`, "PUT", null, "Error updating reading progress!", null);
                    }

                    // Clear out localStorage'd progress
                    localStorage.removeItem(`${id}-reader`);
                    localStorage.removeItem(`${id}-totalPages`);
                }));
        });

        Promise.all(promises).then(() => $.toast({
            heading: "Reading Progression has been fully migrated! 🎉",
            text: "You'll have to reopen archives in the Reader to see the migrated progression values.",
            hideAfter: false,
            position: "top-left",
            icon: "success",
        }));
    } else {
        console.log("No local reading progression to migrate");
    }
};

window.Index = Index;
