/**
 * Non-DataTables Index functions.
 * (The split is there to permit easier switch if we ever yeet datatables from the main UI)
 * @global
 */
const Index = {};
Index.selectedCategory = "";
Index.awesomplete = {};
Index.carouselInitialized = false;
Index.swiper = {};
Index.serverVersion = "";
Index.debugMode = false;
Index.isProgressLocal = true;
Index.isProgressAuthenticated = true;
Index.pageSize = 100;
Index.pseudoCopyBtn = undefined;

/**
 * Initialize the Archive Index.
 */
Index.initializeAll = function () {
    // Bind events to DOM
    $(document).on("click", "[id^=edit-header-]", function () {
        const headerIndex = $(this).attr("id").split("-")[2];
        Index.promptCustomColumn(headerIndex);
    });
    $(document).on("click.mode-toggle", ".mode-toggle", Index.toggleMode);
    $(document).on("change.page-select", "#page-select", () => IndexTable.dataTable.page($("#page-select").val() - 1).draw("page"));
    $(document).on("change.thumbnail-crop", "#thumbnail-crop", Index.toggleCrop);
    $(document).on("change.group-tanks", ".group-tanks", Index.toggleGroupTanks);
    $(document).on("change.namespace-sortby", "#namespace-sortby", Index.handleCustomSort);
    $(document).on("change.columnCount", "#columnCount", Index.handleColumnNum);
    $(document).on("click.order-sortby", "#order-sortby", Index.toggleOrder);
    $(document).on("click.open-carousel", ".collapsible-title", Index.toggleCarousel);
    $(document).on("click.reload-carousel", "#reload-carousel", Index.updateCarousel);
    $(document).on("click.close-overlay", "#overlay-shade", LRR.closeOverlay);
    $(document).on("click.thumbnail-bookmark-icon", ".thumbnail-bookmark-icon", Index.toggleBookmarkStatusByIcon);
    $(document).on("click.title-bookmark-icon", ".title-bookmark-icon", Index.toggleBookmarkStatusByIcon);
    $(document).on("keydown.quick-search", Index.handleQuickSearch);
    $(document).on("keydown.escape-overlay", Index.handleEscapeKey);

    // Selection bar and tank selector event handlers
    $(document).on("change.archive-checkbox", ".archive-checkbox", function () {
        Index.toggleArchiveSelection($(this).data("id"), this.checked);
    });
    $(document).on("click.select-page", "#select-page-btn", Index.selectCurrentPage);
    $(document).on("click.deselect-page", "#deselect-page-btn", Index.deselectCurrentPage);
    $(document).on("click.add-to-tank", "#add-to-tank-btn", Index.openTankSelector);
    $(document).on("click.clear-selection", "#clear-selection-btn", Index.clearSelection);
    $(document).on("click.create-tank", "#create-tank-btn", Index.openCreateTankDialog);
    $(document).on("click.cancel-tank", "#cancel-tank-btn", LRR.closeOverlay);

    // 0 = List view
    // 1 = Thumbnail view
    // List view is at 0 but became the non-default state later so here's some legacy weirdness
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

    // Default to on deck for carousel
    if (localStorage.getItem("carouselType") === null) {
        localStorage.carouselType = "ondeck";
    }

    // Default to opened carousel
    if (localStorage.getItem("carouselOpen") === null) {
        localStorage.carouselOpen = 1;
    }

    // Force-open the collapsible if carouselOpen = true
    if (localStorage.carouselOpen === "1") {
        $(".collapsible-title").trigger("click", [false]);
        // Index.updateCarousel(); will be executed by toggleCarousel
    } else {
        Index.updateCarousel();
    }

    // Initialize carousel mode menu
    $.contextMenu({
        selector: "#carousel-mode-menu",
        trigger: "left",
        build: () => ({
            callback(key) {
                localStorage.carouselType = key;
                Index.updateCarousel();
            },
            items: {
                ondeck: { name: I18N.CarouselOnDeck, icon: "fas fa-book-reader" },
                random: { name: I18N.CarouselRandom, icon: "fas fa-random" },
                inbox: { name: I18N.NewArchives, icon: "fas fa-envelope-open-text" },
                untagged: { name: I18N.UntaggedArchives, icon: "fas fa-edit" },
            },
        }),
    });

    // Tell user about the context menu
    if (localStorage.getItem("sawContextMenuToast") === null) {
        localStorage.sawContextMenuToast = true;

        LRR.toast({
            heading: I18N.IndexWelcome(Index.serverVersion),
            text: I18N.IndexWelcome2,
            icon: "info",
            hideAfter: 13000,
        });
    }

    // Get some info from the server: version, debug mode, local progress
    Server.callAPI("/api/info", "GET", null, I18N.ServerInfoError,
        (data) => {
            Index.serverVersion = data.version;
            Index.debugMode = !!data.debug_mode;
            Index.isProgressLocal = !data.server_tracks_progress;
            Index.isProgressAuthenticated = data.authenticated_progress;
            Index.pageSize = data.archives_per_page;

            // Check version if not in debug mode
            if (!Index.debugMode) {
                Index.checkVersion();
                Index.fetchChangelog();
            } else {
                LRR.toast({
                    heading: `<i class="fas fa-bug"></i> ` + I18N.DebugModeHeader,
                    text: I18N.DebugModeDesc(new LRR.apiURL("/debug")),
                    icon: "warning",
                });
            }

            Index.migrateProgress();
            Index.loadTagSuggestions();

            // Make bookmark category ID available to index and indextable
            Server.loadBookmarkCategoryId()
                .then(() => Index.loadCategories())
                .then(() => IndexTable.initializeAll())
                .catch(error => console.error("Error initializing index:", error));
        });

    const columnCountSelect = document.getElementById("columnCount");
    columnCountSelect.value = Index.getColumnCount();

    Index.updateTableHeaders();
    Index.resizableColumns();

    Index.pseudoCopyBtn = $("#pseudo-copy-btn")
    Index.clipboard = new window.ClipboardJS("#pseudo-copy-btn");

    Index.clipboard.on("success", function (e) {
        LRR.toast({
            heading: I18N.IndexCopyLinkSuccess,
            icon: "info",
            hideAfter: 3000,
        });
        e.clearSelection();
    });

    Index.clipboard.on("error", function (e) {
        LRR.toast({
            heading: I18N.IndexCopyLinkFail,
            icon: "error",
            hideAfter: false,
        });
    });
};

// Turn bookmark icons to OFF for all archives.
Index.bookmarkIconOff = function (arcid) {
    const icons = document.querySelectorAll(`.title-bookmark-icon[id='${arcid}'], .thumbnail-bookmark-icon[id='${arcid}']`);
    icons.forEach(el => {
        el.classList.remove("fas");
        el.classList.add("far");
    })
}

// Turn bookmark icons to ON for all archives.
Index.bookmarkIconOn = function (arcid) {
    const icons = document.querySelectorAll(`.title-bookmark-icon[id='${arcid}'], .thumbnail-bookmark-icon[id='${arcid}']`);
    icons.forEach(el => {
        el.classList.remove("far");
        el.classList.add("fas");
    })
}

Index.toggleBookmarkStatusByIcon = function (e) {
    const icon = e.currentTarget;
    const id = icon.id;

    if (!LRR.isUserLogged()) {
        LRR.toast({
            heading: I18N.LoginRequired(new LRR.apiURL("/login")),
            icon: "warning",
            hideAfter: 5000,
        });
        return;
    }

    if (icon.classList.contains("far")) {
        Server.addArchiveToCategory(id, localStorage.getItem("bookmarkCategoryId"));
        Index.bookmarkIconOn(id);
    } else if (icon.classList.contains("fas")) {
        Server.removeArchiveFromCategory(id, localStorage.getItem("bookmarkCategoryId"));
        Index.bookmarkIconOff(id);
    }
};

/**
 * Handle quick search functionality. If user is in index page and
 * presses "/" key, focus to search input. If the release overlay
 * is open, closes it before focusing to search input.
 * 
 * @param {KeyboardEvent} e - The keyboard event
 */
Index.handleQuickSearch = function (e) {
    if (e.key !== "/") return;
    if (e.target.tagName === "INPUT") return;
    if (e.ctrlKey || e.altKey || e.shiftKey || e.metaKey) return;
    e.preventDefault();
    if ($("#overlay-shade").is(":visible")) LRR.closeOverlay();
    $("#search-input")[0].focus();
};

/**
 * Handle escape key to close overlays.
 * @param {KeyboardEvent} e - The keyboard event
 */
Index.handleEscapeKey = function (e) {
    if (e.key !== "Escape") return;
    if (e.target.tagName === "INPUT") return;
    LRR.closeOverlay();
};

Index.toggleMode = function () {
    localStorage.indexViewMode = (localStorage.indexViewMode === "1") ? "0" : "1";
    IndexTable.dataTable.draw();
};

Index.toggleCarousel = function (e, updateLocalStorage = true) {
    if (updateLocalStorage) localStorage.carouselOpen = (localStorage.carouselOpen === "1") ? "0" : "1";

    if (!Index.carouselInitialized) {
        Index.carouselInitialized = true;
        $("#reload-carousel").show();

        Index.swiper = new Swiper(".index-carousel-container", {
            breakpoints: (() => {
                const breakpoints = {
                    0: { // ensure every device have at least 1 slide
                        slidesPerView: 1,
                    },
                };
                // virtual Slides doesn't work with slidesPerView: 'auto'
                // the following loops are meant to implement same functionality by doing mathworks
                // it also helps avoid writing a billion slidesPerView combos for window widths
                // when the screen width <= 560px, every thumbnails have a different width
                // from 169px, when the width is 17px bigger, we display 0.1 more slide
                for (let width = 169, sides = 1; width <= 424; width += 17, sides += 0.1) {
                    breakpoints[width] = {
                        slidesPerView: sides,
                    };
                }
                // from 427px, when the width is 46px bigger, we display 0.2 more slide
                // the width support up to 4K resolution
                for (let width = 427, sides = 1.8; width <= 3840; width += 46, sides += 0.2) {
                    breakpoints[width] = {
                        slidesPerView: sides,
                    };
                }
                return breakpoints;
            })(),
            breakpointsBase: "container",
            centerInsufficientSlides: false,
            mousewheel: true,
            navigation: {
                nextEl: ".carousel-next",
                prevEl: ".carousel-prev",
            },
            slidesPerView: 7,
            virtual: {
                enabled: true,
                addSlidesAfter: 2,
                addSlidesBefore: 2,
            },
        });

        Index.updateCarousel();
    }
};

Index.toggleCrop = function () {
    localStorage.cropthumbs = $("#thumbnail-crop")[0].checked;
    IndexTable.dataTable.draw();
};

// Handler for .group-tanks checkboxes (duplicated in thumbnail-options and compact-options).
// Uses `this.checked` to read from whichever checkbox triggered the event.
// Both checkboxes are synced via localStorage in updateTableControls() after each table draw.
Index.toggleGroupTanks = function () {
    localStorage.grouptanks = this.checked;
    IndexTable.dataTable.draw();
};

// #region Archive Selection for Tankoubon

// Set to store selected archive IDs
Index.selectedArchives = new Set();
Index.tankAwesomplete = null;
Index.tankList = [];

/**
 * Check if the current selection contains any tankoubons.
 * @returns {boolean} True if any selected ID starts with "TANK_"
 */
Index.selectionContainsTanks = function () {
    return [...Index.selectedArchives].some(id => id.startsWith("TANK_"));
};

/**
 * Count tankoubons and archives in the current selection.
 * @returns {{archives: number, tanks: number}}
 */
Index.getSelectionCounts = function () {
    let archives = 0;
    let tanks = 0;
    Index.selectedArchives.forEach(id => {
        if (id.startsWith("TANK_")) {
            tanks++;
        } else {
            archives++;
        }
    });
    return { archives, tanks };
};

/**
 * Handle checkbox change for archive selection.
 * @param {string} arcid Archive ID
 * @param {boolean} checked Whether the checkbox is checked
 */
Index.toggleArchiveSelection = function (arcid, checked) {
    if (checked) {
        Index.selectedArchives.add(arcid);
    } else {
        Index.selectedArchives.delete(arcid);
    }
    Index.updateSelectionBar();
};

/**
 * Select all archives on the current page.
 */
Index.selectCurrentPage = function () {
    // Get all archive IDs from the current page
    const pageData = IndexTable.dataTable.rows({ page: "current" }).data();
    pageData.each((data) => {
        const id = data.arcid || data.id;
        Index.selectedArchives.add(id);
    });
    // Update all checkboxes on the page
    $(".archive-checkbox").prop("checked", true);
    Index.updateSelectionBar();
};

/**
 * Deselect all archives on the current page.
 */
Index.deselectCurrentPage = function () {
    // Get all archive IDs from the current page
    const pageData = IndexTable.dataTable.rows({ page: "current" }).data();
    pageData.each((data) => {
        const id = data.arcid || data.id;
        Index.selectedArchives.delete(id);
    });
    // Update all checkboxes on the page
    $(".archive-checkbox").prop("checked", false);
    Index.updateSelectionBar();
};

/**
 * Clear all selected archives.
 */
Index.clearSelection = function () {
    Index.selectedArchives.clear();
    $(".archive-checkbox").prop("checked", false);
    Index.updateSelectionBar();
};

/**
 * Update the selection bar visibility and count.
 */
Index.updateSelectionBar = function () {
    const count = Index.selectedArchives.size;
    const addToTankBtn = document.getElementById("add-to-tank-btn");

    if (count > 0) {
        const counts = Index.getSelectionCounts();

        // Update display text - show mixed count if tankoubons are selected
        if (counts.tanks > 0) {
            $("#selection-count").text(I18N.SelectionCountMixed(counts.archives, counts.tanks));
        } else {
            $("#selection-count").text(I18N.SelectionCount(count));
        }

        // Enable/disable Add to Tankoubon button based on whether tankoubons are selected
        if (counts.tanks > 0) {
            addToTankBtn.disabled = true;
            addToTankBtn.title = I18N.CannotAddTanksToTank;
        } else {
            addToTankBtn.disabled = false;
            addToTankBtn.title = "";
        }

        $("#selection-bar").show();
    } else {
        $("#selection-bar").hide();
    }
};

/**
 * Open the tank selector overlay.
 */
Index.openTankSelector = function () {
    // Fetch tank list and initialize awesomplete
    Server.getTankoubonList((data) => {
        Index.tankList = data.result || [];
        Index.initTankAwesomplete();
        LRR.toggleOverlay("#tank-overlay");
        $("#tank-input").val("").focus();
    });
};

/**
 * Initialize Awesomplete for tank selection.
 */
Index.initTankAwesomplete = function () {
    // Destroy previous instance if exists
    if (Index.tankAwesomplete) {
        Index.tankAwesomplete.destroy();
    }

    const input = document.getElementById("tank-input");

    Index.tankAwesomplete = new Awesomplete(input, {
        list: Index.tankList,
        data(tank) {
            return { label: tank.name, value: tank.id };
        },
        filter(text, input) {
            return Awesomplete.FILTER_CONTAINS(text, input);
        },
        item(text, input) {
            return Awesomplete.ITEM(text, input);
        },
        replace(text) {
            this.input.value = text.label;
        },
        minChars: 0,
        maxItems: 10,
    });

    // Show all items when focusing on empty input
    input.addEventListener("focus", () => {
        if (input.value === "") {
            Index.tankAwesomplete.evaluate();
        }
    });

    // Handle selection
    input.addEventListener("awesomplete-selectcomplete", (e) => {
        const tankId = e.text.value;
        const tankName = e.text.label;
        Index.addSelectedToTank(tankId, tankName);
    });
};

/**
 * Add selected archives to a tankoubon.
 * @param {string} tankId Tankoubon ID
 * @param {string} tankName Tankoubon name for display
 */
Index.addSelectedToTank = function (tankId, tankName) {
    const archiveIds = Array.from(Index.selectedArchives);

    Server.addArchivesToTankoubon(tankId, archiveIds, (data) => {
        LRR.toast({
            heading: I18N.AddedToTankoubon(data.added, tankName),
            icon: "success",
        });

        // Close overlay and clear selection
        LRR.closeOverlay();
        Index.clearSelection();
    });
};

/**
 * Open the create new tankoubon dialog.
 */
Index.openCreateTankDialog = function () {
    // Close the tank overlay first so SweetAlert isn't blocked
    LRR.closeOverlay();

    LRR.showPopUp({
        title: I18N.NewTankoubon,
        input: "text",
        inputPlaceholder: I18N.TankoubonDefaultName,
        inputAttributes: {
            autocapitalize: "off",
        },
        showCancelButton: true,
        reverseButtons: true,
        inputValidator: (value) => {
            if (!value) {
                return I18N.MissingTankName;
            }
            return undefined;
        },
    }).then((result) => {
        if (result.isConfirmed) {
            Index.createAndAddToTank(result.value);
        }
    });
};

/**
 * Create a new tankoubon and add selected archives to it.
 * @param {string} name Name for the new tankoubon
 */
Index.createAndAddToTank = function (name) {
    Server.createTankoubon(name, (data) => {
        if (data.tankoubon_id) {
            Index.addSelectedToTank(data.tankoubon_id, name);
        }
    });
};

// #endregion

Index.toggleOrder = function (e) {
    e.preventDefault();
    const order = IndexTable.dataTable.order();
    order[0][1] = order[0][1] === "asc" ? "desc" : "asc";
    IndexTable.dataTable.order(order);
    IndexTable.dataTable.draw();
};

/**
 * Toggles a category filter.
 * Adds/removes the category from the selectedCategories Set and updates the button's class.
 * Multiple categories can be selected simultaneously (intersection/AND logic).
 * @param {*} button Button matching the category.
 */
Index.toggleCategory = function (button) {
    const categoryId = button.id;

    // Initialize Set if not yet done (shouldn't happen, but be defensive)
    if (!Index.selectedCategories) {
        Index.selectedCategories = new Set();
    }

    // Toggle category in the Set
    if (Index.selectedCategories.has(categoryId)) {
        Index.selectedCategories.delete(categoryId);
        button.classList.remove("toggled");
    } else {
        Index.selectedCategories.add(categoryId);
        button.classList.add("toggled");
    }

    // When TANKOUBONS_ONLY is selected, force grouptanks on since tanks only appear when grouped
    if (Index.selectedCategories.has("TANKOUBONS_ONLY")) {
        localStorage.grouptanks = "true";
    }

    // Trigger search
    IndexTable.doSearch();
};

/**
 * Show a prompt to update the namespace of a column in compact mode.
 * @param {*} column Index of the column to modify, either 1 or 2
 */
Index.promptCustomColumn = function (column) {
    LRR.showPopUp({
        title: I18N.CustomColumn,
        text: I18N.CustomColumnDesc + "\n" + I18N.CustomColumnDesc2,
        input: "text",
        inputValue: localStorage.getItem(`customColumn${column}`),
        inputPlaceholder: I18N.TagNamespace,
        inputAttributes: {
            autocapitalize: "off",
        },
        showCancelButton: true,
        reverseButtons: true,
        inputValidator: (value) => {
            if (!value) {
                return I18N.TagNamespaceError;
            }
            return undefined;
        },
    }).then((result) => {
        if (result.isConfirmed) {
            if (!LRR.isNullOrWhitespace(result.value)) {
                localStorage.setItem(`customColumn${column}`, result.value.trim());

                // Absolutely disgusting
                IndexTable.dataTable.settings()[0].aoColumns[column].sName = result.value.trim();
                Index.updateTableHeaders();
                IndexTable.doSearch();
            }
        }
    });
};

/**
 * Update table controls to reflect the current status.
 * @param {*} currentSort Current sort column
 * @param {*} currentOrder Current sort order
 * @param {*} totalPages Total pages of the table
 * @param {*} currentPage Current page of the table
 */
Index.updateTableControls = function (currentSort, currentOrder, totalPages, currentPage) {
    $(".table-options").show();
    $("#thumbnail-crop")[0].checked = localStorage.cropthumbs === "true";
    // Sync both .group-tanks checkboxes (one in thumbnail-options, one in compact-options)
    $(".group-tanks").prop("checked", localStorage.grouptanks === "true");

    $("#namespace-sortby").val(currentSort);
    $("#order-sortby")[0].classList.remove("fa-sort-alpha-down", "fa-sort-alpha-up");
    $("#order-sortby")[0].classList.add(currentOrder === "asc" ? "fa-sort-alpha-down" : "fa-sort-alpha-up");

    if (localStorage.indexViewMode === "1") {
        $(".thumbnail-options").show();
        $(".thumbnail-toggle").show();
        $(".compact-options").hide();
        $(".compact-toggle").hide();
    } else {
        $(".thumbnail-options").hide();
        $(".thumbnail-toggle").hide();
        $(".compact-options").show();
        $(".compact-toggle").show();
    }

    // Page selector
    const pageSelect = $("#page-select");
    pageSelect.empty();

    for (let j = 1; j <= totalPages; j++) {
        const oOption = document.createElement("option");
        oOption.text = j;
        oOption.value = j;
        pageSelect[0].add(oOption, null);
    }

    pageSelect.val(currentPage);
};

Index.handleCustomSort = function () {
    const namespace = $("#namespace-sortby").val();
    const order = IndexTable.dataTable.order();

    // Special case for title sorting, as that uses column 1 (0 is checkbox)
    if (namespace === "title") {
        order[0][0] = 1;
    } else {
        // The order set in the combobox uses is offset from title by 1; 
        // e.g. customColumn1 is offset from title by 2.
        order[0][0] = 2;
        localStorage.customColumn1 = namespace;
        IndexTable.dataTable.settings()[0].aoColumns[2].sName = namespace;
        Index.updateTableHeaders();
    }

    IndexTable.dataTable.order(order);
    IndexTable.dataTable.draw();
};

Index.updateCarousel = function (e) {
    e?.preventDefault();
    $("#carousel-empty").hide();
    $("#carousel-loading").show();
    $(".swiper-wrapper").hide();

    $("#reload-carousel").addClass("fa-spin");

    // Build category query params from selectedCategories Set
    // Pseudo-categories become their own params, real categories go into category= (comma-separated)
    const buildCategoryParams = () => {
        const params = [];
        const realCategories = [];

        // Handle case where selectedCategories isn't initialized yet (early carousel init)
        if (!Index.selectedCategories) {
            return "";
        }

        for (const cat of Index.selectedCategories) {
            if (cat === "NEW_ONLY") {
                params.push("newonly=true");
            } else if (cat === "UNTAGGED_ONLY") {
                params.push("untaggedonly=true");
            } else if (cat === "TANKOUBONS_ONLY") {
                params.push("tankoubonsonly=true");
            } else {
                realCategories.push(cat);
            }
        }

        if (realCategories.length > 0) {
            params.push(`category=${realCategories.join(",")}`);
        }

        return params.join("&");
    };

    const categoryParams = buildCategoryParams();

    // Hit a different API endpoint depending on the requested localStorage carousel type
    let endpoint;
    switch (localStorage.carouselType) {
        case "random":
            $("#carousel-icon")[0].classList = "fas fa-random";
            $("#carousel-title").text(I18N.CarouselRandom);
            endpoint = `/api/search/random?filter=${IndexTable.currentSearch}&count=15`;
            if (categoryParams) endpoint += `&${categoryParams}`;
            break;
        case "inbox":
            $("#carousel-icon")[0].classList = "fas fa-envelope-open-text";
            $("#carousel-title").text(I18N.NewArchives);
            endpoint = `/api/search?filter=${IndexTable.currentSearch}&newonly=true&sortby=date_added&order=desc&start=-1`;
            if (categoryParams) endpoint += `&${categoryParams}`;
            break;
        case "untagged":
            $("#carousel-icon")[0].classList = "fas fa-edit";
            $("#carousel-title").text(I18N.UntaggedArchives);
            endpoint = `/api/search?filter=${IndexTable.currentSearch}&untaggedonly=true&sortby=date_added&order=desc&start=-1`;
            if (categoryParams) endpoint += `&${categoryParams}`;
            break;
        case "ondeck":
            $("#carousel-icon")[0].classList = "fas fa-book-reader";
            $("#carousel-title").text(I18N.CarouselOnDeck);
            endpoint = `/api/search?filter=${IndexTable.currentSearch}&sortby=lastread`;
            break;
        default:
            $("#carousel-icon")[0].classList = "fas fa-pastafarianism";
            $("#carousel-title").text("What???");
            endpoint = `/api/search?filter=${IndexTable.currentSearch}`;
            if (categoryParams) endpoint += `&${categoryParams}`;
            break;
    }

    if (Index.carouselInitialized) {
        Server.callAPI(endpoint, "GET", null, I18N.CarouselError,
            (results) => {
                Index.swiper.virtual.removeAllSlides();
                const slides = results.data
                    .map((archive) => LRR.buildThumbnailDiv(archive, true, false));
                Index.swiper.virtual.appendSlide(slides);
                Index.swiper.virtual.update();

                if (results.data.length === 0) {
                    $("#carousel-empty").show();
                }

                $("#carousel-loading").hide();
                $(".swiper-wrapper").show();
                $("#reload-carousel").removeClass("fa-spin");
            },
        );
    }
};

Index.handleColumnNum = function () {
    const columnCountSelect = document.getElementById("columnCount");
    const selectedCount = columnCountSelect.value;
    localStorage.setItem("columnCount", selectedCount);
    Index.updateTableHeaders();
    document.location.reload(true);
};

/**
 * Generate the Table Headers based on the custom namespaces set in localStorage.
 */
Index.generateTableHeaders = function (columnCount) {
    const headerRow = $("#header-row");
    headerRow.empty();
    // Checkbox column header (no title, just empty)
    headerRow.append(`<th id="checkboxheader" class="selection-checkbox"></th>`);
    const headerWidth = localStorage.getItem(`resizeColumn0`) || "";
    headerRow.append(`
        <th id="titleheader" width="${headerWidth}">
            <a>${I18N.IndexTitle}</a>
        </th>`);

    for (let i = 1; i <= columnCount; i++) {
        const customColumn = localStorage[`customColumn${i}`] || `Header ${i}`;
        const colWidth = localStorage.getItem(`resizeColumn${i}`) || "";

        const headerHtml = `
            <th id="customheader${i}" width="${colWidth}">
                <i id="edit-header-${i}" class="fas fa-pencil-alt edit-header-btn" title="${I18N.IndexEditColumn}"></i>
                <a id="header-${i}">${customColumn.charAt(0).toUpperCase() + customColumn.slice(1)}</a>
            </th>`;
        headerRow.append(headerHtml);
    }
    headerRow.append(`
        <th id="tagsheader">
            <a>${I18N.IndexTags}</a>
        </th>`);
};


/**
 * Update the Table Headers based on the custom namespaces set in localStorage.
 */
Index.updateTableHeaders = function () {
    let columnCount = Index.getColumnCount();
    Index.generateTableHeaders(columnCount);

    for (let i = 1; i <= columnCount; i++) {
        const customColumn = localStorage[`customColumn${i}`] || `${I18N.IndexHeader} ${i}`;
        $(`#customcol${i}`).val(customColumn);

        $(`#header-${i}`).html(customColumn.charAt(0).toUpperCase() + customColumn.slice(1) || `${I18N.IndexHeader} ${i}`);
    }
};

/**
 * Check the GitHub API to see if an update was released.
 * If so, flash another friendly notification inviting the user to check it out
 */
Index.checkVersion = function () {
    const githubAPI = "https://api.github.com/repos/difegue/lanraragi/releases/latest";

    fetch(githubAPI)
        .then((response) => {
            if (response.ok) {
                return response.json();
            }
            if (response.status === 403) {
                console.error("Github API rate limit exceeded: ", response);
                throw new Error(I18N.IndexGithubRateLimitError);
            }
            console.error("GitHub API returned: ", response);
            throw new Error(I18N.IndexGithubAPIError(response.status));
        })
        .then((data) => {
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
                LRR.toast({
                    heading: I18N.IndexUpdateNotif(data.tag_name),
                    text: `<a href="${data.html_url}">${I18N.IndexUpdateNotif2}</a>`,
                    icon: "info",
                    closeOnClick: false,
                    draggable: false,
                    hideAfter: 7000,
                });
            }
        })
        .catch((error) => console.log("Error checking latest version.", error));
};

/**
 * Fetch the latest LRR changelog and show it to the user if he just updated
 */
Index.fetchChangelog = function () {
    if (localStorage.lrrVersion !== Index.serverVersion) {
        localStorage.lrrVersion = Index.serverVersion;

        fetch("https://api.github.com/repos/difegue/lanraragi/releases/latest", { method: "GET" })
            .then((response) => {
                if (response.ok) {
                    return response.json();
                }
                if (response.status === 403) {
                    console.error("Github API rate limit exceeded: ", response);
                    throw new Error(I18N.IndexGithubRateLimitError);
                }
                console.error("GitHub API returned: ", response);
                throw new Error(I18N.IndexGithubAPIError(response.status));
            })
            .then((data) => {
                if (data.error) throw new Error(data.error);

                if (data.state === "failed") {
                    throw new Error(data.result);
                }

                marked.parse(data.body, {
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
            .catch((error) => { LRR.showErrorToast(I18N.IndexUpdateError, error); });
    }
};

/**
 * Load tag suggestions for the tag search bar.
 */
Index.loadTagSuggestions = function () {
    // Query the tag cloud API to get the most used tags.
    Server.callAPI("/api/database/stats?minweight=2", "GET", null, I18N.TagStatsLoadFailure,
        (data) => {
            // Get namespaces objects in the data array to fill the namespace-sortby combobox
            const namespacesSet = new Set(data.map((element) => (element.namespace === "parody" ? "series" : element.namespace)));
            namespacesSet.forEach((element) => {
                if (element !== "" && element !== "date_added") {
                    $("#namespace-sortby").append(`<option value="${element}">${element.charAt(0).toUpperCase() + element.slice(1)}</option>`);
                }
            });

            // Setup awesomplete for the tag search bar
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
                    this.input.value = `${before + text}$, `;
                },
            });
        },
    );
};

/**
 * Query the category API to build the filter buttons.
 */
Index.loadCategories = function () {
    return Server.callAPI("/api/categories", "GET", null, I18N.CategoryFetchError,
        (data) => {
            // Sort by pinned + alpha
            // Pinned categories are shown at the beginning
            data.sort((b, a) => b.name.localeCompare(a.name));
            data.sort((a, b) => b.pinned - a.pinned);
            // Helper to check if a category is selected (handles uninitialized state)
            const isSelected = (id) => Index.selectedCategories && Index.selectedCategories.has(id);

            // Queue some hardcoded categories at the beginning - those are special-cased in the DataTables variant of the search endpoint. 
            let html = `<div style='display:inline-block'>
                            <input class='favtag-btn ${(isSelected("NEW_ONLY") ? "toggled" : "")}' 
                            type='button' id='NEW_ONLY' value='🆕 ${I18N.NewArchives}' 
                            onclick='Index.toggleCategory(this)' title='${I18N.NewArchiveDesc}'/>
                        </div><div style='display:inline-block'>
                            <input class='favtag-btn ${(isSelected("UNTAGGED_ONLY") ? "toggled" : "")}' 
                            type='button' id='UNTAGGED_ONLY' value='🏷️ ${I18N.UntaggedArchives}' 
                            onclick='Index.toggleCategory(this)' title='${I18N.UntaggedArcDesc}'/>
                        </div><div style='display:inline-block'>
                            <input class='favtag-btn ${(isSelected("TANKOUBONS_ONLY") ? "toggled" : "")}' 
                            type='button' id='TANKOUBONS_ONLY' value='📚 ${I18N.TankoubonsOnly}' 
                            onclick='Index.toggleCategory(this)' title='${I18N.TankoubonsOnlyDesc}'/>
                        </div>`;

            const iteration = (data.length > 10 ? 10 : data.length);

            for (let i = 0; i < iteration; i++) {
                const category = data[i];
                const pinned = category.pinned === "1";

                let catName = (pinned ? "📌" : "") + category.name;
                catName = LRR.encodeHTML(catName);

                const div = `<div style='display:inline-block'>
                    <input class='favtag-btn ${(isSelected(category.id) ? "toggled" : "")}' 
                            type='button' id='${category.id}' value='${catName}' 
                            onclick='Index.toggleCategory(this)' title='${I18N.CategoryDesc}'/>
                </div>`;

                // Take this opportunity to update the bookmark
                if (category.id === localStorage.getItem("bookmarkCategoryId")) {
                    localStorage.setItem("bookmarkedArchives", JSON.stringify(category.archives));
                }

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
        },
    );
};

/**
 * If server-side progress tracking is enabled, migrate local progression to the server.
 */
Index.migrateProgress = function () {
    // No migration if local progress is enabled, or if progress is authenticated and we're not logged in.
    if (Index.isProgressLocal || (Index.isProgressAuthenticated && !LRR.isUserLogged())) {
        return;
    }

    const localProgressKeys = Object.keys(localStorage).filter((x) => x.endsWith("-reader")).map((x) => x.slice(0, -7));
    if (localProgressKeys.length > 0) {
        LRR.toast({
            heading: I18N.LocalProgression,
            text: I18N.LocalProgressionDesc + " ☕",
            icon: "info",
            hideAfter: 23000,
        });

        const promises = [];
        localProgressKeys.forEach((id) => {
            const progress = localStorage.getItem(`${id}-reader`);

            promises.push(fetch(new LRR.apiURL(`api/archives/${id}/metadata`), { method: "GET" })
                .then((response) => response.json())
                .then((data) => {
                    // Don't migrate if the server progress is already further
                    if (progress !== null
                        && data !== undefined
                        && data !== null
                        && progress > data.progress) {
                        Server.callAPI(`api/archives/${id}/progress/${progress}?force=1`, "PUT", null, I18N.LocalProgressionError, null);
                    }

                    // Clear out localStorage'd progress
                    localStorage.removeItem(`${id}-reader`);
                    localStorage.removeItem(`${id}-totalPages`);
                }));
        });

        Promise.all(promises).then(() => LRR.toast({
            heading: I18N.LocalProgressionComplete + " 🎉",
            text: I18N.LocalProgressionCompleteDesc,
            icon: "success",
            hideAfter: 13000,
        }));
    } else {
        // eslint-disable-next-line no-console
        console.log("No local reading progression to migrate");
    }
};

/**
 * Restore and update column width, data store in localstorge.
 */
Index.resizableColumns = function () {
    let currentHeader;
    let currentIndex;
    let startX;
    let startWidth;

    const headers = document.querySelectorAll("#header-row th");
    headers.forEach(header => {
        // init
        header.addEventListener("mousedown", function (event) {
            if (event.offsetX > header.offsetWidth - 10) {
                currentHeader = header;
                currentIndex = Array.from(headers).indexOf(currentHeader);
                startX = event.clientX;

                startWidth = localStorage.getItem(`resizeColumn${currentIndex}`) || header.width || header.offsetWidth;
                if (!Number.isInteger(startWidth))
                    startWidth = parseInt(startWidth.replace("px", ""));

                document.addEventListener("mousemove", resizeColumn);
                document.addEventListener("mouseup", stopResize);

                // Disable DataTables sorting while resizing
                // (Unfortunately, sorting is perma-disabled after this..)
                // TODO fix both deprecated and the broken sorting
                $("th").unbind("click.DT");

                document.body.style.cursor = "col-resize";
            }
        });
        header.addEventListener("mousemove", function (event) {
            if (event.offsetX > header.offsetWidth - 10) {
                header.style.cursor = "col-resize";
            } else {
                header.style.cursor = "default";
            }
        });
    });

    function resizeColumn(event) {
        if (currentHeader) {
            currentHeader.style.cursor = "col-resize";
            let newWidth = startWidth + (event.clientX - startX);
            const minWidth = parseInt(window.getComputedStyle(currentHeader).minWidth.replace("px", ""));
            const maxWidth = parseInt(window.getComputedStyle(currentHeader).maxWidth.replace("px", ""));

            if (newWidth > maxWidth)
                newWidth = maxWidth;

            if (newWidth < minWidth)
                newWidth = minWidth;

            if (newWidth > 0) {
                currentHeader.style.width = newWidth + "px";
                localStorage.setItem(`resizeColumn${currentIndex}`, newWidth + "px");
            }
        }
    }

    function stopResize() {
        if (currentHeader) {
            currentHeader = null;
        }
        document.removeEventListener("mousemove", resizeColumn);
        document.removeEventListener("mouseup", stopResize);

        document.body.style.cursor = "default";
    }
};

/**
 * @returns number of custom columns in compact mode
 */
Index.getColumnCount = function () {
    return localStorage.getItem("columnCount") ? parseInt(localStorage.getItem("columnCount")) : 2;
}

jQuery(() => {
    Index.initializeAll();
});
